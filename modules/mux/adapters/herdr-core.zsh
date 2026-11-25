case $1 in
    detect) [[ -n $HC_TERMINAL_ID ]] ;;
    set_titles)
        if (( $+commands[hc] )) && [[ -z $HC_TERMINAL_SOCKET || -S $HC_TERMINAL_SOCKET ]]; then
            HC_SOCKET=${HC_TERMINAL_SOCKET:-${HC_SOCKET-}} command hc label "$HC_TERMINAL_ID" \
                "marksharc.workspace=$2" "marksharc.tab=$3" "marksharc.pane=$4" >/dev/null 2>&1
        fi
        # The app reads OSC 2 from the core's terminal stream as its pane title.
        if [[ -z ${TMUX_PANE}${HERDR_PANE_ID} ]]; then
            printf '\033]2;%s\007' "$4"
        fi
        ;;
    refresh_env) return 0 ;;
    supports) [[ ${2-} == (launch|remote|autostart|argv|place-workspace|place-tab|place-hidden) ]] ;;
    current|instances|machines|launch)
        local state_dir=${XDG_STATE_HOME:-$HOME/.local/state}/herdr-core
        local instance=${HC_SESSION:-default} current_instance='' lock socket
        local -a cli=() args=() program=()
        local -A json_values=() json_types=()
        if [[ $1 == (current|instances) || -n ${HC_TERMINAL_ID-} ]]; then
            for lock in "$state_dir"/*/core.lock(N.); do
                socket=$(<"$lock")
                [[ -n $socket && -S $socket ]] || continue
                if [[ $1 == instances ]]; then
                    printf '%s\t%s\n' "${lock:h:t}" "$socket"
                elif [[ -n $HC_TERMINAL_ID && $socket == "$HC_TERMINAL_SOCKET" ]]; then
                    current_instance=${lock:h:t}
                    break
                fi
            done
            case $1 in
                current) [[ -n $current_instance ]] && print -r -- "$current_instance"; return $? ;;
                instances) return 0 ;;
            esac
        fi

        if [[ $1 == machines ]]; then
            instance=${2:-${current_instance:-$instance}}
        else
            instance=${launch_req[instance]:-${current_instance:-$instance}}
        fi
        [[ $instance =~ '^[A-Za-z0-9_][A-Za-z0-9_.-]*$' ]] || {
            print -ru2 -- "hc: invalid instance: $instance"
            return 2
        }
        if [[ $instance == "$current_instance" ]]; then
            cli=( env "HC_SOCKET=$HC_TERMINAL_SOCKET" hc )
        else
            cli=( env HC_SOCKET= "HC_SESSION=$instance" hc )
        fi

        local output index name target hostname
        if [[ $1 == machines ]]; then
            lock=$state_dir/$instance/core.lock
            [[ -r $lock ]] || return 0
            socket=$(<"$lock")
            [[ -S $socket ]] || return 0
            output=$(command "${cli[@]}" machine ls --json) || return 1
            _ms_json_parse "$output" && [[ $json_types[/machines] == array ]] || return 1
            for (( index = 0; index < json_values[/machines]; index++ )); do
                name=${json_values[/machines/$index/name]}
                target=${json_values[/machines/$index/target]}
                hostname=${json_values[/machines/$index/host]}
                [[ -n $name && $name != *[[:cntrl:]]* && $target != *[[:cntrl:]]* &&
                    $hostname != *[[:cntrl:]]* ]] || continue
                [[ $json_types[/machines/$index/target] == string ]] || target=''
                [[ $json_types[/machines/$index/host] == string ]] || hostname=''
                printf '%s\t%s\t%s\n' "$name" "$target" "$hostname"
            done
            return 0
        fi

        args=( run --bg --no-parent --no-notify )
        local machine=$launch_req[machine] cwd=$launch_req[cwd] place=$launch_req[place]
        [[ -z $machine ]] || args+=( --on "$machine" )
        [[ -z $launch_req[name] ]] || args+=( --label "marksharc.name=$launch_req[name]" )

        local space='' part address
        if [[ $place == tab && -z $machine && $instance == "$current_instance" ]]; then
            if [[ $launch_req[dry_run] == 1 ]]; then
                _ms_mux_preview "${cli[@]}" get "$HC_TERMINAL_ID" --json
                space='<caller-space-or-new-id>'
            elif output=$(command "${cli[@]}" get "$HC_TERMINAL_ID" --json 2>/dev/null) &&
                _ms_json_parse "$output" && [[ $json_types[/labels/herdr.space] == string ]]; then
                space=${json_values[/labels/herdr.space]}
            fi
        fi
        if [[ $place != hidden && -z $space ]]; then
            [[ $place != tab ]] || print -ru2 -- 'hc launch: tab placement uses a new workspace'
            space=sp
            repeat 8; do
                printf -v part '%04x' "$RANDOM"
                space+=$part
            done
        fi
        [[ -z $space ]] || args+=( --label "herdr.space=$space" )

        program=( "${launch_argv[@]}" )
        if [[ -n $machine && $cwd == ('~'|'~/'*) ]]; then
            (( $#program )) || program=( sh -c 'exec "${SHELL:-/bin/sh}" -l' )
            [[ $cwd != '~' ]] || cwd='~/'
            program=( sh -c 'CDPATH= cd -- "$HOME/$1" && shift && exec "$@"' sh "${cwd#\~/}" "${program[@]}" )
        else
            case $cwd in
                '~') cwd=$HOME ;;
                '~/'*) cwd=$HOME/${cwd#\~/} ;;
            esac
            [[ -z $cwd ]] || args+=( --cwd "$cwd" )
        fi
        # hc interprets a single command word as a shell line. Keep it in a real argv.
        if (( $#program == 1 )) || { (( $#launch_env && $#program )) && [[ $program[1] == *=* ]]; }; then
            program=( sh -c 'exec "$@"' sh "${program[@]}" )
        fi
        if (( $#launch_env )); then
            (( $#program )) || program=( sh -c 'exec "${SHELL:-/bin/sh}" -l' )
            program=( env "${launch_env[@]}" "${program[@]}" )
        fi
        (( ! $#program )) || args+=( -- "${program[@]}" )

        if [[ $launch_req[dry_run] == 1 ]]; then
            _ms_mux_preview "${cli[@]}" "${args[@]}"
            return
        fi
        output=$(command "${cli[@]}" "${args[@]}") || return 1
        _ms_json_parse "$output" || return 1
        address=${json_values[/address]}
        if [[ $json_types[/address] != string || -z $address || $address == *[[:cntrl:]]* ]]; then
            print -ru2 -- 'hc launch: creation did not return a terminal address'
            return 1
        fi
        if [[ $place == hidden ]]; then
            print -ru2 -- "hc launch: hidden terminal. Attach with $(_ms_mux_preview "${cli[@]}" attach "$address")"
        fi
        printf '%s\t%s\n' "$instance" "$address"
        ;;
    sessions) HC_SOCKET=${HC_TERMINAL_SOCKET:-${HC_SOCKET-}} command hc ls --json ;;
esac
