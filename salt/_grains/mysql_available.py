#!/usr/bin/env python
"""Custom grain: MySQL/MariaDB autodiscovery.

The single question this grain answers is: "can the local *root* user reach a
MySQL-compatible server using the default client config (/root/.my.cnf or the
default socket)?" If yes, anything that relies on that same config path will
work too, with no manual user/grant setup -- poor man's autodiscovery.

That connectivity probe is authoritative on its own, so we lean on it as the
primary signal and harvest version + flavor from the very same query.

Locality: we do NOT try to prove the server shares our namespace (that needs
finding the server PID behind the socket and comparing /proc/<pid>/ns/* --
not worth it). Instead we read how WE connected, which the server reports in
its own processlist row:
  * Unix socket  -> host "localhost": a socket is a path in our mount ns, so
    same host / effectively same namespace. Strong "local" signal.
  * loopback TCP -> host "127.0.0.1:port": local, EXCEPT a container can
    publish its port on loopback, so this is the one ambiguous case (~0.1%).
  * routable TCP -> host "1.2.3.4:port": treat as remote (covers ".my.cnf
    points at our own public IP" and "points at another box").

Grains run as root on EVERY salt invocation, very early (before pillar and
execution modules -- so no __salt__ here, we use subprocess directly). A grain
that blocks blocks all of Salt on this minion, so every external call is
bounded twice: client-side --connect-timeout AND an outer subprocess timeout
as a hard kill.

Returns a single nested grain:

    mysql:
      available: True | False      # root can run a query via the default config
      version:   "8.0.36-28" | ""  # SERVER version (not the client binary)
      flavor:    mysql | mariadb | percona | ""
      transport: socket | tcp | "" # how we reached the server
      peer_host: "localhost" | "127.0.0.1:3306" | ""  # raw, for inspection
      local:     True | False | None   # derived; None = transport unknown
      client:    "/usr/bin/mysql" | ""  # client binary used for the probe
      process:   True | False      # local mysqld/mariadbd seen in /proc (info)
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

# Rich probe: version + flavor + how *we* are connected (own processlist row,
# readable without the PROCESS privilege). Plain probe is the robust fallback
# so a quirky information_schema can never flip a live server to unavailable.
_SQL_RICH = (
    "SELECT VERSION(), @@version_comment, "
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


def _classify_peer(host):
    """Map the server-reported connection host to (transport, local).

    transport: "socket" | "tcp" | ""(unknown)
    local:     True | False | None(unknown)
    """
    if not host:
        return "", None
    h = host.strip().lower()
    if h == "localhost":
        return "socket", True          # Unix socket
    # TCP: "ip:port" (ipv6 may carry extra colons; loopback check is best-effort).
    addr = h.rsplit(":", 1)[0]
    if addr.startswith("127.") or "::1" in h:
        return "tcp", True             # loopback (container-on-loopback caveat)
    return "tcp", False                # routable address => remote


def _probe(client):
    """Probe the server. Returns a dict of discovered fields, or None if the
    server is not reachable at all."""
    out = _run(client, _SQL_RICH)
    have_host = out is not None
    if out is None:
        out = _run(client, _SQL_PLAIN)   # robust fallback: keep availability
    if not out:
        return None

    parts = out.split("\t")
    version = parts[0].strip()
    if not version:
        return None
    comment = parts[1].strip() if len(parts) > 1 else ""
    peer_host = parts[2].strip() if (have_host and len(parts) > 2) else ""
    transport, local = _classify_peer(peer_host)

    return {
        "version": version,
        "flavor": _flavor(version, comment),
        "peer_host": peer_host,
        "transport": transport,
        "local": local,
    }


def _local_server_process():
    """Best-effort: is a mysqld/mariadbd process visible in this /proc?

    Informational only -- it is wrong for containerised servers (other PID
    namespace) and remote .my.cnf targets, so it must NOT drive any decision.
    """
    names = (b"mysqld", b"mariadbd")
    try:
        pids = [p for p in os.listdir("/proc") if p.isdigit()]
    except OSError:
        return False
    for pid in pids:
        try:
            with open("/proc/%s/comm" % pid, "rb") as fh:
                if fh.read().strip() in names:
                    return True
        except (IOError, OSError):
            continue
    return False


def mysql_grains():
    """Public entrypoint -- Salt merges the returned dict into grains."""
    grain = {
        "available": False,
        "version": "",
        "flavor": "",
        "transport": "",
        "peer_host": "",
        "local": None,
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
