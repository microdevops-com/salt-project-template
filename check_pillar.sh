#!/bin/bash
GRAND_EXIT=0

TMP_IMAGE="$(cat /dev/urandom | tr -dc 'a-z' | fold -w 20 | head -n 1)"
docker build --pull -t ${TMP_IMAGE} .
docker run --rm ${TMP_IMAGE} -- /.check_pillar_for_roster.sh || GRAND_EXIT=1
docker rmi -f ${TMP_IMAGE}
if [[ ${GRAND_EXIT} != 0 ]]; then
	echo ERROR: Check failed: pillar error found
fi
exit $GRAND_EXIT
