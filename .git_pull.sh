#!/bin/bash
set -e
git pull
git submodule init
git submodule update -f --checkout
git submodule foreach "git checkout master && git pull"
ln -sf ../../.githooks/pre-push .git/hooks/pre-push
