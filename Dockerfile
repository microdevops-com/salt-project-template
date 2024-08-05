FROM __DOCKER_IMAGE__

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ="__ADMIN_TZ__"

# Add salt repo and install salt-ssh
# salt-minion added for --local pillar tests
# 3004 salt fixes:
# - https://github.com/saltstack/salt/pull/61895/files
# - https://github.com/saltstack/salt/pull/61064
# 3006.6+, 3007 salt fixes:
# - https://github.com/saltstack/salt/issues/66133, https://github.com/saltstack/salt/issues/65977 (symlink following disabled)
COPY etc/files/3004/_compat.py /etc/files/3004/_compat.py
ARG SALT_VERSION=__SALT_VERSION__
RUN   if [[ $(uname -m) =~ x86_64|i386|i686 ]]; then ARCH=amd64; else ARCH=arm64; fi; \
      source /etc/os-release; \
      if [[ "${SALT_VERSION}" == "3001" ]]; then \
      apt-get update -y \
      && apt-get -qy install wget gnupg \
      && echo "deb https://archive.repo.saltproject.io/py3/${ID}/${VERSION_ID}/${ARCH}/${SALT_VERSION} ${VERSION_CODENAME} main" >> /etc/apt/sources.list.d/saltstack.list \
      && wget -qO - https://archive.repo.saltproject.io/py3/${ID}/${VERSION_ID}/${ARCH}/${SALT_VERSION}/SALTSTACK-GPG-KEY.pub | apt-key add - \
      && apt-get update -y \
      && apt-get install -y --no-install-recommends salt-minion salt-ssh openssh-client \
      && true; \
    elif [[ "${SALT_VERSION}" == "3004" ]]; then \
      apt-get update -y \
      && apt-get -qy install wget gnupg \
      && echo "deb http://repo.saltstack.com/py3/${ID}/${VERSION_ID}/${ARCH}/${SALT_VERSION} ${VERSION_CODENAME} main" >> /etc/apt/sources.list.d/saltstack.list \
      && wget -qO - https://repo.saltstack.com/py3/${ID}/${VERSION_ID}/${ARCH}/${SALT_VERSION}/SALTSTACK-GPG-KEY.pub | apt-key add - \
      && apt-get update -y \
      && apt-get install -y --no-install-recommends salt-minion salt-ssh openssh-client python3-contextvars \
      && sed -i -e 's/state = compile_template(/# Make sure SaltCacheLoader use correct fileclient\n                if context is None:\n                  context = {"fileclient": self.client}\n                state = compile_template(/' /usr/lib/python3/dist-packages/salt/state.py \
      && cp -f /etc/files/3004/_compat.py /usr/lib/python3/dist-packages/salt/_compat.py \
      && true; \
    elif [[ "${SALT_VERSION}" == "3006" ]]; then \
      apt-get update -y \
      && apt-get -qy install curl wget gnupg \
      && curl -fsSL -o /etc/apt/keyrings/salt-archive-keyring-2023.gpg https://repo.saltproject.io/salt/py3/${ID}/${VERSION_ID}/${ARCH}/SALT-PROJECT-GPG-PUBKEY-2023.gpg \
      && echo "deb [signed-by=/etc/apt/keyrings/salt-archive-keyring-2023.gpg arch=${ARCH}] https://repo.saltproject.io/salt/py3/${ID}/${VERSION_ID}/${ARCH}/${SALT_VERSION} ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/salt.list \
      && apt-get update -y \
      && apt-get install -y --no-install-recommends salt-minion salt-ssh openssh-client python-is-python3 \
      && sed -i -e 's/if salt.utils.verify.clean_path(root, fpath, subdir=True):/if True: #salt.utils.verify.clean_path(root, fpath, subdir=True):/' /opt/saltstack/salt/lib/python3.10/site-packages/salt/fileserver/roots.py \
      && sed -i -e 's/if not salt.utils.verify.clean_path(root, full, subdir=True):/if False: #not salt.utils.verify.clean_path(root, full, subdir=True):/' /opt/saltstack/salt/lib/python3.10/site-packages/salt/fileserver/roots.py \
      && true; \
    else \
      apt-get update -y \
      && apt-get -qy install curl wget gnupg \
      && curl -fsSL -o /etc/apt/keyrings/salt-archive-keyring-2023.gpg https://repo.saltproject.io/salt/py3/${ID}/${VERSION_ID}/${ARCH}/SALT-PROJECT-GPG-PUBKEY-2023.gpg \
      && echo "deb [signed-by=/etc/apt/keyrings/salt-archive-keyring-2023.gpg arch=${ARCH}] https://repo.saltproject.io/salt/py3/${ID}/${VERSION_ID}/${ARCH}/${SALT_VERSION} ${VERSION_CODENAME} main" > /etc/apt/sources.list.d/salt.list \
      && apt-get update -y \
      && apt-get install -y --no-install-recommends salt-minion salt-ssh openssh-client \
      && sed -i -e 's/if salt.utils.verify.clean_path(root, fpath, subdir=True):/if True: #salt.utils.verify.clean_path(root, fpath, subdir=True):/' /opt/saltstack/salt/lib/python3.10/site-packages/salt/fileserver/roots.py \
      && sed -i -e 's/if not salt.utils.verify.clean_path(root, full, subdir=True):/if False: #not salt.utils.verify.clean_path(root, full, subdir=True):/' /opt/saltstack/salt/lib/python3.10/site-packages/salt/fileserver/roots.py \
      && true; \
    fi

