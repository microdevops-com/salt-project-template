base:

  # All Windows
  'G@kernel:Windows':
    - match: compound
    - users.windows

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
    - heartbeat_mesh.sysadmws.sender

  # All Ubuntu and Debian
  'G@os:Ubuntu or G@os:Debian':
    - match: compound
    - bash.bash_completions
    - bash.bash_misc
    - ufw_simple.ufw_simple
