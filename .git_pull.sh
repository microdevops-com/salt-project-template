#!/bin/bash
set -e
git pull --no-tags
git submodule init
git submodule update -f --checkout
git submodule foreach "git checkout master && git pull --no-tags"
ln -sf ../../.githooks/pre-push .git/hooks/pre-push
