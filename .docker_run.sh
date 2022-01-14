#!/bin/bash
docker run -it --rm -v $SSH_AUTH_SOCK:/root/.ssh-agent -e SSH_AUTH_SOCK=/root/.ssh-agent ${PWD##*/}:$USER -- "$@"
