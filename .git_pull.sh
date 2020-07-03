#!/bin/bash
set -e
git pull
git fetch --prune origin +refs/tags/*:refs/tags/*
git submodule init
git submodule update -f --checkout
git submodule foreach "git checkout master && git pull && git fetch --prune origin +refs/tags/*:refs/tags/*"
