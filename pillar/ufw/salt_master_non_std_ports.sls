{% from "ufw/vars.jinja" import vars with context %}

ufw:
  allow:
    salt_master_non_std_ports:
      proto: tcp
      from:
        {{ vars["All_Servers"] }}
      to_port: __SALT_MASTER_PORT_1__,__SALT_MASTER_PORT_2__
