#!/usr/bin/env bash
unset dbuild drun direxpand gtpl
dir=${BASH_SOURCE[0]}
dir=${dir%/*}
. ${dir}/.docker-misc.bash

set -e
pushd $dir > /dev/null 2>&1 || exit 1
ln -sf ../../.githooks/pre-push .git/hooks/pre-push
gtpl
popd > /dev/null 2>&1 || exit 1
