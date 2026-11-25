# Shared helpers for $MARKSHARC_CONFIG/hosts.conf, SSH/hc discovery, and safe updates.
# Sourced by core/cli/hosts and core/cli/push under `emulate -L zsh`.

source "$MARKSHARC_HOME/core/zsh/lib/modules.zsh"

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

# Pure-zsh scanner for `hc machine ls --json` output: {"machines":[{...}, ...]}.
_ms_hosts_parse_hc_json() {
    local json=$1
    integer len=${#json} i=1 depth=0 in_machines=0 in_arr=0
    local ch key val str m_name m_target m_via m_temp mkey bval REPLY=

    _ms_json_skip_ws() {
        while (( i <= len )); do
            case $json[i] in
                ' '|$'\t'|$'\n'|$'\r') (( i++ )) ;;
                *) break ;;
            esac
        done
    }

    _ms_json_read_string() {
        REPLY=
        (( i <= len )) && [[ $json[i] == '"' ]] || return 1
        (( i++ ))
        local out= c
        while (( i <= len )); do
            c=$json[i]
            if [[ $c == '"' ]]; then
                (( i++ ))
                REPLY=$out
                return 0
            fi
            if [[ $c == '\' ]]; then
                (( i++ ))
                (( i <= len )) || return 1
                case $json[i] in
                    '"'|'\'|'/') out+=$json[i] ;;
                    n) out+=$'\n' ;;
                    t) out+=$'\t' ;;
                    r) out+=$'\r' ;;
                    *) out+=$json[i] ;;
                esac
                (( i++ ))
                continue
            fi
            out+=$c
            (( i++ ))
        done
        return 1
    }

    _ms_json_skip_value() {
        _ms_json_skip_ws
        (( i <= len )) || return 1
        case $json[i] in
            '"')
                local REPLY=
                _ms_json_read_string || return 1
                ;;
            '{'|'[')
                local open=$json[i] close='}'
                [[ $open == '[' ]] && close=']'
                integer d=1
                (( i++ ))
                while (( i <= len && d > 0 )); do
                    if [[ $json[i] == '"' ]]; then
                        local REPLY=
                        _ms_json_read_string || return 1
                        continue
                    fi
                    if [[ $json[i] == $open ]]; then (( d++ ))
                    elif [[ $json[i] == $close ]]; then (( d-- ))
                    fi
                    (( i++ ))
                done
                ;;
            *)
                while (( i <= len )); do
                    case $json[i] in
                        ','|'}'|']'|' '|$'\t'|$'\n'|$'\r') break ;;
                        *) (( i++ )) ;;
                    esac
                done
                ;;
        esac
        return 0
    }

    _ms_json_skip_ws
    (( i <= len )) && [[ $json[i] == '{' ]] || return 0
    (( i++ ))

    while (( i <= len )); do
        _ms_json_skip_ws
        (( i <= len )) || break
        [[ $json[i] == '}' ]] && break
        [[ $json[i] == ',' ]] && { (( i++ )); continue; }
        REPLY=
        _ms_json_read_string || break
        key=$REPLY
        _ms_json_skip_ws
        (( i <= len )) && [[ $json[i] == ':' ]] || break
        (( i++ ))
        _ms_json_skip_ws
        if [[ $key == machines && $json[i] == '[' ]]; then
            (( i++ ))
            while (( i <= len )); do
                _ms_json_skip_ws
                (( i <= len )) || break
                [[ $json[i] == ']' ]] && { (( i++ )); break; }
                [[ $json[i] == ',' ]] && { (( i++ )); continue; }
                if [[ $json[i] != '{' ]]; then
                    _ms_json_skip_value || break
                    continue
                fi
                (( i++ ))
                m_name= m_target= m_via=false m_temp=false
                while (( i <= len )); do
                    _ms_json_skip_ws
                    (( i <= len )) || break
                    [[ $json[i] == '}' ]] && { (( i++ )); break; }
                    [[ $json[i] == ',' ]] && { (( i++ )); continue; }
                    _ms_json_read_string || break
                    mkey=$REPLY
                    _ms_json_skip_ws
                    (( i <= len )) && [[ $json[i] == ':' ]] || break
                    (( i++ ))
                    _ms_json_skip_ws
                    if [[ $mkey == (name|target) && $json[i] == '"' ]]; then
                        _ms_json_read_string || break
                        if [[ $mkey == name ]]; then m_name=$REPLY; else m_target=$REPLY; fi
                    elif [[ $mkey == (via|temporary) ]]; then
                        bval=
                        while (( i <= len )); do
                            case $json[i] in
                                ','|'}'|' '|$'\t'|$'\n'|$'\r') break ;;
                                *) bval+=$json[i]; (( i++ )) ;;
                            esac
                        done
                        if [[ $mkey == via ]]; then m_via=$bval; else m_temp=$bval; fi
                    else
                        _ms_json_skip_value || break
                    fi
                done
                if [[ -n $m_name && $m_via != true && $m_temp != true ]]; then
                    [[ -n $m_target ]] || m_target=$m_name
                    _ms_hosts_add_candidate "$m_name" "$m_target" hc
                fi
            done
            break
        else
            _ms_json_skip_value || break
        fi
    done
}

_ms_hosts_discover_hc() {
    whence -p -- hc >/dev/null 2>&1 || return 0
    local json
    json=$(command hc machine ls --json 2>/dev/null) || return 0
    [[ -n $json ]] || return 0
    _ms_hosts_parse_hc_json "$json"
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
