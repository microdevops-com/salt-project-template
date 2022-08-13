ssh_keys:
  salt_masters:
    user: root
    present:
      # Salt Masters
      - __SALT_MASTER_1_SSH_PUB__
      - __SALT_MASTER_2_SSH_PUB__
