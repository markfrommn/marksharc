# Shared helpers for $MARKSHARC_CONFIG/hosts.conf, SSH/hc discovery, and safe updates.
# Sourced by core/cli/hosts and core/cli/push under `emulate -L zsh`.

source "$MARKSHARC_HOME/core/zsh/lib/modules.zsh"
source "$MARKSHARC_HOME/core/zsh/lib/json.zsh"

_ms_hosts_file() {
    local config=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}
    REPLY=$config/hosts.conf
}

_ms_hosts_valid_name() {
    local name=$1
    [[ -n $name && $name != -* && $name =~ '^[A-Za-z0-9._@:-]+$' ]]
}

_ms_hosts_valid_target() {
    local target=$1
    [[ -n $target && $target != -* && $target =~ '^[]A-Za-z0-9._@:/[-]+$' ]]
}

# Read hosts.conf into _ms_host_names (ordered array) and _ms_host_targets (name -> ssh target).
_ms_hosts_read() {
    local file=${1-}
    if [[ -z $file ]]; then
        local REPLY=
        _ms_hosts_file
        file=$REPLY
    fi
    typeset -ga _ms_host_names=()
    typeset -gA _ms_host_targets=()
    [[ -r $file ]] || return 0
    local line name target
    integer line_no=0
    while IFS= read -r line || [[ -n $line ]]; do
        (( ++line_no ))
        _ms_words "$line" || continue
        if [[ ${reply[1]} == host ]]; then
            if (( $#reply < 2 || $#reply > 3 )); then
                print -ru2 -- "hosts.conf:$line_no: expected 'host <name> [<ssh-target>]'"
                return 1
            fi
            name=${reply[2]}
            target=${reply[3]-$name}
        elif (( $#reply == 1 )); then
            name=${reply[1]}
            target=$name
        else
            print -ru2 -- "hosts.conf:$line_no: invalid entry (expected 'host <name> [<ssh-target>]')"
            return 1
        fi
        if ! _ms_hosts_valid_name "$name"; then
            print -ru2 -- "hosts.conf:$line_no: invalid host name: $name"
            return 1
        fi
        if ! _ms_hosts_valid_target "$target"; then
            print -ru2 -- "hosts.conf:$line_no: invalid ssh target: $target"
            return 1
        fi
        if [[ -z ${_ms_host_targets[$name]-} ]]; then
            _ms_host_names+=( "$name" )
        fi
        _ms_host_targets[$name]=$target
    done < "$file"
    return 0
}

_ms_hosts_add_candidate() {
    local name=$1 target=$2 source_tag=$3
    _ms_hosts_valid_name "$name" || return 0
    _ms_hosts_valid_target "$target" || return 0
    if [[ -z ${_ms_disc_targets[$name]-} ]]; then
        _ms_disc_names+=( "$name" )
        _ms_disc_targets[$name]=$target
        _ms_disc_sources[$name]=$source_tag
    else
        # Prefer an explicit non-default target (e.g. from hc) over a bare alias.
        if [[ ${_ms_disc_targets[$name]} == "$name" && $target != "$name" ]]; then
            _ms_disc_targets[$name]=$target
        fi
        if [[ ",${_ms_disc_sources[$name]}," != *",$source_tag,"* ]]; then
            _ms_disc_sources[$name]="${_ms_disc_sources[$name]},$source_tag"
        fi
    fi
}

_ms_hosts_parse_ssh_file() {
    local file=$1 base_dir=$2
    [[ -r $file ]] || return 0
    local real=${file:A}
    [[ -n ${_ms_ssh_seen[$real]-} ]] && return 0
    _ms_ssh_seen[$real]=1

    local line rest key val pat inc expanded match_file
    local -a tokens=() matches=()
    while IFS= read -r line || [[ -n $line ]]; do
        line=${line%%#*}
        line=${line#"${line%%[![:space:]]*}"}
        line=${line%"${line##*[![:space:]]}"}
        [[ -n $line ]] || continue
        if [[ $line =~ '^([A-Za-z]+)[[:space:]]*=[[:space:]]*(.*)$' ]]; then
            key=${match[1]:l}
            val=${match[2]}
        elif [[ $line =~ '^([A-Za-z]+)[[:space:]]+(.*)$' ]]; then
            key=${match[1]:l}
            val=${match[2]}
        else
            continue
        fi
        case $key in
            include)
                tokens=( ${(z)val} ) 2>/dev/null || continue
                for inc in "${tokens[@]}"; do
                    inc=${(Q)inc}
                    [[ $inc == '~/'* ]] && inc=$HOME/${inc#\~/}
                    [[ $inc != /* ]] && inc=$base_dir/$inc
                    matches=( ${~inc}(N-.) )
                    for match_file in "${matches[@]}"; do
                        _ms_hosts_parse_ssh_file "$match_file" "$base_dir"
                    done
                done
                ;;
            host)
                tokens=( ${(z)val} ) 2>/dev/null || continue
                for pat in "${tokens[@]}"; do
                    pat=${(Q)pat}
                    [[ -z $pat ]] && continue
                    # Skip SSH wildcards, negations, and option-like names.
                    [[ $pat == *[*?!\[\]]* || $pat == -* ]] && continue
                    _ms_hosts_add_candidate "$pat" "$pat" ssh
                done
                ;;
        esac
    done < "$file"
}

_ms_hosts_discover_ssh() {
    local ssh_conf=${1:-${MARKSHARC_SSH_CONFIG:-$HOME/.ssh/config}}
    typeset -A _ms_ssh_seen=()
    _ms_hosts_parse_ssh_file "$ssh_conf" "${ssh_conf:h}"
}

# Import permanent hc machine entries into the discovery candidates.
_ms_hosts_parse_hc_json() {
    local -A json_values=() json_types=()
    local -i index
    local prefix name target
    _ms_json_parse "$1" || return 1
    [[ ${json_types[/machines]-} == array ]] || return 1
    for (( index = 0; index < ${json_values[/machines]}; ++index )); do
        prefix=/machines/$index
        [[ ${json_types[$prefix/name]-} == string ]] || continue
        name=${json_values[$prefix/name]}
        target=''
        [[ ${json_types[$prefix/target]-} != string ]] || target=${json_values[$prefix/target]}
        [[ -n $name ]] || continue
        [[ ${json_types[$prefix/via]-} != boolean || ${json_values[$prefix/via]} != true ]] || continue
        [[ ${json_types[$prefix/temporary]-} != boolean || ${json_values[$prefix/temporary]} != true ]] || continue
        [[ -n $target ]] || target=$name
        _ms_hosts_add_candidate "$name" "$target" hc
    done
}

_ms_hosts_discover_hc() {
    whence -p -- hc >/dev/null 2>&1 || return 0
    local json
    json=$(command hc machine ls --json 2>/dev/null) || return 0
    [[ -n $json ]] || return 0
    _ms_hosts_parse_hc_json "$json"
}

# Launch helpers return their result in REPLY. The caller loads hosts.conf first.
_ms_launch_host_kind() {
    case ${1-} in
        ''|local|localhost) REPLY=local ;;
        remote) REPLY=prompt ;;
        *) if [[ -n ${MARKSHARC_HOST-} && $1 == $MARKSHARC_HOST ]]; then
               REPLY=local
           else
               REPLY=remote
           fi ;;
    esac
}

_ms_launch_host_target() {
    REPLY=${_ms_host_targets[$1]-$1}
}

# The machine inventory is newline-delimited name, target, hostname TSV.
_ms_launch_machine() {
    local kind=$1 host=$2 rows=$3 target row name machine_target hostname rest
    local -a matches=()
    local -i tier
    _ms_launch_host_target "$host"
    target=$REPLY
    for tier in 1 2 3; do
        matches=()
        for row in "${(@f)rows}"; do
            [[ $row == *$'\t'* ]] || continue
            name=${row%%$'\t'*}
            rest=${row#*$'\t'}
            machine_target=${rest%%$'\t'*}
            hostname=${rest#*$'\t'}
            [[ $rest == *$'\t'* ]] || hostname=''
            case $tier in
                1) [[ $name == $host ]] || continue ;;
                2) [[ -n $hostname && $hostname == $host ]] || continue ;;
                3) [[ $machine_target == $target || $machine_target == $host ]] || continue ;;
            esac
            matches+=( "$name" )
        done
        if (( $#matches == 1 )); then
            REPLY=$matches[1]
            return 0
        elif (( $#matches > 1 )); then
            print -ru2 -- "hosts: ambiguous machine for $host: ${(j:, :)matches}"
            return 1
        fi
    done
    case $kind in
        herdr-core) print -ru2 -- "hosts: no machine for $host; add it with: hc machine add ${(q)target} --name ${(q)host}" ;;
        herdr) print -ru2 -- "hosts: no machine for $host; add it with: herdr machine add ${(q)target} --label ${(q)host}" ;;
        *) print -ru2 -- "hosts: $kind cannot reach $host" ;;
    esac
    return 1
}

# Read kind<TAB>name<TAB>target<TAB>hostname rows and print picker candidates.
_ms_launch_host_candidates() {
    local filter=${1-} row kind machine remainder target host kind_rows REPLY
    local -a names=( "${_ms_host_names[@]}" ) kinds=() reachable=()
    local -A inventories=() seen=() targets=()
    for host in "${names[@]}"; do
        seen[$host]=1
        targets[$host]=${_ms_host_targets[$host]}
    done
    while IFS= read -r row || [[ -n $row ]]; do
        [[ $row == *$'\t'* ]] || continue
        kind=${row%%$'\t'*}
        remainder=${row#*$'\t'}
        [[ $remainder == *$'\t'* ]] || continue
        machine=${remainder%%$'\t'*}
        target=${remainder#*$'\t'}
        target=${target%%$'\t'*}
        [[ -n $kind && -n $machine ]] || continue
        if [[ -z ${inventories[$kind]-} ]]; then
            kinds+=( "$kind" )
        fi
        inventories[$kind]+="$remainder"$'\n'
        if [[ -z ${seen[$machine]-} ]]; then
            seen[$machine]=1
            names+=( "$machine" )
            targets[$machine]=${target:-$machine}
        fi
    done
    for host in "${names[@]}"; do
        _ms_launch_host_kind "$host"
        [[ $REPLY == remote ]] || continue
        reachable=()
        for kind in "${kinds[@]}"; do
            [[ -z $filter || $kind == $filter ]] || continue
            kind_rows=${inventories[$kind]}
            _ms_launch_machine "$kind" "$host" "$kind_rows" 2>/dev/null && reachable+=( "$kind" )
        done
        [[ -z $filter || $#reachable -gt 0 ]] || continue
        print -r -- "$host"$'\t'"$host (${targets[$host]}) [${(j:, :)reachable}]"
    done
    return 0
}

_ms_hosts_format_line() {
    local name=$1 target=$2
    if [[ -n $target && $target != "$name" ]]; then
        REPLY="host $name $target"
    else
        REPLY="host $name"
    fi
}

# Atomically write new content to hosts.conf while preserving a symlinked overlay file.
_ms_hosts_save_text() {
    local file=$1 content=$2
    local dest=$file
    [[ -L $file ]] && dest=${file:A}
    command mkdir -p -- "${dest:h}" || return 1
    local tmp="$dest.tmp.$$"
    print -rn -- "$content" > "$tmp" || { command rm -f -- "$tmp"; return 1; }
    command mv -f -- "$tmp" "$dest" || { command rm -f -- "$tmp"; return 1; }
}
