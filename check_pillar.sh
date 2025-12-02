#!/usr/bin/env bash
set -e
unset dbuild drun direxpand gtpl
dir=${BASH_SOURCE[0]}
dir=${dir%/*}
. ${dir}/.docker-misc.bash
if ! (dbuild && drun check); then
	echo ERROR: Check failed: pillar error found
    exit 1
fi
