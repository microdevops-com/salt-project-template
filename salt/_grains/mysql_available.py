#!/usr/bin/env python
"""Custom grain: MySQL/MariaDB autodiscovery.

Two indicators, mirroring the actual situation on the box (we never supply
credentials just for the grain -- we only reflect what the default path gives):

  * available: we connected and ran a command using the default client config
    (/root/.my.cnf or the default socket). If those creds work, True; if the
    server refuses us, False. This is "can I run arbitrary commands right now".
  * local: available AND the *connected* server process runs on this machine.
    It is the strict indicator; available is just its first half.

Locality is a proof, not a heuristic: SELECT @@pid_file gives the connected
server's own pidfile path; we read it and check /proc/<pid>/comm. A match means
the server shares our PID namespace => same host. Containerised servers report
a pidfile path / PID from their own namespace that will not resolve here, so
they correctly come out local=False.

transport/peer_host are kept as pure informational fields (how we reached the
server), not as the locality signal.

Grains run as root on EVERY salt invocation, very early (before pillar and
execution modules -- so no __salt__ here, we use subprocess directly). A grain
that blocks blocks all of Salt on this minion, so every external call is
bounded twice: client-side --connect-timeout AND an outer subprocess timeout
as a hard kill.

Returns a single nested grain:

    mysql:
      available: True | False      # connected + ran a command via default config
      local:     True | False      # available AND server runs on this machine
      version:   "8.0.36-28" | ""  # SERVER version (not the client binary)
      flavor:    mysql | mariadb | percona | ""
      server_pid:"974" | ""        # connected server PID (from @@pid_file)
      transport: socket | tcp | "" # how we reached the server (info only)
      peer_host: "localhost" | "127.0.0.1:3306" | ""  # raw, for inspection
      client:    "/usr/bin/mysql" | ""  # client binary used for the probe
      process:   True | False      # any mysqld/mariadbd seen in /proc (info only)
"""

import os
import subprocess

# Hard upper bound on the whole probe. Must stay small: this runs inline with
# grain rendering, so it is added latency on every salt call.
_PROBE_TIMEOUT = 5          # seconds, outer subprocess kill (per query)
_CONNECT_TIMEOUT = 3        # seconds, mysql client connect timeout

# PATH is minimal during grain load, so search explicit locations.
_CLIENT_CANDIDATES = (
    "/usr/bin/mysql",
    "/usr/local/bin/mysql",
    "/usr/bin/mariadb",
    "/usr/local/bin/mariadb",
)

# /proc/<pid>/comm values that count as a local mysql/mariadb server.
_SERVER_COMMS = (b"mysqld", b"mariadbd")

# Rich probe: version + flavor + the connected server's pidfile path (for the
# locality proof) + how *we* connected (own processlist row, readable without
# the PROCESS privilege). Plain probe is the robust fallback so a quirky
# information_schema can never flip a live server to unavailable.
_SQL_RICH = (
    "SELECT VERSION(), @@version_comment, @@pid_file, "
    "(SELECT host FROM information_schema.processlist WHERE id = CONNECTION_ID())"
)
_SQL_PLAIN = "SELECT VERSION(), @@version_comment"


def _find_client():
    """Return path to a mysql/mariadb client binary, or None."""
    for path in _CLIENT_CANDIDATES:
        if os.access(path, os.X_OK):
            return path
    # Fallback: honour PATH if it happens to be populated.
    from shutil import which
    return which("mysql") or which("mariadb")


def _run(client, sql):
    """Run one batch query. Return stdout str on success, or None on any
    failure (no binary, auth/connect error, non-zero exit, timeout)."""
    cmd = [
        client,
        "--batch",                 # tab-separated, machine friendly
        "--skip-column-names",
        "--connect-timeout=%d" % _CONNECT_TIMEOUT,
        "-e", sql,
    ]
    try:
        proc = subprocess.run(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            timeout=_PROBE_TIMEOUT,
            # Clean, predictable env. /root/.my.cnf is read from HOME.
            env={"HOME": "/root", "PATH": "/usr/bin:/bin"},
        )
    except (OSError, subprocess.TimeoutExpired):
        return None
    if proc.returncode != 0:
        return None
    return proc.stdout.decode("utf-8", "replace").strip()


def _flavor(version, comment):
    haystack = (version + " " + comment).lower()
    if "mariadb" in haystack:
        return "mariadb"
    if "percona" in haystack:
        return "percona"
    return "mysql"


def _transport(host):
    """Classify the server-reported connection host (info only).

    "localhost" -> unix socket; "ip:port" -> tcp; "" -> unknown.
    """
    if not host:
        return ""
    return "socket" if host.strip().lower() == "localhost" else "tcp"


def _pid_is_server(pid):
    """True if /proc/<pid> is a mysql/mariadb server in *this* namespace."""
    if not pid or not pid.isdigit():
        return False
    try:
        with open("/proc/%s/comm" % pid, "rb") as fh:
            return fh.read().strip() in _SERVER_COMMS
    except (IOError, OSError):
        return False


def _pid_from_file(path):
    """Read a pidfile and return the PID string, or "" if unreadable/invalid."""
    if not path:
        return ""
    try:
        with open(path, "r") as fh:
            pid = fh.read().strip()
    except (IOError, OSError):
        return ""
    return pid if pid.isdigit() else ""


def _probe(client):
    """Probe the server. Returns a dict of discovered fields, or None if the
    server is not reachable at all."""
    out = _run(client, _SQL_RICH)
    have_rich = out is not None
    if out is None:
        out = _run(client, _SQL_PLAIN)   # robust fallback: keep availability
    if not out:
        return None

    parts = out.split("\t")
    version = parts[0].strip()
    if not version:
        return None
    comment = parts[1].strip() if len(parts) > 1 else ""
    pid_file = parts[2].strip() if (have_rich and len(parts) > 2) else ""
    peer_host = parts[3].strip() if (have_rich and len(parts) > 3) else ""

    server_pid = _pid_from_file(pid_file)
    return {
        "version": version,
        "flavor": _flavor(version, comment),
        "server_pid": server_pid,
        "local": _pid_is_server(server_pid),
        "transport": _transport(peer_host),
        "peer_host": peer_host,
    }


def _local_server_process():
    """Best-effort: is any mysqld/mariadbd visible in this /proc?

    Informational only -- it is wrong for containerised servers (other PID
    namespace) and remote .my.cnf targets, so it must NOT drive any decision.
    """
    try:
        pids = [p for p in os.listdir("/proc") if p.isdigit()]
    except OSError:
        return False
    for pid in pids:
        if _pid_is_server(pid):
            return True
    return False


def mysql_grains():
    """Public entrypoint -- Salt merges the returned dict into grains."""
    grain = {
        "available": False,
        "local": False,
        "version": "",
        "flavor": "",
        "server_pid": "",
        "transport": "",
        "peer_host": "",
        "client": "",
        "process": _local_server_process(),
    }

    client = _find_client()
    if not client:
        # No client binary => we cannot probe the default config path at all.
        # Treat as unavailable.
        return {"mysql": grain}

    grain["client"] = client
    found = _probe(client)
    if found is not None:
        grain["available"] = True
        grain.update(found)

    return {"mysql": grain}
