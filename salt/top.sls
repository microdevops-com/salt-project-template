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
    - ntp
    - netdata
    - pkg.pkg
    - vim.vim
    - microdevops-utils
    - bulk_log
    - disk_alert
    - mysql_queries_log
    - mysql_replica_checker
    - mysql_increment_checker
    - notify_devilry
    - cmd_check_alert
    - heartbeat_mesh.sender
    - hosts
    - ufw_simple.ufw_simple
    - ufw
    - salt.minion
    - sysctl
    - ssh_keys
    - catch_server_mail

  # All Ubuntu and Debian and CentOS
  'G@os:Ubuntu or G@os:Debian or G@os:CentOS':
    - match: compound
    - bash.completions
    - bash.misc
