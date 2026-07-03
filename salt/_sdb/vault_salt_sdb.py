"""
SDB module: read HashiCorp Vault KV secrets directly (token / AppRole / JWT-OIDC),
with stock-sdb-compatible URI syntax, a file-based token cache, an optional
two-tier value cache (freshness + outage fallback), optional cache encryption,
fail-closed errors, an in-process circuit breaker, and per-render path dedup.
Built for salt-ssh on Salt 3006.

Version history:
* 2026-06-16: initial version
* 2026-06-21: cache file written 0600 (was 0644); dropped dead `cached` arg from
  _extract; documented lease_duration-0 fallback and cache_fresh_for staleness window.
* 2026-06-29: added `jwt` auth method (GitLab CI OIDC: exchange id_tokens JWT for a
  short-lived Vault token); refactored AppRole/JWT onto a shared `_login`; an explicit
  but absent auth_file is no longer fatal when inline auth is present (CI uses inline
  JWT, persistent masters / local dev override with an AppRole auth_file).

Profile (e.g. /etc/salt/master.d/vault.conf):

    custom_vault_driver:
      driver: vault_salt_sdb
      url: https://vault.dev.example.org
      auth:                         # inline auth (optional when auth_file is used)
        method: approle          # or: token, jwt
        role_id: <role-id>
        secret_id: <secret-id>
        # method: token -> token: <token>
        # method: jwt (GitLab CI OIDC) -> role: <vault-jwt-role>
        #   JWT source: $VAULT_ID_TOKEN (default) | jwt_env: <ENV> | jwt_file: <path> | jwt: <inline>
        #   mount: jwt (optional, the Vault jwt auth mount path; default 'jwt')
      auth_file: ~/.config/vault_salt_sdb/auth.conf   # optional; load auth from a separate
                                    # file so credentials stay OUT of this config. Keys there
                                    # OVERRIDE the inline auth above. Used automatically if it exists.
      verify: true                  # TLS verify (default: true)
      timeout: 10                   # request timeout, seconds (default: 10)
      outage_cooldown: 30           # after Vault fails, skip it for this many seconds (default: 30)
      kv_version: 2                 # optional; autodetected if omitted
      cache_secrets: false          # keep secret VALUES on disk (default: false = fail-closed)
      cache_fresh_for: 60           # reuse a cached value without calling Vault if younger, seconds
                                    # (note: a rotated secret is not observed until this window lapses)
      cache_offline_max_age: 3600   # if Vault is unreachable, reuse a cached value if younger, seconds
      cache_name: <name>            # optional; cache filename component (default: git repo + hash)
      cache_path: <path>            # optional; full cache file path override
      cache_encryption_key: <pass>  # optional; if set, the cache file is encrypted
      warn_plaintext_cache: true    # log the "cache is unencrypted" warning (default: true;
                                    # set false to silence it, e.g. in the minion.d/check config)

URI:  sdb://<profile>/<mount>/<path>/<key>          (key = last segment)
      sdb://custom_vault_driver/salt/example/tst/nextcloud/admin_pass
      -> GET <url>/v1/salt/data/example/tst/nextcloud ; return key 'admin_pass'

Performance during an outage:
  * Circuit breaker: the first connection failure is recorded in the cache file
    for `outage_cooldown` seconds; subsequent lookups (even in fresh render contexts,
    as salt-ssh uses) skip the network and fall back to cache. One timeout per
    breaker window, not per key. The marker clears once Vault answers again.
  * Per-render dedup: within one process each secret PATH is fetched at most once.

Auth file (auth_file; default ~/.config/vault_salt_sdb/auth.conf; chmod 600). Same
keys as the inline `auth:` block, for example:

    method: approle
    role_id: <role-id>
    secret_id: <secret-id>
    # or:  method: token  /  token: <vault-token>
"""
import base64
import hashlib
import json
import logging
import os
import re
import tempfile
import time

import requests
import yaml

import salt.exceptions

log = logging.getLogger(__name__)

__virtualname__ = "vault_salt_sdb"

_SESSION = None
_CACHES = {}            # cache_path -> {"tokens": {}, "kv": {}, "secrets": {}}
_RENDER_SECRETS = {}    # "url|mount|path" -> data dict (this process only)
_VAULT_DOWN = set()     # base urls found unreachable this process (circuit breaker)
_REPO_ID = None         # cached per-repo identifier used in the cache filename
_AUTH_FILES = {}        # auth_file path -> parsed auth dict (this process only)
_WARNED_PLAINTEXT = False

DEFAULT_AUTH_FILE = "~/.config/vault_salt_sdb/auth.conf"


