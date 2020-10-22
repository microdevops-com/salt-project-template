# About
Project Template for Salt Masters /srv.

# Prepare the repository
Create empty Git repo:
```
mkdir example-salt
cd example-salt
git init 
```

Add this repo as Git Submodule to a project:
```
git submodule add --name .salt-project-template -b master -- https://github.com/sysadmws/salt-project-template .salt-project-template
```

Copy example `template_install.sh` from template to the repo:
```
cp .salt-project-template/template_install.sh.example template_install.sh
```

Edit `template_install.sh` depending on your needs.

Run template install:
```
./template_install.sh
```

Fill the repo with some additional data:
- `README.md`
- `pillar/top_sls` files (see pillar/top_sls/srv1.example.com.example)
- `pillar/users/example/admins.sls`
- `pillar/ip/example.jinja` (see pillar/ip/example.jinja.example)
- `pillar/ufw_simple/vars.jinja` (see pillar/ufw_simple/vars.jinja.example)

For Salt-SSH:
- `etc/salt/roster` (see roster.example in `.salt-project-template`)

# Use the repository
Either push to GitLab and pipeline should deploy depo code to Salt Masters or build the docker image
Then use [Gitlab Pipelines](https://github.com/sysadmws/gitlab-server-job) to run salt/salt-ssh.

Or build and run locally for Salt-SSH with SSH Agent:
```
docker build --pull -t example-salt:latest .
docker run -it --rm -v $SSH_AUTH_SOCK:/root/.ssh-agent -e SSH_AUTH_SOCK=/root/.ssh-agent example-salt:latest
salt-ssh srv1.example.com test.ping
```
