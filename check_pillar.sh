#!/bin/bash
GRAND_EXIT=0

DOCKER_IMAGE="${PWD##*/}:${USER}"
docker build --quiet --pull -t ${DOCKER_IMAGE} .
docker run --rm ${DOCKER_IMAGE} -- /.check_pillar_for_roster.sh || GRAND_EXIT=1
if [[ ${GRAND_EXIT} != 0 ]]; then
	echo ERROR: Check failed: pillar error found
fi
exit $GRAND_EXIT
