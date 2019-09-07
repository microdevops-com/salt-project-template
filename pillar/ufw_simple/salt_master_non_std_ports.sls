{% from 'ufw_simple/vars.jinja' import vars with context %}

ufw_simple:
  enabled: True
  logging: 'off'
  allow:
    salt:
      proto: 'tcp'
      from:
        {{ vars['All_Servers'] }}
      to_port: '__SALT_MASTER_PORT_1__,__SALT_MASTER_PORT_2__'
  delete:
    allow:
      salt:
        proto: 'tcp'
        from:
          {{ vars['Delete_All_Servers'] }}
        to_port: '__SALT_MASTER_PORT_1__,__SALT_MASTER_PORT_2__'