class _VaultUnreachable(Exception):
    """Vault could not be reached (network / timeout / 5xx / sealed)."""


def __virtual__():
    return __virtualname__


# --------------------------------------------------------------------------- #
# infra: session, encryption, cache file
# --------------------------------------------------------------------------- #
def _session():
    global _SESSION
    if _SESSION is None:
        _SESSION = requests.Session()
    return _SESSION


def _timeout(profile):
    return profile.get("timeout", 10)


def _mark_down(profile):
    base = profile["url"].rstrip("/")
    _VAULT_DOWN.add(base)
    cache = _load_cache(profile)
    cache.setdefault("down", {})[base] = time.time()
    _save_cache(profile)


def _down(profile, msg):
    _mark_down(profile)
    raise _VaultUnreachable(msg)


def _request(profile, method, full_url, **kw):
    base = profile["url"].rstrip("/")
    cache = _load_cache(profile)
    down = cache.setdefault("down", {})
    outage_cooldown = int(profile.get("outage_cooldown", 30))
    # Circuit breaker, persisted to the cache file so it survives salt-ssh
    # rendering each sdb lookup in a fresh context: if Vault failed recently,
    # skip the network entirely and let the caller fall back to cache.
    if base in _VAULT_DOWN or (down.get(base) and time.time() - down[base] < outage_cooldown):
        raise _VaultUnreachable("Vault marked unreachable recently; skipping connection")
    try:
        r = _session().request(
            method, full_url,
            verify=profile.get("verify", True),
            timeout=_timeout(profile),
            **kw
        )
    except requests.exceptions.RequestException as exc:
        _mark_down(profile)
        raise _VaultUnreachable(str(exc))
    # got an HTTP response -> Vault answered; clear any stale down marker
    if base in down:
        down.pop(base, None)
        _save_cache(profile)
    _VAULT_DOWN.discard(base)
    return r


def _fernet(cache_encryption_key):
    try:
        from cryptography.fernet import Fernet
    except ImportError:
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: cache_encryption_key is set but the 'cryptography' library is unavailable"
        )
    fkey = base64.urlsafe_b64encode(hashlib.sha256(cache_encryption_key.encode()).digest())
    return Fernet(fkey)


def _repo_id():
    """Stable per-repo identifier for the cache filename: git repo name + short
    hash of its absolute path (so same-named repos in different paths don't clash)."""
    global _REPO_ID
    if _REPO_ID is not None:
        return _REPO_ID
    try:
        import subprocess
        top = subprocess.check_output(
            ["git", "rev-parse", "--show-toplevel"],
            stderr=subprocess.DEVNULL,
            timeout=5,
        ).decode().strip()
    except Exception:
        top = os.getcwd()
    name = re.sub(r"[^A-Za-z0-9._-]", "_", os.path.basename(top.rstrip("/")) or "repo")
    short = hashlib.sha256(top.encode()).hexdigest()[:8]
    _REPO_ID = "{}_{}".format(name, short)
    return _REPO_ID


def _cache_path(profile):
    # Keep the cache OUTSIDE file_roots / the salt repo: salt-ssh scans those dirs
    # (an unreadable file there breaks "checking context"), and a cache holding
    # secrets could get git-committed. Default: per-user dir, per-repo filename.
    explicit = profile.get("cache_path")
    if explicit:
        return os.path.expanduser(explicit)
    name = profile.get("cache_name") or _repo_id()
    return os.path.expanduser(
        os.path.join("~", ".cache", "vault_salt_sdb_{}.json".format(name))
    )


def _empty_cache():
    return {"tokens": {}, "kv": {}, "secrets": {}, "down": {}}


def _load_cache(profile):
    path = _cache_path(profile)
    if path in _CACHES:
        return _CACHES[path]
    cache = _empty_cache()
    try:
        with open(path, "rb") as fh:
            raw = fh.read()
        if raw:
            if profile.get("cache_encryption_key"):
                raw = _fernet(profile["cache_encryption_key"]).decrypt(raw)
            loaded = json.loads(raw)
            for section in cache:
                got = loaded.get(section)
                if isinstance(got, dict):
                    cache[section] = got
    except FileNotFoundError:
        pass
    except salt.exceptions.CommandExecutionError:
        raise
    except Exception as exc:        # corrupt file or wrong key -> ignore, rebuild
        log.warning("vault_salt_sdb: ignoring unreadable cache %s: %s", path, exc)
    _CACHES[path] = cache
    return cache


