#!/bin/bash
set -e

# Sanity checks
if [[ -z $1 ]]; then
	echo ARG1 is required - target dir
	exit 1
fi

if [[ -z $2 ]]; then
	echo ARG2 is required - salt/salt-ssh
	exit 1
fi

if [[ $(basename $(pwd)) != ".salt-project-template" ]]; then
	echo This script should be run from .salt-project-template
	exit 1
fi

if [[ $2 = salt ]]; then
	if [[ -z ${SALT_MINION_VERSION} ]]; then echo Var SALT_MINION_VERSION missing; exit 1; fi
	if [[ -z ${SALT_MASTER_VERSION} ]]; then echo Var SALT_MASTER_VERSION missing; exit 1; fi
	if [[ -z ${SALT_MASTER_1_NAME} ]]; then echo Var SALT_MASTER_1_NAME missing; exit 1; fi
	if [[ -z ${SALT_MASTER_1_IP} ]]; then echo Var SALT_MASTER_1_IP missing; exit 1; fi
	if [[ -z ${SALT_MASTER_1_EXT_IP} ]]; then echo Var SALT_MASTER_1_EXT_IP missing; exit 1; fi
	if [[ -z "${SALT_MASTER_1_SSH_PUB}" ]]; then echo Var SALT_MASTER_1_SSH_PUB missing; exit 1; fi
	if [[ -z ${SALT_MASTER_2_NAME} ]]; then echo Var SALT_MASTER_2_NAME missing; exit 1; fi
	if [[ -z ${SALT_MASTER_2_IP} ]]; then echo Var SALT_MASTER_2_IP missing; exit 1; fi
	if [[ -z ${SALT_MASTER_2_EXT_IP} ]]; then echo Var SALT_MASTER_2_EXT_IP missing; exit 1; fi
	if [[ -z "${SALT_MASTER_2_SSH_PUB}" ]]; then echo Var SALT_MASTER_2_SSH_PUB missing; exit 1; fi
	if [[ -z ${SALT_MASTER_PORT_1} ]]; then echo Var SALT_MASTER_PORT_1 missing; exit 1; fi
	if [[ -z ${SALT_MASTER_PORT_2} ]]; then echo Var SALT_MASTER_PORT_2 missing; exit 1; fi
	if [[ -z ${STAGING_SALT_MASTER} ]]; then echo Var STAGING_SALT_MASTER missing; exit 1; fi
fi
if [[ $2 = salt-ssh ]]; then
	if [[ -z ${DEV_RUNNER} ]]; then echo Var DEV_RUNNER missing; exit 1; fi
	if [[ -z ${PROD_RUNNER} ]]; then echo Var PROD_RUNNER missing; exit 1; fi
	if [[ -z "${SALTSSH_ROOT_ED25519_PUB}" ]]; then echo Var SALTSSH_ROOT_ED25519_PUB missing; exit 1; fi
	if [[ -z ${SALTSSH_RUNNER_SOURCE_IP} ]]; then echo Var SALTSSH_RUNNER_SOURCE_IP missing; exit 1; fi
	if [[ -z ${SALT_VERSION} ]]; then echo Var SALT_VERSION missing; exit 1; fi
fi
if [[ -z ${CLIENT} ]]; then echo Var CLIENT missing; exit 1; fi
if [[ -z ${CLIENT_FULL} ]]; then echo Var CLIENT_FULL missing; exit 1; fi
if [[ -z ${VENDOR} ]]; then echo Var VENDOR missing; exit 1; fi
if [[ -z ${VENDOR_FULL} ]]; then echo Var VENDOR_FULL missing; exit 1; fi
if [[ -z ${HB_RECEIVER_HN} ]]; then echo Var HB_RECEIVER_HN missing; exit 1; fi
if [[ -z ${HB_TOKEN} ]]; then echo Var HB_TOKEN missing; exit 1; fi
if [[ -z ${ROOT_EMAIL} ]]; then echo Var ROOT_EMAIL missing; exit 1; fi
if [[ -z ${DEFAULT_TZ} ]]; then echo Var DEFAULT_TZ missing; exit 1; fi
if [[ -z ${CLIENT_DOMAIN} ]]; then echo Var CLIENT_DOMAIN missing; exit 1; fi

# Functions

function rsync_with_delete () {
	mkdir -p $2
	rsync -a -v --delete $1/ $2/
}

