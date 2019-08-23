salt:
  minion:
    version: __SALT_MINION_VERSION__
    hosts:
      - name: __SALT_MASTER_1_NAME__
        ip: __SALT_MASTER_1_IP__
      - name: __SALT_MASTER_2_NAME__
        ip: __SALT_MASTER_2_IP__
    config:
      master:
        - __SALT_MASTER_1_NAME__
        - __SALT_MASTER_2_NAME__
      grains:
        fqdn: {{ grains['fqdn'] }}
    grains_file_rm: True