def _save_cache(profile):
    path = _cache_path(profile)
    cache = _CACHES.get(path)
    if cache is None:
        return
    raw = json.dumps(cache).encode()
    if profile.get("cache_encryption_key"):
        raw = _fernet(profile["cache_encryption_key"]).encrypt(raw)
    folder = os.path.dirname(path) or "."
    try:
        os.makedirs(folder, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=folder, prefix=".vault_salt_sdb_", suffix=".tmp")
        try:
            with os.fdopen(fd, "wb") as fh:
                fh.write(raw)
            os.chmod(tmp, 0o600)  # owner-only: file holds a live Vault token + (optionally) plaintext secrets
            os.replace(tmp, path)          # atomic
            tmp = None
        finally:
            if tmp and os.path.exists(tmp):
                try:
                    os.remove(tmp)
                except OSError:
                    pass
    except salt.exceptions.CommandExecutionError:
        raise
    except Exception as exc:
        log.warning("vault_salt_sdb: failed to persist cache %s: %s", path, exc)


# --------------------------------------------------------------------------- #
# auth
# --------------------------------------------------------------------------- #
def _auth(profile):
    """Resolve the auth mapping. Inline `auth:` is the base; an external
    `auth_file` (default DEFAULT_AUTH_FILE) is overlaid on top (file wins), so
    credentials can live outside the Salt config. The file holds the same keys
    as the inline block, optionally wrapped in a top-level `auth:`."""
    inline = dict(profile.get("auth") or {})
    explicit = "auth_file" in profile
    path = os.path.expanduser(profile.get("auth_file", DEFAULT_AUTH_FILE))

    if path in _AUTH_FILES:
        file_auth = _AUTH_FILES[path]
    elif os.path.exists(path):
        try:
            with open(path) as fh:
                loaded = yaml.safe_load(fh) or {}
        except Exception as exc:
            raise salt.exceptions.CommandExecutionError(
                "vault_salt_sdb: cannot read auth_file {}: {}".format(path, exc)
            )
        if not isinstance(loaded, dict):
            raise salt.exceptions.CommandExecutionError(
                "vault_salt_sdb: auth_file {} must be a mapping "
                "(method/role_id/secret_id/token)".format(path)
            )
        file_auth = loaded.get("auth", loaded)       # bare mapping or `auth:` wrapper
        if not isinstance(file_auth, dict):
            raise salt.exceptions.CommandExecutionError(
                "vault_salt_sdb: 'auth' in {} must be a mapping".format(path)
            )
        _AUTH_FILES[path] = file_auth
    elif explicit:
        # An explicitly configured auth_file that is absent is only fatal when there is
        # no usable inline auth to fall back to. This lets one shared profile carry inline
        # JWT auth (used in CI, where no auth_file exists) while persistent masters / local
        # dev drop an AppRole auth_file alongside it that takes over when present.
        if inline:
            log.debug("vault_salt_sdb: auth_file %s absent; using inline auth", path)
            file_auth = None
        else:
            raise salt.exceptions.CommandExecutionError(
                "vault_salt_sdb: auth_file not found: {}".format(path)
            )
    else:
        file_auth = None

    return {**inline, **file_auth} if file_auth else inline


def _jwt_token(auth):
    """Resolve the OIDC JWT for jwt auth: inline auth:jwt, else the env var named by
    auth:jwt_env (default VAULT_ID_TOKEN, injected by GitLab CI id_tokens), else
    auth:jwt_file."""
    jwt = auth.get("jwt")
    if jwt:
        return jwt
    env = auth.get("jwt_env", "VAULT_ID_TOKEN")
    jwt = os.environ.get(env)
    if jwt:
        return jwt
    jwt_file = auth.get("jwt_file")
    if jwt_file:
        path = os.path.expanduser(jwt_file)
        try:
            with open(path) as fh:
                return fh.read().strip()
        except Exception as exc:
            raise salt.exceptions.CommandExecutionError(
                "vault_salt_sdb: cannot read jwt_file {}: {}".format(path, exc)
            )
    raise salt.exceptions.CommandExecutionError(
        "vault_salt_sdb: jwt auth has no token (set ${} or auth:jwt_file)".format(env)
    )


