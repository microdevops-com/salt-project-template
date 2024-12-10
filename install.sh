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
	if [[ -z ${DEV_RUNNER} ]]; then echo Var DEV_RUNNER missing; exit 1; fi
	if [[ -z ${SALT_MINION_VERSION} ]]; then echo Var SALT_MINION_VERSION missing; exit 1; fi
	if [[ -z ${SALT_MASTER_VERSION} ]]; then echo Var SALT_MASTER_VERSION missing; exit 1; fi
	if [[ -z ${SALT_MASTER_THREADS} ]]; then echo Var SALT_MASTER_THREADS missing; exit 1; fi
	if [[ -z ${SALT_VERSION} ]]; then echo Var SALT_VERSION missing; exit 1; fi
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
fi
if [[ $2 = salt-ssh ]]; then
	if [[ -z ${DEV_RUNNER} ]]; then echo Var DEV_RUNNER missing; exit 1; fi
	if [[ -z ${PROD_RUNNER} ]]; then echo Var PROD_RUNNER missing; exit 1; fi
	if [[ -z "${SALTSSH_ROOT_ED25519_PUB}" ]]; then echo Var SALTSSH_ROOT_ED25519_PUB missing; exit 1; fi
	if [[ -z ${SALTSSH_RUNNER_SOURCE_IP_1} ]]; then echo Var SALTSSH_RUNNER_SOURCE_IP_1 missing; exit 1; fi
	if [[ -z ${SALTSSH_RUNNER_SOURCE_IP_2} ]]; then echo Var SALTSSH_RUNNER_SOURCE_IP_2 missing; exit 1; fi
	if [[ -z ${SALT_VERSION} ]]; then echo Var SALT_VERSION missing; exit 1; fi
fi
if [[ -z ${CLIENT} ]]; then echo Var CLIENT missing; exit 1; fi
if [[ -z ${CLIENT_FULL} ]]; then echo Var CLIENT_FULL missing; exit 1; fi
if [[ -z ${VENDOR} ]]; then echo Var VENDOR missing; exit 1; fi
if [[ -z ${VENDOR_FULL} ]]; then echo Var VENDOR_FULL missing; exit 1; fi
if [[ -z ${HB_RECEIVER_HN} ]]; then echo Var HB_RECEIVER_HN missing; exit 1; fi
if [[ -z ${HB_TOKEN} ]]; then echo Var HB_TOKEN missing; exit 1; fi
if [[ -z ${SENTRY_DOMAIN} ]]; then echo Var SENTRY_DOMAIN missing; exit 1; fi
if [[ -z ${SENTRY_AUTH_TOKEN} ]]; then echo Var SENTRY_AUTH_TOKEN missing; exit 1; fi
if [[ -z ${SENTRY_DSN_PUBLIC} ]]; then echo Var SENTRY_DSN_PUBLIC missing; exit 1; fi
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
	if [[ -z ${MONITORING_ENABLED} ]]; then
		MONITORING_ENABLED=True
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
		-e "s/__MONITORING_ENABLED__/${MONITORING_ENABLED}/g" \
		-e "s#__ALERTA_URL__#${LOCAL_ALERTA_URL}#g" \
		-e "s/__ALERTA_API_KEY__/${LOCAL_ALERTA_API_KEY}/g" \
		-e "s/__HB_RECEIVER_HN__/${HB_RECEIVER_HN}/g" \
		-e "s/__HB_TOKEN__/${HB_TOKEN}/g" \
		-e "s/__SENTRY_DOMAIN__/${SENTRY_DOMAIN}/g" \
		-e "s/__SENTRY_AUTH_TOKEN__/${SENTRY_AUTH_TOKEN}/g" \
		-e "s/__SENTRY_DSN_PUBLIC__/${SENTRY_DSN_PUBLIC}/g" \
		-e "s/__ROOT_EMAIL__/${ROOT_EMAIL}/g" \
		-e "s/__DEFAULT_TZ__/${DEFAULT_TZ}/g" \
		-e "s/__CLIENT_DOMAIN__/${CLIENT_DOMAIN}/g" \
		-e "s/__SALT_VERSION__/${SALT_VERSION}/g" \
		-e "s/__UFW__/${UFW}/g" \
		-e "s#__ADMIN_TZ__#$(cat /etc/timezone)#g" \
		-e "s/__DEV_RUNNER__/${DEV_RUNNER}/g" \
		-e "s/__DOCKER_IMAGE__/${DOCKER_IMAGE}/g" \
		$1
}

