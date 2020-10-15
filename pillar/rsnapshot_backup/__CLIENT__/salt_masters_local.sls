rsnapshot_backup:
  sources:

    __SALT_MASTER_1_NAME__:
      - type: RSYNC_SSH
        data:
          #- UBUNTU
          - /var/log/salt
          #- /srv
        checks:
          - type: .backup
        backups:
          - host: __SALT_MASTER_1_NAME__
            path: /var/backups/__SALT_MASTER_1_NAME__
        #rsync_args: --exclude=/home/gitlab-runner --exclude=/var/log/journal
      - type: SUPPRESS_COVERAGE
        data:
          - UBUNTU
          - /var/log/salt
          - /srv
        remote_backups_suppress_reason: No need for remote backups
      - type: SUPPRESS_COVERAGE
        data:
          - UBUNTU
          - /srv
        local_backups_suppress_reason: No need for these backups

    __SALT_MASTER_2_NAME__:
      - type: RSYNC_SSH
        data:
          #- UBUNTU
          - /var/log/salt
          #- /srv
        checks:
          - type: .backup
        backups:
          - host: __SALT_MASTER_2_NAME__
            path: /var/backups/__SALT_MASTER_2_NAME__
        #rsync_args: --exclude=/home/gitlab-runner --exclude=/var/log/journal
      - type: SUPPRESS_COVERAGE
        data:
          - UBUNTU
          - /var/log/salt
          - /srv
        remote_backups_suppress_reason: No need for remote backups
      - type: SUPPRESS_COVERAGE
        data:
          - UBUNTU
          - /srv
        local_backups_suppress_reason: No need for these backups
