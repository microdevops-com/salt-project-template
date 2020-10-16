#!/usr/bin/env bash
set -e

# Check if we are in pipeline with project variables with salt-ssh key
if [[ "${SALTSSH_ROOT_ED25519_PRIV}" && "${SALTSSH_ROOT_ED25519_PUB}" ]]; then
	echo "${SALTSSH_ROOT_ED25519_PRIV}" > /root/.ssh/id_ed25519
	chmod 600 /root/.ssh/id_ed25519
	echo "${SALTSSH_ROOT_ED25519_PUB}" > /root/.ssh/id_ed25519.pub
	sed -i -e 's#__ROSTER_PRIV__#/root/.ssh/id_ed25519#g' /etc/salt/roster
# If no pipeline vars - use ssh agent forwarding in roster for manual docker image run and user salt-ssh key forwarding
else
	sed -i -e 's#__ROSTER_PRIV__#agent-forwarding#g' /etc/salt/roster
fi

exec "$@"
