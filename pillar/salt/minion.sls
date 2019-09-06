salt:
  minion:
    version: __SALT_MINION_VERSION__
    hosts:
      - name: __SALT_MASTER_1_NAME__
        ip: __SALT_MASTER_1_IP__
      - name: __SALT_MASTER_2_NAME__
        ip: __SALT_MASTER_2_IP__
    config:
{% if grains['fqdn'] == "__SALT_MASTER_1_NAME__" %}
      master:
        - __SALT_MASTER_1_NAME__
      publish_port: 4505
      master_port: 4506
{% elif grains['fqdn'] == "__SALT_MASTER_2_NAME__" %}
      master:
        - __SALT_MASTER_2_NAME__
      publish_port: 4505
      master_port: 4506
{% else %}
      master:
        - __SALT_MASTER_1_NAME__
        - __SALT_MASTER_2_NAME__
      publish_port: __SALT_MASTER_PORT_1__
      master_port: __SALT_MASTER_PORT_2__
{% endif %}
      grains:
        fqdn: {{ grains['fqdn'] }}
    grains_file_rm: True
