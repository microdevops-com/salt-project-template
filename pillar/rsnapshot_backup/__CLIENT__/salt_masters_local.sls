rsnapshot_backup:
  sources:

    SALT_MASTER_1_NAME:
      - type: RSYNC_SSH
        data:
          - UBUNTU
          - /var/cache/salt
          - /srv
        checks:
          - type: .backup
        backups:
          - host: SALT_MASTER_1_NAME
            path: /var/backups/SALT_MASTER_1_NAME

    SALT_MASTER_2_NAME:
      - type: RSYNC_SSH
        data:
          - UBUNTU
          - /var/cache/salt
          - /srv
        checks:
          - type: .backup
        backups:
          - host: SALT_MASTER_2_NAME
            path: /var/backups/SALT_MASTER_2_NAME
