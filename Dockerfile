FROM ubuntu:focal

SHELL ["/bin/bash", "-c"]

ENV DEBIAN_FRONTEND=noninteractive
ENV TZ="__ADMIN_TZ__"

# Add salt repo and install salt-ssh
# salt-minion added for --local pillar tests
# Add python3-contextvars, https://github.com/saltstack/salt/pull/61895/files patch for 3004 to fix salt-ssh
ARG SALT_VERSION=__SALT_VERSION__
RUN if [[ "${SALT_VERSION}" == "3001" ]]; then \
      apt-get update -y \
      && apt-get -qy install wget gnupg lsb-release \
      && echo "deb https://archive.repo.saltproject.io/py3/ubuntu/$(lsb_release -sr)/amd64/${SALT_VERSION} $(lsb_release -sc) main" >> /etc/apt/sources.list.d/saltstack.list \
      && wget -qO - https://archive.repo.saltproject.io/py3/ubuntu/$(lsb_release -sr)/amd64/${SALT_VERSION}/SALTSTACK-GPG-KEY.pub | apt-key add - \
      && apt-get update -y \
      && apt-get install -y --no-install-recommends salt-minion salt-ssh openssh-client; \
    else \
      apt-get update -y \
      && apt-get -qy install wget gnupg lsb-release \
      && echo "deb http://repo.saltstack.com/py3/ubuntu/$(lsb_release -sr)/amd64/${SALT_VERSION} $(lsb_release -sc) main" >> /etc/apt/sources.list.d/saltstack.list \
      && wget -qO - https://repo.saltstack.com/py3/ubuntu/$(lsb_release -sr)/amd64/${SALT_VERSION}/SALTSTACK-GPG-KEY.pub | apt-key add - \
      && apt-get update -y \
      && apt-get install -y --no-install-recommends salt-minion salt-ssh openssh-client python3-contextvars \
      && sed -i -e 's/state = compile_template(/# Make sure SaltCacheLoader use correct fileclient\n                if context is None:\n                  context = {"fileclient": self.client}\n                state = compile_template(/' /usr/lib/python3/dist-packages/salt/state.py; \
    fi

# Add utils
RUN apt-get install -y --no-install-recommends mc vim telnet iputils-ping curl ccze less jq dnsutils

# Add sysadmws-utils for notify_devilry
RUN apt-key adv --keyserver keyserver.ubuntu.com --recv 2E7DCF8C && echo "deb https://repo.sysadm.ws/sysadmws-apt/ any main" >> /etc/apt/sources.list.d/sysadmws.list \
    && apt-get update -y \
    && apt-get install -y --no-install-recommends sysadmws-utils-v1

# Copy notify_devilry.yaml from repo
COPY files/notify_devilry/__VENDOR__/notify_devilry.yaml /opt/sysadmws/notify_devilry/notify_devilry.yaml

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