function sed_inplace_salt () {
	sed -i \
		-e "s/__SALT_MINION_VERSION__/${SALT_MINION_VERSION}/g" \
		-e "s/__SALT_MASTER_VERSION__/${SALT_MASTER_VERSION}/g" \
		-e "s/__SALT_MASTER_THREADS__/${SALT_MASTER_THREADS}/g" \
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
		-e "s/#salt#//" \
		-e "/#salt-ssh#/d" \
		$1
}

function sed_inplace_salt-ssh () {
	sed -i \
		-e "s/__PROD_RUNNER__/${PROD_RUNNER}/g" \
		-e "s#__SALTSSH_ROOT_ED25519_PUB__#${SALTSSH_ROOT_ED25519_PUB}#g" \
		-e "s/__SALTSSH_RUNNER_SOURCE_IP_1__/${SALTSSH_RUNNER_SOURCE_IP_1}/g" \
		-e "s/__SALTSSH_RUNNER_SOURCE_IP_2__/${SALTSSH_RUNNER_SOURCE_IP_2}/g" \
		-e "s/#salt-ssh#//" \
		-e "/#salt#/d" \
		$1
}

function add_submodule () {
	pushd $2
	# Always add force to update remote url
	git submodule add --force --name $1 -b master -- $3 $1
	popd
}

