#!/bin/bash
set -e

# Sanity checks
if [ -z $1 ]; then
	echo ARG1 is required - target dir
	exit 1
fi

if [ $(basename $(pwd)) != ".salt-project-template" ]; then
	echo This script should be run from .salt-project-template
	exit 1
fi
		
if [ -z ${TELEGRAM_TOKEN} ]; then echo Var missing; exit 1; fi
if [ -z ${TELEGRAM_CHAT_ID} ]; then echo Var missing; exit 1; fi
if [ -z ${ALERTA_URL} ]; then echo Var missing; exit 1; fi
if [ -z ${ALERTA_API_KEY} ]; then echo Var missing; exit 1; fi
if [ -z ${HB_RECEIVER_HN} ]; then echo Var missing; exit 1; fi
if [ -z ${HB_TOKEN} ]; then echo Var missing; exit 1; fi
if [ -z ${ROOT_EMAIL} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MINION_VERSION} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_1_NAME} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_1_IP} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_1_EXT_IP} ]; then echo Var missing; exit 1; fi
if [ -z "${SALT_MASTER_1_SSH_PUB}" ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_2_NAME} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_2_IP} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_2_EXT_IP} ]; then echo Var missing; exit 1; fi
if [ -z "${SALT_MASTER_2_SSH_PUB}" ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_PORT_1} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_PORT_2} ]; then echo Var missing; exit 1; fi
if [ -z ${STAGING_SALT_MASTER} ]; then echo Var missing; exit 1; fi
if [ -z ${CLIENT} ]; then echo Var missing; exit 1; fi
if [ -z ${DEFAULT_TZ} ]; then echo Var missing; exit 1; fi

# Functions

function rsync_with_delete () {
	mkdir -p $2
	rsync -a -v --delete $1/ $2/
}

function rsync_without_delete () {
	mkdir -p $2
	rsync -a -v $1/ $2/
}

function sed_inplace () {
	sed -i \
		-e "s/__TELEGRAM_TOKEN__/${TELEGRAM_TOKEN}/g" \
		-e "s/__TELEGRAM_CHAT_ID__/${TELEGRAM_CHAT_ID}/g" \
		-e "s#__ALERTA_URL__#${ALERTA_URL}#g" \
		-e "s/__ALERTA_API_KEY__/${ALERTA_API_KEY}/g" \
		-e "s/__HB_RECEIVER_HN__/${HB_RECEIVER_HN}/g" \
		-e "s/__HB_TOKEN__/${HB_TOKEN}/g" \
		-e "s/__ROOT_EMAIL__/${ROOT_EMAIL}/g" \
		-e "s/__SALT_MINION_VERSION__/${SALT_MINION_VERSION}/g" \
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
		-e "s/__CLIENT__/${CLIENT}/g" \
		-e "s/__DEFAULT_TZ__/${DEFAULT_TZ}/g" \
		$1
}

function add_submodule () {
	pushd $2
	git submodule status | awk '{print $2}' | grep -q -e "$1" || git submodule add --force --name $1 -b master -- $3 $1
	popd
}

# Copy templates

rsync_with_delete .githooks $1/.githooks

rsync_without_delete files $1/files
sed_inplace $1/files/notify_devilry/sysadmws/notify_devilry.yaml

rsync_without_delete formulas $1/formulas
add_submodule sysadmws-formula $1/formulas https://github.com/sysadmws/sysadmws-formula.git
add_submodule users-formula $1/formulas https://github.com/sysadmws/users-formula.git
add_submodule postgres-formula $1/formulas https://github.com/sysadmws/postgres-formula.git
add_submodule vim-formula $1/formulas https://github.com/sysadmws/vim-formula.git
add_submodule pip-formula $1/formulas https://github.com/sysadmws/pip-formula.git
add_submodule .gitlab-server-job $1 https://github.com/sysadmws/gitlab-server-job
add_submodule .gitlab-ci-functions $1 https://github.com/sysadmws/gitlab-ci-functions

rsync_without_delete pillar $1/pillar
sed_inplace $1/pillar/pkg/sysadmws/forward_root_email.sls
sed_inplace $1/pillar/salt/minion.sls
sed_inplace $1/pillar/staging/staging.sls
sed_inplace $1/pillar/telegram/sysadmws_alarms.sls
sed_inplace $1/pillar/top_sls/_salt_masters.sls
sed_inplace $1/pillar/top_sls/_top.sls
sed_inplace $1/pillar/ufw_simple/salt_master_non_std_ports.sls

rsync_with_delete pillar/sysadmws-utils $1/pillar/sysadmws-utils

mkdir -p $1/pillar/rsnapshot_backup/${CLIENT}
mv -f $1/pillar/rsnapshot_backup/__CLIENT__/* $1/pillar/rsnapshot_backup/${CLIENT}
rm -rf $1/pillar/rsnapshot_backup/__CLIENT__
sed_inplace $1/pillar/rsnapshot_backup/${CLIENT}/salt_masters_local.sls

mkdir -p $1/pillar/pkg/ssh_keys/${CLIENT}
mv -f $1/pillar/pkg/ssh_keys/__CLIENT__/* $1/pillar/pkg/ssh_keys/${CLIENT}
rm -rf $1/pillar/pkg/ssh_keys/__CLIENT__
sed_inplace $1/pillar/pkg/ssh_keys/${CLIENT}/salt_masters.sls

rsync_with_delete reactor $1/reactor

rsync_with_delete scripts $1/scripts

rsync_without_delete salt $1/salt

cp -f .gitignore $1/.gitignore

cp -f .git_pull.sh $1/.git_pull.sh

cp -f .gitlab-ci.yml $1/.gitlab-ci.yml
sed_inplace $1/.gitlab-ci.yml

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
# notify_devilry.yaml.jinja is not used anymore
rm -f files/notify_devilry/sysadmws/notify_devilry.yaml.jinja

# Return back
popd
