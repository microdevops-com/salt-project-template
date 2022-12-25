# ACHTUNG!!!
# Do not edit /srv/pillar/top.sls directly.
# It is being compiled by concatenating all files within /srv/pillar/top_sls directory.
# Compilation is triggered by post-merge git hook.

base:

  # Common pillars by OS
  'G@os:Ubuntu or G@os:Debian or G@os:CentOS':
    - match: compound
    - vim.vim
    - pkg.common
    - microdevops-utils.latest
    - notify_devilry.__VENDOR__
    - bulk_log.enabled
    - disk_alert.enabled
    - mysql_queries_log.enabled
    - mysql_replica_checker.enabled
    - mysql_increment_checker.enabled
    - pkg.__VENDOR__.forward_root_email
    #salt#- ssh_keys.__CLIENT__.salt_masters
    #salt-ssh#- ssh_keys.__CLIENT__.salt-ssh_runners
    #salt#- salt.minion
    - __UFW__.standard
    #salt#- __UFW__.ssh_from_salt_servers
    #salt-ssh#- __UFW__.ssh_from_salt-ssh_runners
    - heartbeat_mesh.__VENDOR__.sender
    - bootstrap.__CLIENT__
    - hosts.__VENDOR__
    - cmd_check_alert.common
    - cmd_check_alert.syshealth
    - ssh_keys.__VENDOR__.root
    - catch_server_mail.__VENDOR__.sentry
  
  'G@os:Windows':
    - match: compound
    #salt#- salt.minion
    - heartbeat_mesh.__VENDOR__.sender
    - hosts.__VENDOR__
