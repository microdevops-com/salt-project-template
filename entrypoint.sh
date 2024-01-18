#!/usr/bin/env bash
set -e

# If we have named argument grains=, process it with yq and put it into the roster file instead of __GRAINS__ lines for all minions
for ARGUMENT in "$@"
do
	KEY=$(echo ${ARGUMENT} | cut -f1 -d=)
	VALUE=$(echo ${ARGUMENT} | cut -f2 -d=)
	case "$KEY" in
		grains) GRAINS="${VALUE}" ;;
	esac
done
if [[ "${GRAINS}" ]]; then
	# Generate grains yaml part from GRAINS and put it into unique tmp file
	GRAINS_TMP_FILE=$(mktemp)
	echo "    grains:" > "${GRAINS_TMP_FILE}"
	echo "${GRAINS}" | yq --prettyPrint --no-colors --no-doc | sed -e 's/^/      /' >> "${GRAINS_TMP_FILE}"
	# Replace all lines with __GRAINS__ to the content of GRAINS_TMP_FILE
	sed -i -e '/__GRAINS__/r '"${GRAINS_TMP_FILE}"'' -e '/__GRAINS__/d' /etc/salt/roster
	rm -f "${GRAINS_TMP_FILE}"
else
	# No grains argument - just remove all lines with __GRAINS__
	sed -i -e '/__GRAINS__/d' /etc/salt/roster
fi

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
