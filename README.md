# About
Project Template for Salt Masters /srv.

# Prepare the repository
Create empty Git repo:
```
mkdir example-salt
cd example-salt
git init 
```

Add this repo as Git Submodule to a project:
```
git submodule add --name .salt-project-template -b master -- https://github.com/microdevops-com/salt-project-template .salt-project-template
```

Copy example `template_install.sh` from template to the repo:
```
cp .salt-project-template/template_install.sh.example template_install.sh
```

Edit `template_install.sh` depending on your needs.

Run template install:
```
./template_install.sh
```

Fill the repo with some additional data:
- `README.md`
- `pillar/top_sls` files (see pillar/top_sls/srv1.example.com.example)
- `pillar/bootstrap` files (see pillar/bootstrap/.../srv1_example_com.example)
- `pillar/users/example/admins.sls`
- `pillar/ip/example/example.sls` (see pillar/ip/example/example.sls.example)
- `pillar/ufw_simple/vars.jinja` (see pillar/ufw_simple/vars.jinja.example) or `pillar/ufw/vars.jinja` (see pillar/ufw/vars.jinja.example)
- `pillar/hosts/example.sls` (see https://github.com/microdevops-com/microdevops-formula/blob/master/hosts/pillar.example - static hosts file, recommended to distribute heartbeat_receivers, alerta hosts here)

For Salt-SSH:
- `etc/salt/roster` (see roster.example in `.salt-project-template`)

# Secrets with Vault (vault_salt_sdb)
This template ships a custom SDB driver (`salt/_sdb/vault_salt_sdb.py`) that reads
secrets from HashiCorp Vault (KV v2) instead of keeping them in plaintext pillar. The driver,
its `extmods.conf` and the `minion.d` wiring are always installed but stay dormant until a
profile is configured, so repos that do not use Vault are unaffected.

## Enable at install time
Set the three vars in `template_install.sh` (presence of `VAULT_SALT_SDB_URL` turns the feature on):
```
VAULT_SALT_SDB_URL=https://vault.example.com \
VAULT_SALT_SDB_PREFIX=iac/example \
VAULT_SALT_SDB_JWT_ROLE=salt-ci-example \
```
- `VAULT_SALT_SDB_URL` - Vault address. If unset, `install.sh` strips out the profile, the macro
  and the CI OIDC lines (the driver itself stays installed, dormant).
- `VAULT_SALT_SDB_PREFIX` - per-repo KV path prefix, e.g. `iac/<project>`. Required when the URL is set.
- `VAULT_SALT_SDB_JWT_ROLE` - Vault jwt auth role name for CI (see *CI auth* below). Required when
  the URL is set. Baked into the profile's inline `auth:` block.

This generates `etc/salt/master.d/vault_salt_sdb.conf` (mirrored into `minion.d` via symlink,
used by the salt-ssh/CI Docker image) and un-comments the `#vault#` OIDC lines in
`.gitlab-ci.yml`. For `type: salt` (persistent masters) projects, it additionally generates the
master-side profile inside `pillar/salt/master.sls` — see *Persistent masters* below.

## Runtime auth
The driver authenticates two ways from one profile, chosen by whether an `auth_file` is present:

**CI (keyless, GitLab OIDC).** The generated `.gitlab-ci.yml` gives every pillar-rendering job an
`id_tokens:` block that mints a short-lived JWT as `$VAULT_ID_TOKEN`; the profile's inline
`auth: {method: jwt, role: <VAULT_SALT_SDB_JWT_ROLE>}` exchanges it for a short-lived Vault token.
No long-lived secret is stored on the runner. Configure Vault once:
```
vault auth enable jwt
vault write auth/jwt/config oidc_discovery_url="https://gitlab.example.com" \
                            bound_issuer="https://gitlab.example.com"
vault policy write salt-ci-example - <<'EOF'
path "iac/data/example/*" { capabilities = ["read"] }
EOF
vault write auth/jwt/role/salt-ci-example - <<'EOF'
{ "role_type": "jwt", "user_claim": "project_path",
  "bound_audiences": ["https://vault.example.com"],
  "bound_claims": {"project_path": "group/subgroup/example"},
  "token_policies": ["salt-ci-example"], "token_ttl": "5m", "token_max_ttl": "10m",
  "token_no_default_policy": true }
EOF
```
The role name must match `VAULT_SALT_SDB_JWT_ROLE`; the KV read path is `<mount>/data/<project>/*`;
`bound_audiences` must equal the `aud` in `.gitlab-ci.yml` (the Vault URL). Vault must be able to
reach the GitLab OIDC discovery URL. Missing/mis-set Vault config fails the pillar check closed.

**Salt masters & local dev (AppRole).** On a persistent master the pillar is compiled by the
long-running master process, so there is no per-job OIDC token to lean on — the master authenticates
with an AppRole instead. Drop an `auth.conf` at `/root/.config/vault_salt_sdb/auth.conf` (kept OUT of
the repo); when present it OVERRIDES the inline JWT auth, so masters and local `drun` (which
bind-mounts `~/.config/vault_salt_sdb/auth.conf` automatically, see `.docker-misc.bash`) use AppRole.
The driver logs in itself, caches the token in memory, and re-authenticates when it expires — no Vault
Agent needed.

Set up the role in Vault once. Masters read the same secrets as CI, so reuse the CI read policy
(`salt-ci-example`) rather than duplicating it (create a dedicated `salt-master-example` policy only
if you want separate audit/scoping):
```
vault auth enable approle   # once per Vault

vault write auth/approle/role/salt-master-example \
    token_policies="salt-ci-example" \
    secret_id_bound_cidrs="10.0.0.11/32,10.0.0.12/32" \
    token_bound_cidrs="10.0.0.11/32,10.0.0.12/32" \
    secret_id_ttl=90d secret_id_num_uses=0 \
    token_ttl=20m token_max_ttl=1h \
    token_no_default_policy=true
```
- `token_policies` — least-privilege read policy over the KV `<mount>/data/<project>/*` paths.
- `*_bound_cidrs` — lock the role to the master IPs; a leaked `secret_id` is useless off-host.
- `secret_id_ttl=90d` — rotate quarterly; `secret_id_num_uses=0` = unlimited logins within that TTL
  (the master re-authenticates repeatedly over its lifetime).
- short `token_ttl`/`token_max_ttl` — the minted token is disposable.

Read the (non-secret) `role_id`, then hand the `secret_id` over **response-wrapped** so the raw value
never lands in provisioning logs — the master unwraps it once at setup:
```
vault read auth/approle/role/salt-master-example/role-id          # -> role_id (safe to bake in)

vault write -wrap-ttl=90s -f auth/approle/role/salt-master-example/secret-id
# prints a single-use wrapping token; then, on the master:
vault unwrap <wrapping-token>                                     # -> the real secret_id
```
Write the file on the master (root, mode 0600; for local `drun` put it at
`~/.config/vault_salt_sdb/auth.conf` instead):
```
mkdir -p /root/.config/vault_salt_sdb
cat > /root/.config/vault_salt_sdb/auth.conf <<'EOF'
method: approle
role_id: <role-id>
secret_id: <unwrapped-secret-id>
EOF
chmod 600 /root/.config/vault_salt_sdb/auth.conf
```
To rotate before `secret_id_ttl` runs out, issue a fresh wrapped `secret-id`, unwrap it on the master,
and replace the `secret_id` line. For at-rest protection you can seal `auth.conf` (or just the
`secret_id`) to the host's TPM — e.g. `systemd-creds encrypt --with-key=tpm2` — so a copied disk is
useless without that machine.

**Persistent masters (`type: salt` projects).** A real, persistent `salt-master` reads its own
separate `/etc/salt/master`, generated by the `microdevops-formula`'s `salt.master` state from
`pillar["salt"]["master"]["config"]` (`file.serialize`, not `master.d` drop-ins — this formula
doesn't use those at all). There's also no per-job GitLab OIDC token to lean on for a
long-running master process, unlike the CI case above — hence AppRole.

Earlier versions of this setup relied on manually symlinking `etc/salt/master.d/vault_salt_sdb.conf`
into the real `/etc/salt/master.d/` on each master. **Don't do that** — it was fragile (a dangling
symlink there makes `salt-master` refuse to start at all) and doesn't survive an unrelated repo
change deleting the target. As of this template, `install.sh` handles it properly: when run with
`salt` mode and `VAULT_SALT_SDB_URL` set, it also merges the same profile (with
`extension_modules` pinned to `/var/cache/salt/extmods`) directly into `pillar/salt/master.sls`,
via the same `#vault#` marker convention used in `.gitlab-ci.yml`. No file placement on the
master host needed — the config rides along with normal `salt.master` state deploys, same as any
other master config change.

The `microdevops-formula`'s `salt.master` state also syncs the driver into `extension_modules`
automatically on every apply (`salt-run saltutil.sync_sdb`, ordered right after the master
restart) — also a no-op for masters with no custom `_sdb` driver, so there's no manual sync step
to remember either.

What's still manual: dropping `auth.conf` on the master (above — AppRole credentials don't belong
in git), and actually triggering a `salt.master` state apply against the master host once the
pillar change lands (however state applies are normally triggered in this project, e.g. a
`SALT_CMD` pipeline run) — a pillar/formula change alone doesn't push itself to a running master.

