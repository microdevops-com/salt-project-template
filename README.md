# About
Project Template for Salt Masters /srv.

# Usage
## Add this repo as Git Submodule to a project

```
git submodule add --name .salt-project-template -b master -- https://github.com/sysadmws/salt-project-template .salt-project-template
```

## Run install.sh
```
cd .salt-project-template
TELEGRAM_TOKEN=xxx \
	TELEGRAM_CHAT_ID=xxx \
	ALERTA_URL=xxx \
	ALERTA_API_KEY=xxx \
	HB_RECEIVER_HN=xxx \
	HB_TOKEN=xxx \
	ROOT_EMAIL=xxx \
	CLIENT=xxx \
	VENDOR=xxx \
	VENDOR_FULL=xxx \
	DEFAULT_TZ=xxx \
	# for salt with masters type
	SALT_MINION_VERSION=xxx \
	SALT_MASTER_1_NAME=xxx \
	SALT_MASTER_1_IP=xxx \
	SALT_MASTER_1_EXT_IP=xxx \
	SALT_MASTER_1_SSH_PUB=xxx \
	SALT_MASTER_2_NAME=xxx \
	SALT_MASTER_2_IP=xxx \
	SALT_MASTER_2_EXT_IP=xxx \
	SALT_MASTER_2_SSH_PUB=xxx \
	SALT_MASTER_PORT_1=xxx \
	SALT_MASTER_PORT_2=xxx \
	STAGING_SALT_MASTER=xxx \
	# for salt-ssh type
	DEV_RUNNER=xxx \
	PROD_RUNNER=xxx \
	SALTSSH_ROOT_ED25519_PUB=xxx \
	SALTSSH_RUNNER_SOURCE_IP=xxx \
	SALT_VERSION=xxx \
	./install.sh ../some/salt/repo/path salt|salt-ssh
```

## Build docker
Push and GitLab pipeline should build docker image.

## Salt-SSH
You can inject ssh agent into docker image:
```
docker run -it --rm -v $SSH_AUTH_SOCK:/root/.ssh-agent -e SSH_AUTH_SOCK=/root/.ssh-agent gitlab.example.com:5001/client-salt:master
```

Test:
```
salt-ssh srv1.example.com test.ping
```
