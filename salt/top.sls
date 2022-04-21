base:

  # All Windows
  'G@kernel:Windows':
    - match: compound
    - users.windows
    - hosts

  # All Linux
  'G@kernel:Linux':
    - match: compound
    - users.unix
    - ntp.ntp
    - netdata.netdata
    - pkg.pkg
    - vim.vim
    - sysadmws-utils.sysadmws-utils
    - bulk_log.bulk_log
    - disk_alert.disk_alert
    - mysql_queries_log.mysql_queries_log
    - mysql_replica_checker.mysql_replica_checker
    - notify_devilry.notify_devilry
    - cmd_check_alert
    - heartbeat_mesh.sender
    - hosts
    - ufw_simple.ufw_simple
    - ufw
    - salt.minion

  # All Ubuntu and Debian and CentOS
  'G@os:Ubuntu or G@os:Debian or G@os:CentOS':
    - match: compound
    - bash.bash_completions
    - bash.bash_misc
