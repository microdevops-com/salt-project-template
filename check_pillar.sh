#!/usr/bin/env bash
set -e
if ! (./.docker_build.sh && ./.docker_run.sh /.check_pillar_for_roster.sh); then
	echo ERROR: Check failed: pillar error found
    exit 1
fi
