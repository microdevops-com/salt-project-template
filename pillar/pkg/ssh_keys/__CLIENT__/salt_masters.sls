pkg:
  ssh-auth-keys___CLIENT__:
    when: 'PKG_PKG'
    states:
      - ssh_auth.present:
          1:
            - user: 'root'
            - names:
              - '__SALT_MASTER_1_SSH_PUB__'
              - '__SALT_MASTER_2_SSH_PUB__'