function rsync_without_delete () {
	mkdir -p $2
	rsync -a -v $1/ $2/
}

function sed_inplace_common () {
	if [[ -z ${TELEGRAM_TOKEN} ]]; then
		local LOCAL_TELEGRAM_TOKEN=__not_set_in_template_install__
	else
		local LOCAL_TELEGRAM_TOKEN=${TELEGRAM_TOKEN}
	fi
	if [[ -z ${TELEGRAM_CHAT_ID} ]]; then
		local LOCAL_TELEGRAM_CHAT_ID=__not_set_in_template_install__
	else
		local LOCAL_TELEGRAM_CHAT_ID=${TELEGRAM_CHAT_ID}
	fi
	if [[ -z ${ALERTA_URL} ]]; then
		local LOCAL_ALERTA_URL=__not_set_in_template_install__
	else
		local LOCAL_ALERTA_URL=${ALERTA_URL}
	fi
	if [[ -z ${ALERTA_API_KEY} ]]; then
		local LOCAL_ALERTA_API_KEY=__not_set_in_template_install__
	else
		local LOCAL_ALERTA_API_KEY=${ALERTA_API_KEY}
	fi
	sed -i \
		-e "s/__CLIENT__/${CLIENT}/g" \
		-e "s/__CLIENT_FULL__/${CLIENT_FULL}/g" \
		-e "s/__VENDOR__/${VENDOR}/g" \
		-e "s/__VENDOR_FULL__/${VENDOR_FULL}/g" \
		-e "s/__TELEGRAM_TOKEN__/${LOCAL_TELEGRAM_TOKEN}/g" \
		-e "s/__TELEGRAM_CHAT_ID__/${LOCAL_TELEGRAM_CHAT_ID}/g" \
		-e "s#__ALERTA_URL__#${LOCAL_ALERTA_URL}#g" \
		-e "s/__ALERTA_API_KEY__/${LOCAL_ALERTA_API_KEY}/g" \
		-e "s/__HB_RECEIVER_HN__/${HB_RECEIVER_HN}/g" \
		-e "s/__HB_TOKEN__/${HB_TOKEN}/g" \
		-e "s/__ROOT_EMAIL__/${ROOT_EMAIL}/g" \
		-e "s/__DEFAULT_TZ__/${DEFAULT_TZ}/g" \
		-e "s/__CLIENT_DOMAIN__/${CLIENT_DOMAIN}/g" \
		$1
}

function sed_inplace_salt () {
	sed -i \
		-e "s/__SALT_MINION_VERSION__/${SALT_MINION_VERSION}/g" \
		-e "s/__SALT_MASTER_VERSION__/${SALT_MASTER_VERSION}/g" \
		-e "s/__SALT_MASTER_1_NAME__/${SALT_MASTER_1_NAME}/g" \
		-e "s/__SALT_MASTER_1_IP__/${SALT_MASTER_1_IP}/g" \
		-e "s/__SALT_MASTER_1_EXT_IP__/${SALT_MASTER_1_EXT_IP}/g" \
		-e "s#__SALT_MASTER_1_SSH_PUB__#${SALT_MASTER_1_SSH_PUB}#g" \
		-e "s/__SALT_MASTER_2_NAME__/${SALT_MASTER_2_NAME}/g" \
		-e "s/__SALT_MASTER_2_IP__/${SALT_MASTER_2_IP}/g" \
		-e "s/__SALT_MASTER_2_EXT_IP__/${SALT_MASTER_2_EXT_IP}/g" \
		-e "s#__SALT_MASTER_2_SSH_PUB__#${SALT_MASTER_2_SSH_PUB}#g" \
		-e "s/__SALT_MASTER_PORT_1__/${SALT_MASTER_PORT_1}/g" \
		-e "s/__SALT_MASTER_PORT_2__/${SALT_MASTER_PORT_2}/g" \
		-e "s/__STAGING_SALT_MASTER__/${STAGING_SALT_MASTER}/g" \
		-e "s/#salt#//" \
		-e "/#salt-ssh#/d" \
		$1
}

function sed_inplace_salt-ssh () {
	sed -i \
		-e "s/__DEV_RUNNER__/${DEV_RUNNER}/g" \
		-e "s/__PROD_RUNNER__/${PROD_RUNNER}/g" \
		-e "s#__SALTSSH_ROOT_ED25519_PUB__#${SALTSSH_ROOT_ED25519_PUB}#g" \
		-e "s/__SALTSSH_RUNNER_SOURCE_IP__/${SALTSSH_RUNNER_SOURCE_IP}/g" \
		-e "s/__SALT_VERSION__/${SALT_VERSION}/g" \
		-e "s/#salt-ssh#//" \
		-e "/#salt#/d" \
		$1
}

