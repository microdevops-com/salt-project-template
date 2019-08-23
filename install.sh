#!/bin/bash

# Sanity checks
if [ -z $1 ]; then
	echo ARG1 is required - target dir
	exit 1
fi

if [ $(basename $(pwd)) != ".salt-project-template" ]; then
	echo This script should be run from .salt-project-template
	exit 1
fi
		
if [ -z ${RUNNER_TAG} ]; then echo Var missing; exit 1; fi
if [ -z ${DEPLOY_KEY} ]; then echo Var missing; exit 1; fi
if [ -z ${DEPLOY_USER} ]; then echo Var missing; exit 1; fi
if [ -z ${TELEGRAM_TOKEN} ]; then echo Var missing; exit 1; fi
if [ -z ${TELEGRAM_CHAT_ID} ]; then echo Var missing; exit 1; fi
if [ -z ${ROOT_EMAIL} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MINION_VERSION} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_1_NAME} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_1_IP} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_2_NAME} ]; then echo Var missing; exit 1; fi
if [ -z ${SALT_MASTER_2_IP} ]; then echo Var missing; exit 1; fi
if [ -z ${STAGING_SALT_MASTER} ]; then echo Var missing; exit 1; fi

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
		-e "s/__RUNNER_TAG__/${RUNNER_TAG}/g" \
		-e "s/__DEPLOY_KEY__/${DEPLOY_KEY}/g" \
		-e "s/__DEPLOY_USER__/${DEPLOY_USER}/g" \
		-e "s/__TELEGRAM_TOKEN__/${TELEGRAM_TOKEN}/g" \
		-e "s/__TELEGRAM_CHAT_ID__/${TELEGRAM_CHAT_ID}/g" \
		-e "s/__ROOT_EMAIL__/${ROOT_EMAIL}/g" \
		-e "s/__SALT_MINION_VERSION__/${SALT_MINION_VERSION}/g" \
		-e "s/__SALT_MASTER_1_NAME__/${SALT_MASTER_1_NAME}/g" \
		-e "s/__SALT_MASTER_1_IP__/${SALT_MASTER_1_IP}/g" \
		-e "s/__SALT_MASTER_2_NAME__/${SALT_MASTER_2_NAME}/g" \
		-e "s/__SALT_MASTER_2_IP__/${SALT_MASTER_2_IP}/g" \
		-e "s/__STAGING_SALT_MASTER__/${STAGING_SALT_MASTER}/g" \
		$1
}

function add_submodule () {
	pushd $2
	git submodule add --force --name $1 -b master -- $3
	popd
}

# Copy templates

rsync_with_delete .githooks $1/.githooks

mkdir -p $1/.gitlab-ci

rsync_without_delete files $1/files
sed_inplace $1/files/notify_devilry/sysadmws/notify_devilry.yaml.jinja

rsync_without_delete formulas $1/formulas
add_submodule sysadmws-formula $1/formulas https://github.com/sysadmws/sysadmws-formula.git
add_submodule users-formula $1/formulas https://github.com/sysadmws/users-formula.git
add_submodule postgres-formula $1/formulas https://github.com/sysadmws/postgres-formula.git
add_submodule vim-formula $1/formulas https://github.com/sysadmws/vim-formula.git
add_submodule pip-formula $1/formulas https://github.com/sysadmws/pip-formula.git
add_submodule lxd-formula $1/formulas https://github.com/sysadmws/lxd-formula.git

rsync_without_delete pillar $1/pillar
sed_inplace $1/pillar/pkg/sysadmws/forward_root_email.sls
sed_inplace $1/pillar/salt/minion.sls
sed_inplace $1/pillar/staging/staging.sls
sed_inplace $1/pillar/telegram/sysadmws_alarms.sls

rsync_with_delete reactor $1/reactor

rsync_without_delete salt $1/salt

cp .gitignore $1/.gitignore

cp .gitlab-ci.yml $1/.gitlab-ci.yml
sed_inplace $1/.gitlab-ci.yml

# Init submodules
pushd $1
git submodule init
git submodule update --recursive -f --checkout
popd
