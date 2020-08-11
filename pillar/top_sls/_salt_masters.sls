  '__SALT_MASTER_1_NAME__':
    - pkg.ssh_keys.sysadmws.backup_servers
    - pkg.tz.__DEFAULT_TZ__
    - pkg.locale.en_US_UTF-8
    - users.sysadmws.admins
    - ufw_simple.salt_master_non_std_ports
    - telegram.sysadmws_alarms
    - telegram.central_notifier
    - rsnapshot_backup.__CLIENT__.salt_masters_local
    - cmd_check_alert.4min
    - cmd_check_alert.salt-master
    - cmd_check_alert.salt-minion
  
  '__SALT_MASTER_2_NAME__':
    - pkg.ssh_keys.sysadmws.backup_servers
    - pkg.tz.__DEFAULT_TZ__
    - pkg.locale.en_US_UTF-8
    - users.sysadmws.admins
    - ufw_simple.salt_master_non_std_ports
    - telegram.sysadmws_alarms
    - telegram.central_notifier
    - rsnapshot_backup.__CLIENT__.salt_masters_local
    - cmd_check_alert.4min
    - cmd_check_alert.salt-master
    - cmd_check_alert.salt-minion