def _login(profile, url, login_path, payload, ckey, force, what):
    """Shared token-issuing login (AppRole / JWT): return a still-valid cached token,
    else POST to login_path, cache the issued client_token under ckey, and return it."""
    cache = _load_cache(profile)
    if not force:
        ent = cache["tokens"].get(ckey)
        if ent and ent.get("expires_at", 0) - 10 > time.time():
            return ent["token"]

    r = _request(profile, "POST", "{}/v1/{}".format(url, login_path), json=payload)
    if r.status_code in (400, 403):
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: {} login denied (HTTP {})".format(what, r.status_code)
        )
    if r.status_code == 503:
        _down(profile, "Vault sealed during {} login (503)".format(what))
    if r.status_code >= 500:
        _down(profile, "Vault error {} during {} login".format(r.status_code, what))
    if r.status_code != 200:
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: unexpected {} login HTTP {}".format(what, r.status_code)
        )
    try:
        body_auth = r.json()["auth"]
        token = body_auth["client_token"]
    except (ValueError, KeyError) as exc:
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: unexpected {} login response: {}".format(what, exc)
        )

    # lease_duration 0 (e.g. root/non-expiring tokens) -> fall back to a short 60s
    # cache rather than treating the token as valid forever.
    ttl = body_auth.get("lease_duration", 0) or 60
    cache["tokens"][ckey] = {"token": token, "expires_at": time.time() + ttl}
    _save_cache(profile)
    return token


def _token(profile, force=False):
    auth = _auth(profile)
    method = auth.get("method", "token")
    url = profile["url"].rstrip("/")

    if method == "token":
        token = auth.get("token")
        if not token:
            raise salt.exceptions.CommandExecutionError(
                "vault_salt_sdb: auth:method is 'token' but auth:token is not set"
            )
        return token

    if method == "approle":
        role_id = auth.get("role_id")
        secret_id = auth.get("secret_id")
        if not role_id or not secret_id:
            raise salt.exceptions.CommandExecutionError(
                "vault_salt_sdb: approle requires auth:role_id and auth:secret_id"
            )
        ckey = hashlib.sha256("{}|approle|{}".format(url, role_id).encode()).hexdigest()
        return _login(
            profile, url, "auth/approle/login",
            {"role_id": role_id, "secret_id": secret_id},
            ckey, force, "AppRole",
        )

    if method == "jwt":
        # GitLab CI OIDC: exchange the job's id_tokens JWT for a short-lived Vault token.
        role = auth.get("role")
        if not role:
            raise salt.exceptions.CommandExecutionError(
                "vault_salt_sdb: jwt auth requires auth:role"
            )
        mount = auth.get("mount", "jwt")
        jwt = _jwt_token(auth)
        ckey = hashlib.sha256("{}|jwt|{}|{}".format(url, mount, role).encode()).hexdigest()
        return _login(
            profile, url, "auth/{}/login".format(mount),
            {"role": role, "jwt": jwt},
            ckey, force, "JWT",
        )

    raise salt.exceptions.CommandExecutionError(
        "vault_salt_sdb: unsupported auth:method {!r} (use 'token', 'approle' or 'jwt')".format(method)
    )


# --------------------------------------------------------------------------- #
# KV version
# --------------------------------------------------------------------------- #
def _detect_kv_version(profile, url, mount):
    """Return (version, confirmed)."""
    try:
        token = _token(profile)
        r = _request(
            profile, "GET", "{}/v1/sys/internal/ui/mounts/{}".format(url, mount),
            headers={"X-Vault-Token": token},
        )
    except _VaultUnreachable:
        log.warning("vault_salt_sdb: Vault unreachable while detecting KV version of %r; assuming v2", mount)
        return 2, False

    if r.status_code == 200:
        try:
            opts = (r.json().get("data") or {}).get("options") or {}
            return int(opts.get("version", 2)), True
        except (ValueError, TypeError):
            pass
    log.warning(
        "vault_salt_sdb: KV version detect for %r returned HTTP %s; assuming v2 "
        "(grant read on sys/internal/ui/mounts/%s, or set kv_version explicitly)",
        mount, r.status_code, mount,
    )
    return 2, False


def _kv_version(profile, url, mount):
    if profile.get("kv_version"):
        return int(profile["kv_version"])
    cache = _load_cache(profile)
    ckey = "{}|{}".format(url, mount)
    if ckey in cache["kv"]:
        return cache["kv"][ckey]
    version, confirmed = _detect_kv_version(profile, url, mount)
    if confirmed:
        cache["kv"][ckey] = version
        _save_cache(profile)
    return version


