base:

  # All Windows
  'G@kernel:Windows':
    - match: compound
    - users.windows

  # All Linux
  'G@kernel:Linux':
    - match: compound
    - users.unix
    - ntp.ntp
    - netdata.netdata
    - pkg.pkg
    - vim.vim

  # All Ubuntu and Debian
  'G@os:Ubuntu or G@os:Debian':
    - match: compound
    - bash.bash_completions
    - bash.bash_misc
    - ufw_simple.ufw_simple