# Add sysadmws-utils for notify_devilry
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 2E7DCF8C && echo "deb [arch=amd64] https://repo.sysadm.ws/sysadmws-apt/ any main" >> /etc/apt/sources.list.d/sysadmws.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends sysadmws-utils-v1 mc vim telnet iputils-ping curl ccze less jq dnsutils whois

# Add yq
RUN wget -qO /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 \
    && chmod +x /usr/local/bin/yq

# Copy notify_devilry.yaml from repo
COPY files/notify_devilry/__VENDOR__/notify_devilry.yaml /opt/sysadmws/notify_devilry/notify_devilry.yaml

# Substitute all {{ ... }} in notify_devilry.yaml with None to make it valid yaml
RUN sed -i -e 's/{{ .* }}/None/g' /opt/sysadmws/notify_devilry/notify_devilry.yaml

# Cleanup
RUN rm -rf /var/lib/apt/lists/*

# Entrypoint with roster and salt-ssh key preparations and bash as default cmd
COPY entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]
CMD ["/bin/bash"]

# Fill the Salt in (this and next step should be in the end as they change layers each time)
RUN mkdir -p -m 700 /root/.ssh
RUN mkdir -p /srv /ssh-csocks
COPY etc/ssh/ssh_config /etc/ssh/ssh_config
COPY formulas /srv/formulas
COPY salt /srv/salt
COPY salt_local /srv/salt_local
COPY scripts /srv/scripts
COPY include /srv/include
COPY .check_pillar_for_roster.sh /.check_pillar_for_roster.sh
COPY .salt-ssh-hooks /.salt-ssh-hooks
COPY etc/salt/master /etc/salt/master
COPY etc/salt/master.d /etc/salt/master.d
COPY etc/salt/roster* /etc/salt/
COPY README.md /srv/README.md
COPY files /srv/files
COPY pillar /srv/pillar

# Prepare pillar top.sls
WORKDIR /srv
RUN cat pillar/top_sls/_top.sls > pillar/top.sls && echo "" >> pillar/top.sls
RUN find pillar/top_sls \( \( -type f -o -type l \) -not -name _top.sls -a -not -name *.swp \) -print0 | sort -z | xargs -i -0 bash -c "cat {} >> pillar/top.sls; echo "" >> pillar/top.sls"
