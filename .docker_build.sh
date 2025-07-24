#!/bin/bash

# This script is intended to be run from the root of the repository.
if [[ "${BASH_SOURCE[0]}" != "./.docker_build.sh" ]]; then
    echo "This script must be run from the root of the repository."
    exit 1
fi

docker build --pull -t ${PWD##*/}:$USER .
