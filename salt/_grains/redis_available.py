#!/usr/bin/env python
"""Custom grain: Redis/Valkey autodiscovery.

The single question this grain answers is: "can the local root user read a
Redis/Valkey server with zero stored credentials (default redis-cli connect,
127.0.0.1:6379, no password)?" If yes, anything relying on that same zero-conf
path works too -- poor man's autodiscovery.

Note the asymmetry vs the mysql grain: Redis has no universal ~/.my.cnf style
credential file, so a server with `requirepass` set is genuinely unusable
without out-of-band creds. We surface that as available=False + auth_required
=True (the server is there, just locked) rather than pretending it is usable.

Locality: `INFO server` reports the server's own process_id. If that PID
resolves to a redis/valkey process in *our* /proc, the server shares our PID
namespace => same host, not a container. That is a stronger local proof than
transport sniffing, and it naturally reports containerised servers (own PID
namespace, so process_id won't match) as local=False -- which is the intent.

Grains run as root on EVERY salt invocation, very early (before pillar and
execution modules -- so no __salt__ here, we use subprocess directly). A grain
that blocks blocks all of Salt on this minion, so the probe is bounded by an
outer subprocess timeout as a hard kill. (redis-cli -t is intentionally not
used: old redis-cli builds lack that flag, so we rely on the outer timeout.)

Returns a single nested grain:

    redis:
      available:      True | False   # read the server with no stored creds
      flavor:         redis | valkey | ""
      version:        "8.0.1" | ""   # native version of the detected flavor
      redis_version:  "7.4.0" | ""   # raw INFO field (valkey reports a compat one)
      valkey_version: "8.0.1" | ""   # raw INFO field (empty on plain redis)
      auth_required:  True | False   # server answered NOAUTH
      local:          True | False   # process_id is a redis/valkey proc in /proc
      server_pid:     "974" | ""     # process_id from INFO, for inspection
      client:         "/usr/bin/redis-cli" | ""
      process:        True | False   # any redis/valkey-server in /proc (info only)
"""

import os
import subprocess

# Hard upper bound on the probe. Must stay small: this runs inline with grain
# rendering, so it is added latency on every salt call. This is the ONLY guard
# (old redis-cli builds lack -t), so keep it tight.
_PROBE_TIMEOUT = 5          # seconds, outer subprocess kill

# PATH is minimal during grain load, so search explicit locations. valkey-cli
# is included because a pure-Valkey host may ship no redis-cli at all; both
# speak the same protocol.
_CLIENT_CANDIDATES = (
    "/usr/bin/redis-cli",
    "/usr/local/bin/redis-cli",
    "/usr/bin/valkey-cli",
    "/usr/local/bin/valkey-cli",
)

# /proc/<pid>/comm values that count as a local redis/valkey server.
_SERVER_COMMS = (b"redis-server", b"valkey-server")


def _find_client():
    """Return path to a redis-cli/valkey-cli binary, or None."""
    for path in _CLIENT_CANDIDATES:
        if os.access(path, os.X_OK):
            return path
    # Fallback: honour PATH if it happens to be populated.
    from shutil import which
    return which("redis-cli") or which("valkey-cli")


def _run(client):
    """Run `INFO server` through the default (no-password) connection.

    Returns combined stdout+stderr text, or None on spawn failure / timeout.
    We keep both streams: INFO data lands on stdout, while NOAUTH and
    connection errors land on stderr depending on the client version.
    """
    cmd = [client, "INFO", "server"]
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=_PROBE_TIMEOUT,
            # Clean env: deliberately drop REDISCLI_AUTH so we test the
            # genuine no-password path.
            env={"PATH": "/usr/bin:/bin"},
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    out = proc.stdout.decode("utf-8", "replace")
    err = proc.stderr.decode("utf-8", "replace")
    return out + "\n" + err


def _parse_info(text):
    """Parse `key:value` INFO lines into a dict.

    Only lines whose key has no whitespace are kept, which drops section
    headers ("# Server") and free-form error text ("Could not connect ...").
    """
    info = {}
    for line in text.splitlines():
        if ":" not in line:
            continue
        key, _, value = line.partition(":")
        if not key or key.strip() != key or " " in key:
            continue
        info[key] = value.strip()
    return info


def _pid_is_server(pid):
    """True if /proc/<pid> is a redis/valkey server in *this* namespace."""
    if not pid or not pid.isdigit():
        return False
    try:
        with open("/proc/%s/comm" % pid, "rb") as fh:
            return fh.read().strip() in _SERVER_COMMS
    except (IOError, OSError):
        return False


def _local_server_process():
    """Best-effort: is any redis/valkey-server visible in this /proc?

    Informational only -- wrong for containerised servers (other PID
    namespace), so it must NOT drive any decision.
    """
    try:
        pids = [p for p in os.listdir("/proc") if p.isdigit()]
    except OSError:
        return False
    for pid in pids:
        if _pid_is_server(pid):
            return True
    return False


def redis_grains():
    """Public entrypoint -- Salt merges the returned dict into grains."""
    grain = {
        "available": False,
        "flavor": "",
        "version": "",
        "redis_version": "",
        "valkey_version": "",
        "auth_required": False,
        "local": False,
        "server_pid": "",
        "client": "",
        "process": _local_server_process(),
    }

    client = _find_client()
    if not client:
        return {"redis": grain}
    grain["client"] = client

    text = _run(client)
    if text is None:
        return {"redis": grain}         # spawn failure / timeout => unavailable

    # Server present but locked: we cannot use it without stored creds.
    if "NOAUTH" in text.upper():
        grain["auth_required"] = True
        return {"redis": grain}

    info = _parse_info(text)
    redis_version = info.get("redis_version", "")
    valkey_version = info.get("valkey_version", "")
    if not redis_version and not valkey_version:
        # No usable INFO (e.g. connection refused): server not reachable.
        return {"redis": grain}

    grain["available"] = True
    grain["redis_version"] = redis_version
    grain["valkey_version"] = valkey_version

    if valkey_version or info.get("server_name", "").lower() == "valkey":
        grain["flavor"] = "valkey"
        grain["version"] = valkey_version or redis_version
    else:
        grain["flavor"] = "redis"
        grain["version"] = redis_version

    pid = info.get("process_id", "")
    grain["server_pid"] = pid
    grain["local"] = _pid_is_server(pid)

    return {"redis": grain}
