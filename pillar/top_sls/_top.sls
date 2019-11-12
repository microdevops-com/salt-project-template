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
    - sysadmws-utils.v1_latest
    - notify_devilry.sysadmws
    - bulk_log.enabled
    - disk_alert.enabled
    - mysql_queries_log.enabled
    - mysql_replica_checker.enabled
    - pkg.sysadmws.forward_root_email
    - pkg.ssh_keys.__CLIENT__.salt_masters
    - salt.minion
    - ufw_simple.standard
    - ufw_simple.ssh_from_salt_servers
  
  'G@os:Windows':
    - match: compound
    - salt.minion
