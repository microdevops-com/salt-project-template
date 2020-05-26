#!/bin/bash
set -e
git pull
git submodule foreach "git checkout master && git pull && git fetch --prune origin +refs/tags/*:refs/tags/*"
