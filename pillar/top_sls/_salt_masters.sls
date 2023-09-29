  '__SALT_MASTER_1_NAME__':
    - pkg.tz.__DEFAULT_TZ__
    - pkg.locale.en_US_UTF-8
    - users.__VENDOR__.admins
    - __UFW__.salt_master_non_std_ports
    - rsnapshot_backup.__CLIENT__.salt_masters_local
    - cmd_check_alert.salt-master
    - cmd_check_alert.salt-minion
    - cmd_check_alert.cpu_load_c_1500_1200_1000_f_2000_1700_1500
    - salt.master
  
  '__SALT_MASTER_2_NAME__':
    - pkg.tz.__DEFAULT_TZ__
    - pkg.locale.en_US_UTF-8
    - users.__VENDOR__.admins
    - __UFW__.salt_master_non_std_ports
    - rsnapshot_backup.__CLIENT__.salt_masters_local
    - cmd_check_alert.salt-master
    - cmd_check_alert.salt-minion
    - cmd_check_alert.cpu_load_c_1500_1200_1000_f_2000_1700_1500
    - salt.master
