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
      worker_threads: 4
      master_sign_pubkey: True
      publish_port: __SALT_MASTER_PORT_1__
      ret_port: __SALT_MASTER_PORT_2__
      ping_on_rotate: True

include:
  - salt.master_{{ grains["fqdn"]|replace(".", "_") }}
