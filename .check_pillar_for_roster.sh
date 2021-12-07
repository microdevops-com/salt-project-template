#!/bin/bash
GRAND_EXIT=0

for SERVER in $(cat /etc/salt/roster | grep -v "^  " | sed -e "s/:$//")
do
	echo ===================
	echo Checking pillar for ${SERVER}
	echo -n "Setting local fqdn grain: "
	# Do not show errors for setting fqdn, there is always an error on the first cycle
	salt-call --local --output=txt grains.setval fqdn ${SERVER} 2>/dev/null
	echo -n "Error list: "
	salt-call --local --output=json --id=${SERVER} pillar.item _errors 2>stderr.log | jq '.local._errors'
	if [[ -s stderr.log ]]; then
		GRAND_EXIT=1
		echo Error details:
		cat stderr.log
	fi
done

exit $GRAND_EXIT