# --------------------------------------------------------------------------- #
# read
# --------------------------------------------------------------------------- #
def _read_secret(profile, url, mount, path):
    version = _kv_version(profile, url, mount)
    if version == 2:
        api = "{}/v1/{}/data/{}".format(url, mount, path)
    else:
        api = "{}/v1/{}/{}".format(url, mount, path)

    r = _request(profile, "GET", api, headers={"X-Vault-Token": _token(profile)})
    if r.status_code == 403:               # cached token may be stale -> refresh once
        r = _request(profile, "GET", api, headers={"X-Vault-Token": _token(profile, force=True)})

    if r.status_code == 403:
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: Vault denied access to {}/{} (403)".format(mount, path)
        )
    if r.status_code == 404:
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: secret not found: {}/{} (404)".format(mount, path)
        )
    if r.status_code == 503:
        _down(profile, "Vault sealed/unavailable (503)")
    if r.status_code >= 500:
        _down(profile, "Vault server error {}".format(r.status_code))
    if r.status_code != 200:
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: unexpected HTTP {} for {}/{}".format(r.status_code, mount, path)
        )

    try:
        body = r.json()
    except ValueError as exc:
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: invalid JSON from Vault for {}/{}: {}".format(mount, path, exc)
        )
    data = (body.get("data") or {}).get("data") if version == 2 else body.get("data")
    if not isinstance(data, dict):
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: no data at {}/{} (deleted version or empty secret?)".format(mount, path)
        )
    return data


def _extract(data, field, path):
    if field in data:
        return data[field]
    available = ", ".join(sorted(data.keys())) or "(none)"
    raise salt.exceptions.CommandExecutionError(
        "vault_salt_sdb: key '{}' not found in secret '{}'. Available keys: {}".format(
            field, path, available
        )
    )


# --------------------------------------------------------------------------- #
# sdb entrypoint
# --------------------------------------------------------------------------- #
def get(key, profile=None, **kwargs):
    profile = profile or {}
    if "url" not in profile:
        raise salt.exceptions.CommandExecutionError("vault_salt_sdb: profile is missing 'url'")
    url = profile["url"].rstrip("/")

    parts = [p for p in str(key).split("/") if p]
    if len(parts) < 3:
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: URI must be <mount>/<path>/<key>, got {!r}".format(key)
        )
    mount, field, path = parts[0], parts[-1], "/".join(parts[1:-1])
    skey = "{}|{}|{}".format(url, mount, path)
    now = time.time()

    # 0) in-memory per-render dedup: this path already resolved this process
    if skey in _RENDER_SECRETS:
        return _extract(_RENDER_SECRETS[skey], field, path)

    cache_on = bool(profile.get("cache_secrets"))
    cache_fresh_for = int(profile.get("cache_fresh_for", 60))
    cache_offline_max_age = int(profile.get("cache_offline_max_age", 3600))

    # 1) persistent freshness window -> serve from cache, no Vault call
    if cache_on and cache_fresh_for > 0:
        ent = _load_cache(profile)["secrets"].get(skey)
        if ent and (now - ent.get("cached_at", 0)) < cache_fresh_for:
            log.debug(
                "vault_salt_sdb: freshness cache hit for %s/%s (%ds old); Vault not contacted",
                mount, path, int(now - ent.get("cached_at", 0)),
            )
            _RENDER_SECRETS[skey] = ent["data"]
            return _extract(ent["data"], field, path)

    # 2) read from Vault
    try:
        data = _read_secret(profile, url, mount, path)
    except _VaultUnreachable as exc:
        # 3) outage fallback (Vault unreachable only; never on 403/404)
        if cache_on and cache_offline_max_age > 0:
            ent = _load_cache(profile)["secrets"].get(skey)
            if ent and (now - ent.get("cached_at", 0)) < cache_offline_max_age:
                log.warning(
                    "vault_salt_sdb: Vault unreachable (%s); serving CACHED secret for "
                    "%s/%s cached %ds ago",
                    exc, mount, path, int(now - ent.get("cached_at", 0)),
                )
                _RENDER_SECRETS[skey] = ent["data"]
                return _extract(ent["data"], field, path)
        raise salt.exceptions.CommandExecutionError(
            "vault_salt_sdb: Vault unreachable and no usable cache for {}/{}: {}".format(mount, path, exc)
        )

    # success
    _RENDER_SECRETS[skey] = data
    if cache_on:
        global _WARNED_PLAINTEXT
        if (profile.get("warn_plaintext_cache", True)
                and not profile.get("cache_encryption_key")
                and not _WARNED_PLAINTEXT):
            log.warning(
                "vault_salt_sdb: cache_secrets is enabled without cache_encryption_key - the "
                "value cache is stored UNENCRYPTED on disk. Set cache_encryption_key to encrypt it."
            )
            _WARNED_PLAINTEXT = True
        cache = _load_cache(profile)
        cache["secrets"][skey] = {"data": data, "cached_at": now}
        _save_cache(profile)

    return _extract(data, field, path)
