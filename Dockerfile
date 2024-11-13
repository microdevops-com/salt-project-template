FROM __DOCKER_IMAGE__

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ="__ADMIN_TZ__"

# Add salt repo and install salt-ssh
# salt-minion added for --local pillar tests
# 3006.6+, 3007 salt fixes:
# - https://github.com/saltstack/salt/issues/66133, https://github.com/saltstack/salt/issues/65977 (symlink following disabled)
ARG SALT_VERSION=__SALT_VERSION__
RUN if [[ $(uname -m) =~ x86_64|i386|i686 ]]; then ARCH=amd64; else ARCH=arm64; fi; \
    source /etc/os-release; \
    apt-get update -y \
    && apt-get -qy install curl wget gnupg \
    && echo "Package: salt-*" > /etc/apt/preferences.d/salt-pin-1001 \
    && echo "Pin: version ${SALT_VERSION}.*" >> /etc/apt/preferences.d/salt-pin-1001 \
    && echo "Pin-Priority: 1001" >> /etc/apt/preferences.d/salt-pin-1001 \
    && curl -fsSL https://packages.broadcom.com/artifactory/api/security/keypair/SaltProjectKey/public | tee /etc/apt/keyrings/salt-archive-keyring-2023.pgp \
    && echo "deb [signed-by=/etc/apt/keyrings/salt-archive-keyring-2023.pgp arch=amd64] https://packages.broadcom.com/artifactory/saltproject-deb/ stable main" | tee /etc/apt/sources.list.d/salt.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends openssh-client salt-common salt-minion salt-ssh \
    && sed -i -e 's/if salt.utils.verify.clean_path(root, fpath, subdir=True):/if True: #salt.utils.verify.clean_path(root, fpath, subdir=True):/' /opt/saltstack/salt/lib/python3.10/site-packages/salt/fileserver/roots.py \
    && sed -i -e 's/if not salt.utils.verify.clean_path(root, full, subdir=True):/if False: #not salt.utils.verify.clean_path(root, full, subdir=True):/' /opt/saltstack/salt/lib/python3.10/site-packages/salt/fileserver/roots.py \
    && true;

# Add sysadmws-utils for notify_devilry
COPY etc/apt/keyrings/sysadmws-apt-key.gpg /etc/apt/keyrings/sysadmws-apt-key.gpg
RUN echo "deb [signed-by=/etc/apt/keyrings/sysadmws-apt-key.gpg arch=amd64] https://repo.sysadm.ws/sysadmws-apt/ any main" >> /etc/apt/sources.list.d/sysadmws.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends sysadmws-utils-v1 mc vim telnet iputils-ping curl ccze less jq dnsutils whois \
    && /opt/microdevops/misc/install_requirements.sh

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
