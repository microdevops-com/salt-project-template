salt:
  minion:
    version: __SALT_MINION_VERSION__
    hosts:
{% if grains['fqdn'] == "__SALT_MASTER_1_NAME__" %}
      - name: __SALT_MASTER_1_NAME__
        ip:
          - __SALT_MASTER_1_IP__
          - 127.0.1.1
{% elif grains['fqdn'] == "__SALT_MASTER_2_NAME__" %}
      - name: __SALT_MASTER_2_NAME__
        ip:
          - __SALT_MASTER_2_IP__
          - 127.0.1.1
{% else %}
      - name: __SALT_MASTER_1_NAME__
        ip: __SALT_MASTER_1_EXT_IP__
      - name: __SALT_MASTER_2_NAME__
        ip: __SALT_MASTER_2_EXT_IP__
{% endif %}
    config:
{% if grains['fqdn'] == "__SALT_MASTER_1_NAME__" %}
      master: __SALT_MASTER_1_NAME__
      publish_port: __SALT_MASTER_PORT_1__
      master_port: __SALT_MASTER_PORT_2__
      verify_master_pubkey_sign: True
{% elif grains['fqdn'] == "__SALT_MASTER_2_NAME__" %}
      master: __SALT_MASTER_2_NAME__
      publish_port: __SALT_MASTER_PORT_1__
      master_port: __SALT_MASTER_PORT_2__
      verify_master_pubkey_sign: True
{% else %}
      master:
        - __SALT_MASTER_1_NAME__
        - __SALT_MASTER_2_NAME__
      publish_port: __SALT_MASTER_PORT_1__
      master_port: __SALT_MASTER_PORT_2__
      verify_master_pubkey_sign: True
      master_type: failover
      retry_dns: 0
      random_master: True
      master_alive_interval: 60
{% endif %}
      grains:
        fqdn: {{ grains['fqdn'] }}
    grains_file_rm: True

include:
  - salt.minion_{{ grains["fqdn"]|replace(".", "_") }}
