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