function remove_submodule () {
	pushd $1
		if [[ -d "$2/$3" ]]; then
			git rm -f "$2/$3"
			rm -rf .git/modules/$3
			git config --remove-section submodule.$3
		fi
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

rsync_without_delete .salt-ssh-hooks $1/.salt-ssh-hooks

rsync_without_delete files $1/files

move_to_templated_dir $1/files/notify_devilry/__VENDOR__ $1/files/notify_devilry/${VENDOR}

sed_inplace_common $1/files/notify_devilry/${VENDOR}/notify_devilry.yaml
sed_inplace_common $1/files/notify_devilry/${VENDOR}/notify_devilry_disabled.yaml
# Enable alerta in notify_devilry if needed vars set
if [[ -n ${ALERTA_URL} && -n ${ALERTA_API_KEY} ]]; then
	sed -i -e 's/#alerta#//' $1/files/notify_devilry/${VENDOR}/notify_devilry.yaml
	sed -i -e 's/#alerta#//' $1/files/notify_devilry/${VENDOR}/notify_devilry_disabled.yaml
# Else if no alerta enable telegram in notify_devilry if needed vars set
# No sense in telegram chain if alerta enabled - dups
elif [[ -n ${TELEGRAM_TOKEN} && -n ${TELEGRAM_CHAT_ID} ]]; then
	sed -i -e 's/#telegram#//' $1/files/notify_devilry/${VENDOR}/notify_devilry.yaml
	sed -i -e 's/#telegram#//' $1/files/notify_devilry/${VENDOR}/notify_devilry_disabled.yaml
fi

# Remove unused submodules
remove_submodule $1 formulas pip-formula
remove_submodule $1 formulas sysadmws-formula
remove_submodule $1 . .gitlab-ci-functions

rsync_without_delete formulas $1/formulas

add_submodule microdevops-formula $1/formulas https://github.com/microdevops-com/microdevops-formula.git
add_submodule users-formula $1/formulas https://github.com/microdevops-com/users-formula.git
add_submodule postgres-formula $1/formulas https://github.com/microdevops-com/postgres-formula.git
add_submodule vim-formula $1/formulas https://github.com/microdevops-com/vim-formula.git
add_submodule salt-cloudflare $1/formulas https://github.com/microdevops-com/salt-cloudflare.git
add_submodule .gitlab-server-job $1 https://github.com/microdevops-com/gitlab-server-job.git

rsync_without_delete pillar $1/pillar

rm -rf $1/pillar/ip/example
rm -f $1/pillar/ufw/vars.jinja.example
rm -f $1/pillar/ufw_simple/vars.jinja.example
rm -f $1/pillar/top_sls/srv1.example.com.example

rm -rf $1/salt/pip

move_to_templated_dir $1/pillar/bootstrap/__CLIENT__ $1/pillar/bootstrap/${CLIENT}
rm -f $1/pillar/bootstrap/${CLIENT}/srv1_example_com.sls.example
mv -f $1/pillar/bootstrap/__CLIENT__.sls $1/pillar/bootstrap/${CLIENT}.sls
sed_inplace_common $1/pillar/bootstrap/${CLIENT}.sls

move_to_templated_dir $1/pillar/heartbeat_mesh/__VENDOR__ $1/pillar/heartbeat_mesh/${VENDOR}
sed_inplace_common $1/pillar/heartbeat_mesh/${VENDOR}/sender.jinja.sls

move_to_templated_dir $1/pillar/catch_server_mail/__VENDOR__ $1/pillar/catch_server_mail/${VENDOR}
sed_inplace_common $1/pillar/catch_server_mail/${VENDOR}/sentry.jinja.sls

mv -f $1/pillar/notify_devilry/__VENDOR__.jinja.sls $1/pillar/notify_devilry/${VENDOR}.jinja.sls
sed_inplace_common $1/pillar/notify_devilry/${VENDOR}.jinja.sls

if [[ $2 = salt ]]; then
	sed_inplace_common $1/pillar/salt/minion.sls
	sed_inplace_salt $1/pillar/salt/minion.sls
	sed_inplace_common $1/pillar/salt/master.sls
	sed_inplace_salt $1/pillar/salt/master.sls
	sed_inplace_common $1/pillar/top_sls/_salt_masters.sls
	sed_inplace_salt $1/pillar/top_sls/_salt_masters.sls
	sed_inplace_common $1/pillar/top_sls/_top.sls
	sed_inplace_salt $1/pillar/top_sls/_top.sls
	sed_inplace_common $1/pillar/ufw/salt_master_non_std_ports.sls
	sed_inplace_salt $1/pillar/ufw/salt_master_non_std_ports.sls
	sed_inplace_common $1/pillar/ufw_simple/salt_master_non_std_ports.sls
	sed_inplace_salt $1/pillar/ufw_simple/salt_master_non_std_ports.sls
	rm -f $1/pillar/ufw/ssh_from_salt-ssh_runners.sls
	rm -f $1/pillar/ufw_simple/ssh_from_salt-ssh_runners.sls
elif [[ $2 = salt-ssh ]]; then
	rm -rf $1/pillar/salt
	rm -f $1/pillar/top_sls/_salt_masters.sls
	sed_inplace_common $1/pillar/top_sls/_top.sls
	sed_inplace_salt-ssh $1/pillar/top_sls/_top.sls
	rm -f $1/pillar/ufw/salt_master_non_std_ports.sls
	rm -f $1/pillar/ufw_simple/salt_master_non_std_ports.sls
	sed_inplace_common $1/pillar/ufw/ssh_from_salt-ssh_runners.sls
	sed_inplace_salt-ssh $1/pillar/ufw/ssh_from_salt-ssh_runners.sls
	sed_inplace_common $1/pillar/ufw_simple/ssh_from_salt-ssh_runners.sls
	sed_inplace_salt-ssh $1/pillar/ufw_simple/ssh_from_salt-ssh_runners.sls
fi

rsync_with_delete pillar/microdevops-utils $1/pillar/microdevops-utils

move_to_templated_dir $1/pillar/rsnapshot_backup/__CLIENT__ $1/pillar/rsnapshot_backup/${CLIENT}
if [[ $2 = salt ]]; then
	sed_inplace_common $1/pillar/rsnapshot_backup/${CLIENT}/salt_masters_local.sls
	sed_inplace_salt $1/pillar/rsnapshot_backup/${CLIENT}/salt_masters_local.sls
elif [[ $2 = salt-ssh ]]; then
	rm -f $1/pillar/rsnapshot_backup/${CLIENT}/salt_masters_local.sls
fi

move_to_templated_dir $1/pillar/ssh_keys/__CLIENT__ $1/pillar/ssh_keys/${CLIENT}
if [[ $2 = salt ]]; then
	sed_inplace_common $1/pillar/ssh_keys/${CLIENT}/salt_masters.sls
	sed_inplace_salt $1/pillar/ssh_keys/${CLIENT}/salt_masters.sls
	rm -f $1/pillar/ssh_keys/${CLIENT}/salt-ssh_runners.sls
elif [[ $2 = salt-ssh ]]; then
	sed_inplace_common $1/pillar/ssh_keys/${CLIENT}/salt-ssh_runners.sls
	sed_inplace_salt-ssh $1/pillar/ssh_keys/${CLIENT}/salt-ssh_runners.sls
	rm -f $1/pillar/ssh_keys/${CLIENT}/salt_masters.sls
fi

rsync_with_delete scripts $1/scripts

rsync_without_delete salt $1/salt

cp -f .gitignore $1/.gitignore
cp -f .dockerignore $1/.dockerignore
cp -f .git_pull.sh $1/.git_pull.sh
cp -f .check_pillar_for_roster.sh $1/.check_pillar_for_roster.sh
cp -f .docker_build.sh $1/.docker_build.sh
cp -f .docker_run.sh $1/.docker_run.sh
cp -f check_pillar.sh $1/check_pillar.sh

if [[ $2 = salt ]]; then
	cp -f .gitlab-ci.yml.salt $1/.gitlab-ci.yml
	sed_inplace_common $1/.gitlab-ci.yml
	sed_inplace_salt $1/.gitlab-ci.yml
elif [[ $2 = salt-ssh ]]; then
	cp -f .gitlab-ci.yml.salt-ssh $1/.gitlab-ci.yml
	sed_inplace_common $1/.gitlab-ci.yml
	sed_inplace_salt-ssh $1/.gitlab-ci.yml
fi

# If salt version is 3006 or higher, set DOCKER_IMAGE to debian:bookworm-slim
# Else set DOCKER_IMAGE to ubuntu:focal
if [[ $(echo $SALT_VERSION | cut -d. -f1) -ge 3006 ]]; then
	DOCKER_IMAGE=debian:bookworm-slim
else
	DOCKER_IMAGE=ubuntu:focal
fi

# Docker is for both salt and salt-ssh
cp -f Dockerfile $1/Dockerfile
sed_inplace_common $1/Dockerfile
cp -f entrypoint.sh $1/entrypoint.sh
mkdir -p $1/etc/salt $1/etc/salt/master.d $1/etc/ssh
cp -Rf etc/files $1/etc
cp -Rf etc/apt $1/etc
cp -f etc/salt/master $1/etc/salt/master
cp -f etc/ssh/ssh_config $1/etc/ssh/ssh_config
rsync_without_delete etc/salt/master.d $1/etc/salt/master.d
rsync_without_delete include $1/include

# Get inside templated repo
pushd $1

if [[ -z $SUBMODULES_DONE ]]; then
    # Init submodules
    git submodule init
    git submodule update --recursive -f --checkout
    # Pull fresh masters of submodules
    git submodule foreach "git checkout master && git pull"
    git submodule foreach --recursive git pull
fi

# .pipeline-cache is not used anymore
rm -rf .pipeline-cache
# salt/cloud is not used anymore
rm -rf salt/cloud
# cleanup old state links
rm -f salt/rvm
rm -f salt/sysadmws-utils
rm -f salt/unit_status_alert
# some cmd_check_alert files are not used anymore
rm -rf files/cmd_check_alert
rm -rf pillar/cmd_check_alert/2min.sls
rm -rf pillar/cmd_check_alert/4min.sls
# remove win salt minion exe
rm -f files/salt/Salt-Minion-3001.4-Py3-AMD64-Setup.exe
# remove alerta leftovers
rm -f files/app/alerta
rm -f pillar/pkg/alerta-urlmon.sls
# remove staging leftovers
rm -rf pillar/staging
# remove old unneeded pillar
rm -f pillar/rsnapshot_backup/backup_server.sls
rm -rf pillar/rvm
rm -rf pillar/sysadmws-utils
rm -f pillar/app/syspass.jinja
rm -f pillar/pkg/forward_root_email.jinja
rm -f pillar/pkg/gitlab-ce.jinja
rm -f pillar/pkg/gitlab-ee.jinja
rm -f pillar/pkg/gitlab-runner.jinja
rm -f pillar/pkg/${VENDOR}/forward_root_email.sls
rm -f pillar/cmd_check_alert/ignore_corrected_nvme_errors.sls
# remove pkg/ssh_keys
rm -f pillar/pkg/ssh_keys/${CLIENT}/salt-ssh_runners.sls
rm -f pillar/pkg/ssh_keys/${CLIENT}/salt_masters.sls
# cleanup example mistakes
rm -f pillar/heartbeat_mesh/${VENDOR}/sender.jinja.sls.example
rm -f pillar/catch_server_mail/${VENDOR}/sentry.jinja.sls.example
rm -f pillar/notify_devilry/${VENDOR}.jinja.sls.example
rm -f etc/files/_compat.py

# Return back
popd