function add_submodule () {
	pushd $2
	git submodule status | awk '{print $2}' | grep -q -e "$1" || git submodule add --force --name $1 -b master -- $3 $1
	popd
}

function move_to_templated_dir () {
	mkdir -p $2
	mv -f $1/* $2
	rm -rf $1
}

# Copy templates

rsync_with_delete .githooks $1/.githooks

rsync_without_delete salt_local $1/salt_local

rsync_without_delete files $1/files

move_to_templated_dir $1/files/notify_devilry/__VENDOR__ $1/files/notify_devilry/${VENDOR}

sed_inplace_common $1/files/notify_devilry/${VENDOR}/notify_devilry.yaml
# Enable alerta in notify_devilry if needed vars set
if [[ -n ${ALERTA_URL} && -n ${ALERTA_API_KEY} ]]; then
	sed -i -e 's/#alerta#//' $1/files/notify_devilry/${VENDOR}/notify_devilry.yaml
# Else if no alerta enable telegram in notify_devilry if needed vars set
# No sense in telegram chain if alerta enabled - dups
elif [[ -n ${TELEGRAM_TOKEN} && -n ${TELEGRAM_CHAT_ID} ]]; then
	sed -i -e 's/#telegram#//' $1/files/notify_devilry/${VENDOR}/notify_devilry.yaml
fi

rsync_without_delete formulas $1/formulas
add_submodule sysadmws-formula $1/formulas https://github.com/sysadmws/sysadmws-formula.git
add_submodule users-formula $1/formulas https://github.com/sysadmws/users-formula.git
add_submodule postgres-formula $1/formulas https://github.com/sysadmws/postgres-formula.git
add_submodule vim-formula $1/formulas https://github.com/sysadmws/vim-formula.git
add_submodule pip-formula $1/formulas https://github.com/sysadmws/pip-formula.git
add_submodule salt-cloudflare $1/formulas https://github.com/sysadmws/salt-cloudflare.git
add_submodule .gitlab-server-job $1 https://github.com/sysadmws/gitlab-server-job
add_submodule .gitlab-ci-functions $1 https://github.com/sysadmws/gitlab-ci-functions

rsync_without_delete pillar $1/pillar

rm -rf $1/pillar/ip/example
rm -f $1/pillar/ufw_simple/vars.jinja.example
rm -f $1/pillar/top_sls/srv1.example.com.example

move_to_templated_dir $1/pillar/bootstrap/__CLIENT__ $1/pillar/bootstrap/${CLIENT}
rm -f $1/pillar/bootstrap/${CLIENT}/srv1_example_com.sls.example
mv -f $1/pillar/bootstrap/__CLIENT__.sls $1/pillar/bootstrap/${CLIENT}.sls
sed_inplace_common $1/pillar/bootstrap/${CLIENT}.sls

move_to_templated_dir $1/pillar/pkg/__VENDOR__ $1/pillar/pkg/${VENDOR}
sed_inplace_common $1/pillar/pkg/${VENDOR}/forward_root_email.sls

mv -f $1/pillar/telegram/__VENDOR___alarms.sls $1/pillar/telegram/${VENDOR}_alarms.sls
sed_inplace_common $1/pillar/telegram/${VENDOR}_alarms.sls

move_to_templated_dir $1/pillar/heartbeat_mesh/__VENDOR__ $1/pillar/heartbeat_mesh/${VENDOR}
sed_inplace_common $1/pillar/heartbeat_mesh/${VENDOR}/sender.sls

mv -f $1/pillar/notify_devilry/__VENDOR__.sls $1/pillar/notify_devilry/${VENDOR}.sls
sed_inplace_common $1/pillar/notify_devilry/${VENDOR}.sls

if [[ $2 = salt ]]; then
	sed_inplace_common $1/pillar/salt/minion.sls
	sed_inplace_salt $1/pillar/salt/minion.sls
	sed_inplace_common $1/pillar/salt/master.sls
	sed_inplace_salt $1/pillar/salt/master.sls
	sed_inplace_common $1/pillar/top_sls/_salt_masters.sls
	sed_inplace_salt $1/pillar/top_sls/_salt_masters.sls
	sed_inplace_common $1/pillar/top_sls/_top.sls
	sed_inplace_salt $1/pillar/top_sls/_top.sls
	sed_inplace_common $1/pillar/ufw_simple/salt_master_non_std_ports.sls
	sed_inplace_salt $1/pillar/ufw_simple/salt_master_non_std_ports.sls
	sed_inplace_common $1/pillar/staging/staging.sls
	sed_inplace_salt $1/pillar/staging/staging.sls
	rm -f $1/pillar/ufw_simple/ssh_from_salt-ssh_runners.sls
elif [[ $2 = salt-ssh ]]; then
	rm -rf $1/pillar/salt
	rm -f $1/pillar/top_sls/_salt_masters.sls
	sed_inplace_common $1/pillar/top_sls/_top.sls
	sed_inplace_salt-ssh $1/pillar/top_sls/_top.sls
	rm -f $1/pillar/ufw_simple/salt_master_non_std_ports.sls
	rm -rf $1/pillar/staging
	sed_inplace_common $1/pillar/ufw_simple/ssh_from_salt-ssh_runners.sls
	sed_inplace_salt-ssh $1/pillar/ufw_simple/ssh_from_salt-ssh_runners.sls
fi

rsync_with_delete pillar/sysadmws-utils $1/pillar/sysadmws-utils

move_to_templated_dir $1/pillar/rsnapshot_backup/__CLIENT__ $1/pillar/rsnapshot_backup/${CLIENT}
if [[ $2 = salt ]]; then
	sed_inplace_common $1/pillar/rsnapshot_backup/${CLIENT}/salt_masters_local.sls
	sed_inplace_salt $1/pillar/rsnapshot_backup/${CLIENT}/salt_masters_local.sls
elif [[ $2 = salt-ssh ]]; then
	rm -f $1/pillar/rsnapshot_backup/${CLIENT}/salt_masters_local.sls
fi

move_to_templated_dir $1/pillar/pkg/ssh_keys/__CLIENT__ $1/pillar/pkg/ssh_keys/${CLIENT}
if [[ $2 = salt ]]; then
	sed_inplace_common $1/pillar/pkg/ssh_keys/${CLIENT}/salt_masters.sls
	sed_inplace_salt $1/pillar/pkg/ssh_keys/${CLIENT}/salt_masters.sls
	rm -f $1/pillar/pkg/ssh_keys/${CLIENT}/salt-ssh_runners.sls
elif [[ $2 = salt-ssh ]]; then
	sed_inplace_common $1/pillar/pkg/ssh_keys/${CLIENT}/salt-ssh_runners.sls
	sed_inplace_salt-ssh $1/pillar/pkg/ssh_keys/${CLIENT}/salt-ssh_runners.sls
	rm -f $1/pillar/pkg/ssh_keys/${CLIENT}/salt_masters.sls
fi

rsync_with_delete scripts $1/scripts

rsync_without_delete salt $1/salt

cp -f .gitignore $1/.gitignore

cp -f .git_pull.sh $1/.git_pull.sh

if [[ $2 = salt ]]; then
	cp -f .gitlab-ci.yml.salt $1/.gitlab-ci.yml
	sed_inplace_common $1/.gitlab-ci.yml
	sed_inplace_salt $1/.gitlab-ci.yml
elif [[ $2 = salt-ssh ]]; then
	cp -f .gitlab-ci.yml.salt-ssh $1/.gitlab-ci.yml
	sed_inplace_common $1/.gitlab-ci.yml
	sed_inplace_salt-ssh $1/.gitlab-ci.yml
fi

# Docker is for both salt and salt-ssh
cp -f Dockerfile $1/Dockerfile
sed_inplace_common $1/Dockerfile
cp -f entrypoint.sh $1/entrypoint.sh
mkdir -p $1/etc/salt
cp -f etc/salt/master $1/etc/salt/master

# Get inside templated repo
pushd $1

# Init submodules
git submodule init
git submodule update --recursive -f --checkout
# Pull fresh masters of submodules
git submodule foreach "git checkout master && git pull"
git submodule foreach --recursive git pull

# .pipeline-cache is not used anymore
rm -rf .pipeline-cache
# salt/cloud is not used anymore
rm -f salt/cloud
# salt/unit_status_alert is not used anymore
rm -f salt/unit_status_alert

# Return back
popd
