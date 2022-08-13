ssh_keys:
  salt-ssh_runners:
    user: root
    present:
      # Salt-SSH Runners
      - __SALTSSH_ROOT_ED25519_PUB__
