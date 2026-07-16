salt:
  master:
    version: __SALT_MASTER_VERSION__
    config:
      file_roots:
        base:
          - /srv/salt
          - /srv/files
          - /srv/salt_local
          - /srv/formulas/_salt
      interface: 0.0.0.0
      presence_events: True
      worker_threads: __SALT_MASTER_THREADS__
      sock_pool_size: __SALT_MASTER_THREADS__
      master_sign_pubkey: True
      publish_port: __SALT_MASTER_PORT_1__
      ret_port: __SALT_MASTER_PORT_2__
      ping_on_rotate: True
      #vault#extension_modules: /var/cache/salt/extmods
      #vault#vault_salt_sdb:
      #vault#  driver: vault_salt_sdb
      #vault#  url: __VAULT_SALT_SDB_URL__
      #vault#  verify: true
      #vault#  timeout: 5
      #vault#  kv_version: 2
      #vault#  outage_cooldown: 30
      #vault#  cache_secrets: true
      #vault#  cache_fresh_for: 60
      #vault#  cache_offline_max_age: 3600
      #vault#  cache_path: /root/.cache/vault_salt_sdb/cache.json
      #vault#  auth:
      #vault#    method: jwt
      #vault#    role: __VAULT_SALT_SDB_JWT_ROLE__
      #vault#  auth_file: /root/.config/vault_salt_sdb/auth.conf
      #vault#  warn_plaintext_cache: false

include:
  - salt.master_{{ grains["id"]|replace(".", "_") }}
