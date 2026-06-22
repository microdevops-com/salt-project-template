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
This template ships a custom SDB driver (`salt/extmods/sdb/vault_salt_sdb.py`) that reads
secrets from HashiCorp Vault (KV v2) instead of keeping them in plaintext pillar. The driver,
its `extmods.conf` and the `minion.d` wiring are always installed but stay dormant until a
profile is configured, so repos that do not use Vault are unaffected.

## Enable at install time
Set both vars in `template_install.sh` (presence of `VAULT_SALT_SDB_URL` turns the feature on):
```
VAULT_SALT_SDB_URL=https://vault.example.com \
VAULT_SALT_SDB_PREFIX=iac/example \
```
- `VAULT_SALT_SDB_URL` - Vault address. If unset, `install.sh` strips out the profile and the macro
  (the driver itself stays installed, dormant).
- `VAULT_SALT_SDB_PREFIX` - per-repo KV path prefix, e.g. `iac/<project>`. Required when the URL is set.

This generates `etc/salt/master.d/vault_salt_sdb.conf` (mirrored into `minion.d` via symlink).

## Runtime auth
The profile loads credentials from `/root/.config/vault_salt_sdb/auth.conf`, kept OUT of the
repo. Provide it on each Salt Master and on the salt-ssh runner (for local docker runs it is
bind-mounted automatically, see `.docker-misc.bash`):
```
mkdir -p ~/.config/vault_salt_sdb
cat > ~/.config/vault_salt_sdb/auth.conf <<'EOF'
method: approle
role_id: <role-id>
secret_id: <secret-id>
EOF
chmod 600 ~/.config/vault_salt_sdb/auth.conf
```
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

# Use the repository
Either push to GitLab and pipeline should deploy depo code to Salt Masters or build the docker image
Then use [Gitlab Pipelines](https://github.com/microdevops-com/gitlab-server-job) to run salt/salt-ssh.

Or build and run locally for Salt-SSH with SSH Agent:
```
docker build --pull -t example-salt:latest .
docker run -it --rm -v $SSH_AUTH_SOCK:/root/.ssh-agent -e SSH_AUTH_SOCK=/root/.ssh-agent example-salt:latest
salt-ssh srv1.example.com test.ping
```
