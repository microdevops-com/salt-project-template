#!/usr/bin/env bash

# shellcheck shell=bash

direxpand() {
    v="$(pwd)"
    while [[ -n "$v" ]]; do
        if [[ -f "$v/Dockerfile" ]] && [[ $(<"$v/Dockerfile") =~ salt ]]; then
            path="${v}"
            dir="${v##*/}"
            echo "$path" "$dir"
            return 0
        fi
        v="${v%/*}";
    done
    echo "Not in project's directory or there is no \`Dockerfile'" 1>&2
    return 1
}

gtpl() {
    start=${EPOCHREALTIME/./}
    git pull
    git submodule sync
    git submodule update --init --recursive --force
    local submodules
    declare -a pids=()
    declare -A subnames
    declare ECODE=0
    mapfile -t submodules < <(git submodule --quiet foreach "pwd")
    for submodule in "${submodules[@]}"; do
        (cd "$submodule" || exit 123; git fetch origin master && git checkout --force -B master origin/master) &
        pid="$!"
        pids+=("$pid")
        subnames["$pid"]=$submodule
    done
    resp=()
    for pid in "${pids[@]}"; do
        wait "$pid"; ecode=$?; [[ $ecode -gt $ECODE ]] && ECODE=$ecode
        resp+=("Job ${pid} exited with $ecode for submodule ${subnames[$pid]}")
    done
    end=${EPOCHREALTIME/./}
    resp+=("$FUNCNAME returned $ECODE in $(( (end - start)/1000 ))ms")
    printf "%s\n" "${resp[@]}"
    return $ECODE
}

dbuild() {
    read -ra _dirs < <(direxpand) || return 1

    local path=${_dirs[0]}
    local name=${_dirs[1]}
    docker stop -t 0 "${name}-$USER" > /dev/null 2>&1
    docker build -t "${name}:$USER" "${path}" "$@";
}

drun() {
    read -ra _dirs < <(direxpand) || return 1

    local path=${_dirs[0]}
    local name=${_dirs[1]}
    local top_file=/tmp/$USER-$name-top-sls.file

    cat "${path}/pillar/top_sls/_top.sls" <(echo) > "$top_file"
    find "${path}/pillar/top_sls" -not -type d -print0 | grep -vzP '\.swp$|_?top\.sls$' | sort -z | xargs -0 -I{} bash -c "cat {} <(echo) >> \"$top_file\""

    if [[ ! $(docker ps --format "{{.Names}}" --filter "name=${name}-$USER") =~ ${name}-$USER ]] ; then
        docker run --hostname salt --detach --rm --name "${name}-$USER" \
            --volume "$top_file:/srv/pillar/top.sls" \
            --volume "${path}/:/srv/" \
            --volume "$SSH_AUTH_SOCK:/root/.ssh-agent" \
            --env SSH_AUTH_SOCK=/root/.ssh-agent \
            "${name}:$USER" \
            -- \
            bash -c "sleep 2h && kill -s 15 1; rm /srv/pillar/top.sls" ;
    fi

    if [[ "$1" == check ]]; then
        docker exec "${name}-$USER" "/.check_pillar_for_roster.sh" ;
    elif [[ ${@} =~ grains= ]]; then
        docker cp -q "${path}/etc/salt" "${name}-$USER:/etc/"
        docker exec -it "${name}-$USER" /entrypoint.sh "$@"
    else
        docker exec -it "${name}-$USER" "$@"
    fi
}

_drun_compl()
{
    read -ra _dirs < <(direxpand) || return 1

    local path=${_dirs[0]}
    local name=${_dirs[1]}

    for i in  "${!COMP_WORDS[@]}"; do # arguments cleanup

        if [[ ${COMP_WORDS[$i]} == "=" ]]; then # equals split string to three parts
            unset 'COMP_WORDS[$i-1]'            # and we want to delete all those arguments
            unset 'COMP_WORDS[$i]'
            unset 'COMP_WORDS[$i+1]'
        fi

        if [[ ${COMP_WORDS[$i]} =~ ^--user$ ]]; then # delete --user user
            unset 'COMP_WORDS[$i]'
            unset 'COMP_WORDS[$i+1]'
        fi

        if [[ ${COMP_WORDS[$i]} =~ ^- ]]; then # delete all args that starts with dash
            unset 'COMP_WORDS[$i]'
        fi
    done
    COMP_WORDS=("${COMP_WORDS[@]}")

    if [[ ${#COMP_WORDS[@]} -eq 2 ]]; then
        local _args
        _args="salt-ssh check"
        mapfile -t COMPREPLY < <(compgen -W "${_args}" "${COMP_WORDS[1]}")
    fi

    if [[ ${#COMP_WORDS[@]} -eq 3 ]]; then
        local hosts
        hosts=$(grep -ohP "^[^\s:]+" "${path}"/etc/salt/roster*)
        mapfile -t COMPREPLY < <(compgen -W "${hosts}" "${COMP_WORDS[2]}")
    fi

    if [[ ${#COMP_WORDS[@]} -eq 4 ]]; then
        local _args
        _args="test.ping state.apply state.highstate pillar.items pillar.item grains.items grains.item cmd.run"
        mapfile -t COMPREPLY < <(compgen -W "${_args}" "${COMP_WORDS[3]}")
    fi

    if [[ ${#COMP_WORDS[@]} -eq 5 && ${COMP_WORDS[3]} == state.apply ]]; then
        local _args cachefile prefix
        prefix='/tmp/druncomprep-'
        cachefile="${prefix}$(md5sum <<<"$path" | cut -f 1 -d ' ')"

        if [[ -f $cachefile ]]; then
            _args=$(<"$cachefile")
        else
            _args=$(find "${path}" -regex '.*formulas/microdevops-formula/.*sls' | awk -F/ '{if (/pillar/) {next}; gsub(/^.*clients\/[^/]+/,"",$0); gsub(/init.sls/,"",$5); gsub(/.sls/,"",$5); if ($5) {print $4"."$5} else { print $4}}')
            _args+="\n"
            _args+=$(find "${path}" -regex '.*salt_local/.*sls' | awk -F/ '{if (/pillar/) {next}; gsub(/^.*clients/,"",$0); gsub(/init.sls/,"",$5); gsub(/.sls/,"",$5); if ($5) {print $4"."$5} else { print $4}}')
            echo -e "$_args" > "$cachefile"
        fi

        mapfile -t COMPREPLY < <(compgen -W "${_args}" "${COMP_WORDS[4]}")
    fi
}

if (return 0 2>/dev/null) ; then
    complete -F _drun_compl drun
else
    fnname=${0##*/}
    if declare -F "$fnname" > /dev/null; then
        $fnname "$@"
    else
        echo "No such function"
    fi
fi
