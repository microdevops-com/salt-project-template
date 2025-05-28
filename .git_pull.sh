#!/bin/bash
set -e
git pull
git submodule sync # update submodule URLs
git submodule update --init --recursive --force
git submodule foreach "git fetch origin master && git checkout --force -B master origin/master"
ln -sf ../../.githooks/pre-push .git/hooks/pre-push
