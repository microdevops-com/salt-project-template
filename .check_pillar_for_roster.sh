#!/bin/bash
shopt -s lastpipe

_RS=$'\e[0m'          # reset
_Y=$'\e[38;5;226m'    # yellow
_C=$'\e[38;5;51m'     # cyan
_G=$'\e[38;5;2m'      # green
_Red=$'\e[38;5;196m'  # red
_Ro=$'\e[38;5;202m'   # rose

get_fqdns() {
    grep -oP "^[^\s:]+" /etc/salt/roster | grep -v -e "^#"
}

set_fqdn() {
    if [[ $# -ge 2 ]]; then
        local fqdn="${1}"
        local prefix="${2}"
        : ${fqdn:?"Error: 'fqdn' variable is not set when function ${FUNCNAME[0]} called"}
        : ${environment:?"Error: 'environment' variable is not set when ${FUNCNAME[0]} called"}

        printf "fqdn: %s" "${fqdn}" > "${prefix}"/grains
    else
        printf "Error setting fqdn"
        exit 1
    fi
}

prepare_salt_call_environment() {
    local fqdn="${1}"
    local environment="${2}"
    : ${fqdn:?"Error: 'fqdn' variable is not set when function ${FUNCNAME[0]} called"}
    : ${environment:?"Error: 'environment' variable is not set when ${FUNCNAME[0]} called"}

    mkdir -p "${environment}"                # create salt environment
    rm -rf "${environment}"/*                # ensure environment is clean
    cp -R /etc/salt/. "${environment}"       # idempotent copy of /etc/salt
    set_fqdn "${fqdn}" "${environment}"      # set fqdn in environment

    mkdir -p "${environment}/var/cache" "${environment}/var/run"
    printf '%s: %s\n' "cachedir" "${environment}/var/cache" \
                      "pidfile" "${environment}/var/run/salt-minion.pid" > "${environment}/minion"

}

chekc_pillars() {
    local fqdn="${1}"
    local environment="${2}"
    local salt_call_stdout_errors=''
    : ${fqdn:?"Error: 'fqdn' variable is not set when function ${FUNCNAME[0]} called"}
    : ${environment:?"Error: 'environment' variable is not set when ${FUNCNAME[0]} called"}

    cd "${environment}"
    salt-call --local --output=json --id="${fqdn}" --config-dir="${environment}" pillar.item _errors 2> stderr.log | jq -r '.local._errors' | salt_call_stdout_errors="$(</dev/stdin)"
    if [[ -s stderr.log || -n "${salt_call_stdout_errors[*]}" ]]; then
        printf "${fqdn} check ${_Red}FAILED${_RS}\n"
        printf "Error list:\n${_Ro}%s${_RS}\n" "${salt_call_stdout_errors[*]}"
        printf "Error details:\n${_Ro}%s${_RS}\n" "$(< stderr.log)"
        exit 1
    else
        printf "${fqdn} check ${_G}PASSED${_RS}\n"
    fi
}

main() {
    ENV_PREFIX='/tmp/'
    GRAND_EXIT=0
    local job_pids
    local pids
    local failed_checks_count=0
    local BATCH
    [[ $1 =~ [0-9]+ ]] && BATCH=$1 || BATCH=10

    declare -A envs

    printf "${_C}Prepare the associative array with fqdn and path to salt configs${_RS}\n"
    for fqdn in $(get_fqdns); do
        environment="${ENV_PREFIX}${fqdn//[-.]/_}"
        envs[$fqdn]="${environment}"
    done

    printf "${_C}Prepare the salt environments${_RS}\n"
    for fqdn in ${!envs[@]}; do
        prepare_salt_call_environment "${fqdn}" "${envs[$fqdn]}"
    done

    printf "${_C}Started spawning jobs${_RS}\n"
    printf "${_C}Keep at least $BATCH simultaneous pillar checks${_RS}\n"
    for fqdn in ${!envs[@]}; do
        while :; do
            job_pids=($(jobs -pr))
            [[ ${#job_pids[@]} -ge ${BATCH} ]] && sleep 0.2s || break
        done
        chekc_pillars "${fqdn}" "${envs[$fqdn]}" &
        pids+=($!)
    done
    printf "${_C}Done spawning jobs${_RS}\n"

    printf "${_C}Wait untill all checks pass${_RS}\n"
    while [[ ${#job_pids[@]} -ge 1 ]]; do
        sleep 0.5;
        job_pids=($(jobs -pr))
    done

    printf "${_C}Check if any of pids has exit code greater than 1${_RS}\n"
    for pid in ${pids[@]}; do
            wait $pid
            [[ $? -ge 1 ]] && failed_checks_count=$((failed_checks_count+1))
    done

    if [[ $failed_checks_count -ge 1 ]]; then
        printf "${_Red}Failed checks count: $failed_checks_count${_RS}\n"
        exit 1
    else
        printf "${_G}Failed checks count: $failed_checks_count${_RS}\n"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main ${@}
fi