Secret values are cached at `/root/.cache/vault_salt_sdb/cache.json` (mode 0600) for a short
freshness window and as an outage fallback; tune via `cache_*` keys in the profile.

## Using secrets in pillar
Import the macro and reference a secret by its path under the prefix:
```
{% from 'vault_salt_sdb.jinja' import secret %}

myapp:
  db_password: "{{ secret('app/db/password') }}"
```
`secret('app/db/password')` expands to `sdb://vault_salt_sdb/<VAULT_SALT_SDB_PREFIX>/app/db/password`.
The URI is `<mount>/<path>/<key>`: the first segment is the KV mount, the last is the field
inside the secret, the middle is the secret path. The macro keeps the per-repo prefix in one
place so secret references stay copy-paste identical across repos. You can also call the driver
directly: `{{ salt['sdb.get']('sdb://vault_salt_sdb/iac/example/app/db/password') }}`.

## Debugging
- `salt '<target>' sdb.get(...)` runs on **the target minion's own local config**, not the
  master — it does not exercise the master's AppRole/profile setup. To test server-side pillar
  compilation, use `pillar.item` instead.
- `pillar.item` on a live target returns the minion's last **cached** pillar, not a fresh
  compile. Run `salt '<target>' saltutil.refresh_pillar` first if you just changed pillar/top.sls.
- For a full traceback instead of a bare `_errors` summary, render pillar locally on the master
  while masquerading as the target's grains id: `salt-call --local --id=<target> pillar.item <key>`.
- Right after `saltutil.sync_sdb` + a master restart, a `KeyError: '<driver>.get'` can appear
  transiently for a minute or two before the sync fully propagates — retry once before assuming
  something's misconfigured.
- A missing/misnamed sdb profile silently returns the literal `sdb://...` URI as the pillar
  value instead of erroring, unless the macro passes `strict=True` (see
  `pillar/vault_salt_sdb.jinja` — this template does). A bare `{{ salt['sdb.get'](...) }}` call
  that bypasses the macro won't get this for free.

# Use the repository
Either push to GitLab and pipeline should deploy depo code to Salt Masters or build the docker image
Then use [Gitlab Pipelines](https://github.com/microdevops-com/gitlab-server-job) to run salt/salt-ssh.

Or build and run locally for Salt-SSH with SSH Agent:
```
docker build --pull -t example-salt:latest .
docker run -it --rm -v $SSH_AUTH_SOCK:/root/.ssh-agent -e SSH_AUTH_SOCK=/root/.ssh-agent example-salt:latest
salt-ssh srv1.example.com test.ping
```
