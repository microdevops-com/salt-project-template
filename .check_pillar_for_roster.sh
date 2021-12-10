#!/bin/bash
shopt -s lastpipe

trap "exit 1" TERM

GRAND_EXIT=0
_PID=$$

_RS=$'\e[0m'          # reset
_Y=$'\e[38;5;226m'    # yellow
_C=$'\e[38;5;51m'     # cyan
_G=$'\e[38;5;2m'      # green
_Red=$'\e[38;5;196m'  # red
_Ro=$'\e[38;5;202m'   # rose


setFqdn() {
    if [[ -n "${1}" ]]; then
        printf "fqdn: %s" "${1}" > /etc/salt/grains
        printf '%s' "$(cat /etc/salt/grains)"
    else
        printf "Error setting fqdn: fqdn is empty"
        exit 1
    fi
}

checkPillars() {
    local grainsFqdn
    local saltCallErrors
    local errors
    local servers="$(grep -oP "^[^\s:]+" /etc/salt/roster)"

    for SERVER in ${servers[@]}; do

        grainsFqdn=''
        saltCallErrors=''
        errors=0

        printf "${_C}----------------------------------------------------------${_RS}\n"
        printf "Checking pillar for ${SERVER}\n"

        setFqdn "${SERVER}" | grainsFqnd="$(</dev/stdin)" || kill -s TERM ${_PID}
        salt-call --local --output=json --id="${SERVER}" pillar.item _errors 2> stderr.log | jq '.local._errors' | saltCallErrors="$(</dev/stdin)"

        printf 'Setting local fqdn grain: `%s`\n' "${grainsFqnd}"

        if [[ ! "${saltCallErrors[*]}" =~ \"\" ]]; then
            errors=1
            printf "Error list:\n${_Ro}%s${_RS}\n" "${saltCallErrors[*]}"
        fi

        if [[ -s stderr.log ]]; then
            errors=1
            GRAND_EXIT=1
            printf "Error details:\n${_Ro}%s${_RS}\n" "$(cat stderr.log)"
        fi

        if [[ $errors -eq 0 ]]; then
            printf "${SERVER} check ${_G}PASSED${_RS}\n"
        else
            printf "${SERVER} check ${_Red}FAILED${_RS}\n"
        fi

    done
}

main() {
    checkPillars
    exit $GRAND_EXIT
}

main
