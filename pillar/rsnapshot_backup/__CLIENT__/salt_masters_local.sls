rsnapshot_backup:
  sources:

    __SALT_MASTER_1_NAME__:
      - type: RSYNC_SSH
        data:
          - UBUNTU
          - /var/cache/salt
          - /srv
        checks:
          - type: .backup
        backups:
          - host: __SALT_MASTER_1_NAME__
            path: /var/backups/__SALT_MASTER_1_NAME__
      - type: SUPPRESS_COVERAGE
        data:
          - UBUNTU
          - /var/cache/salt
          - /srv
        remote_backups_suppress_reason: No need for remote backups

    __SALT_MASTER_2_NAME__:
      - type: RSYNC_SSH
        data:
          - UBUNTU
          - /var/cache/salt
          - /srv
        checks:
          - type: .backup
        backups:
          - host: __SALT_MASTER_2_NAME__
            path: /var/backups/__SALT_MASTER_2_NAME__
      - type: SUPPRESS_COVERAGE
        data:
          - UBUNTU
          - /var/cache/salt
          - /srv
        remote_backups_suppress_reason: No need for remote backups
