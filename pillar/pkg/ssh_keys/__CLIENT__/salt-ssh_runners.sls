pkg:
  ssh-auth-keys___CLIENT___from-salt-ssh_runners:
    when: 'PKG_PKG'
    states:
      - ssh_auth.present:
          1:
            - user: 'root'
            - names:
              - '__SALTSSH_ROOT_ED25519_PUB__'
