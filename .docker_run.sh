#!/usr/bin/env bash

if [[ $HOSTNAME =~ docker ]]; then
    docker run --rm -v $SSH_AUTH_SOCK:/root/.ssh-agent -e SSH_AUTH_SOCK=/root/.ssh-agent ${PWD##*/}:$USER -- "$@"
    exit $?
fi

unset dbuild drun direxpand gtpl
dir=${BASH_SOURCE[0]}
dir=${dir%/*}
. ${dir}/.docker-misc.bash
drun "$@"
