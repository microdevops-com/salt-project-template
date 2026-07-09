#!/usr/bin/env bash
set -e

# If we have named argument grains=, process it with yq and put it into the roster file instead of __GRAINS__ lines for all minions
# FYI: salt-ssh --wipe ... grains.item xxx grains={...} - salt has a bug and will not wipe thin dir in /var/tmp for grains.item -> grains will be cached.
# FYI: Remove /var/tmp/..._salt to wipe grains cache for salt-ssh.
# FYI: But --wipe works fine for state.apply.
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

# Sync custom sdb modules (vault_salt_sdb) from file_roots _sdb into extension_modules.
# extension_modules lives outside /srv (see etc/salt/*/extmods.conf), so it is not part
# of the bind-mounted repo and starts empty in every fresh container. Doing it here,
# once per container startup, covers every entry point (drun's persistent container,
# plain `docker run --rm` in CI, salt-ssh, check_pillar.sh, ...) since ENTRYPOINT runs
# once at container creation, unlike `docker exec` which skips it entirely.
# Touch a marker afterwards so drun() (.docker-misc.bash) can wait for this instead of
# firing its own concurrent salt-call --local: two overlapping local salt-call runs
# race each other over /var/cache/salt and were observed to fail intermittently
# (mkdir "File exists", and even a bogus pillar render error) when run at once.
# sync_sdb only needs file_roots (to find the _sdb driver); it does not need real
# pillar data. salt-call still eagerly compiles local pillar at startup regardless of
# which function is called, matching this container's own hostname against whatever
# top.sls this repo ships - which errors loudly if a repo's top.sls assumes every
# minion ID is a real managed host (seen as e.g. "SLS 'salt.minion_<container-id>' ...
# is not available"). Point --pillar-root at an empty dir so that compile is a
# guaranteed no-op instead.
mkdir -p /tmp/empty_pillar_root
salt-call --local --pillar-root=/tmp/empty_pillar_root saltutil.sync_sdb
touch /tmp/.entrypoint-sdb-synced

exec "$@"
