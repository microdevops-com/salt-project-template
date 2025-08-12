#!/bin/bash
unset dbuild drun direxpand gtpl
dir=${BASH_SOURCE[0]}
dir=${dir%/*}
. ${dir}/.docker-misc.bash
drun "$@"
