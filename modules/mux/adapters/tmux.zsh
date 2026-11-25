case $1 in
    detect) [[ -n $TMUX && $TMUX_PANE == %<-> ]] && (( $+commands[tmux] )) ;;
    set_titles)
        # tmux expands its own format syntax even for arguments passed directly from argv.
        # A trailing semicolon is a command separator. The empty format keeps it in the title.
        local tab=${3//\#/\#\#} pane=${4//\#/\#\#}
        [[ $tab != *';' ]] || tab+='#{null}'
        [[ $pane != *';' ]] || pane+='#{null}'
        command tmux rename-window -t "$TMUX_PANE" -- "$tab" >/dev/null 2>&1
        command tmux select-pane -t "$TMUX_PANE" -T "$pane" >/dev/null 2>&1
        ;;
    refresh_env)
        local name token output unset_next=0
        shift
        local -a requested=( "$@" )
        # Single session query: DISPLAY and XAUTHORITY must come from the same attach.
        # tmux -s quotes multiline values. Lex and unquote its data without executing it.
        output=$(command tmux show-environment -s -t "$TMUX_PANE" 2>/dev/null) || return 0
        for token in "${(@z)output}"; do
            if (( unset_next )); then
                (( ${requested[(Ie)$token]} )) && client_env[$token]=''
                unset_next=0
            elif [[ $token == unset ]]; then
                unset_next=1
            elif [[ $token == *=\"*\" ]]; then
                name=${token%%=*}
                if (( ${requested[(Ie)$name]} )); then
                    client_env[$name]=${(Q)${token#*=}}
                fi
            fi
        done
        return 0
        ;;
    sessions) command tmux list-sessions -F '#{session_name}' ;;
    supports)
        case ${2-} in
            launch|autostart|argv|place-workspace|place-tab|place-hidden) return 0 ;;
            *) return 1 ;;
        esac
        ;;
    current|instances|machines|launch)
        local operation=$1 socket=${TMUX%,*,*} result word
        local -a tmux_cmd=( tmux ) args=() escaped=()
        [[ -z $socket ]] || tmux_cmd+=( -S "$socket" )

        case $operation in
            current)
                [[ -n $TMUX && $TMUX_PANE == %<-> ]] || return 1
                command "${tmux_cmd[@]}" display-message -p -t "$TMUX_PANE" '#{session_id}' 2>/dev/null
                return $?
                ;;
            instances)
                command "${tmux_cmd[@]}" list-sessions -F $'#{session_id}\t#{session_name}' 2>/dev/null
                return $?
                ;;
            machines) return 0 ;;
        esac

        if [[ -n ${launch_req[machine]} ]]; then
            print -ru2 -- 'tmux: remote launch is not supported'
            return 1
        fi
        if [[ -n ${launch_req[instance]} ]]; then
            args=( new-window -t "${launch_req[instance]}:" )
            [[ ${launch_req[focus]} != 0 && ${launch_req[place]} != hidden ]] || args+=( -d )
            if [[ ${launch_req[place]} == workspace ]]; then
                print -ru2 -- 'tmux: workspace placement uses a tab'
            fi
        else
            args=( new-session -d -s marksharc )
        fi
        # tmux expands format expressions in directory and window-name options.
        [[ -z ${launch_req[cwd]} ]] || args+=( -c "${launch_req[cwd]//\#/##}" )
        [[ -z ${launch_req[name]} ]] || args+=( -n "${launch_req[name]//\#/##}" )
        for word in "${launch_env[@]}"; do args+=( -e "$word" ); done
        args+=( -P -F $'#{session_id}\t#{session_id}:#{window_id}.#{pane_id}' )
        if (( $#launch_argv == 1 )); then
            # A single tmux command argument is interpreted as a shell line.
            args+=( -- /bin/sh -c 'exec "$@"' sh "${launch_argv[@]}" )
        elif (( $#launch_argv )); then
            args+=( -- "${launch_argv[@]}" )
        fi
        # The tmux client treats a trailing semicolon as a command separator.
        # Escaping it in each argument preserves the literal byte at the server.
        for word in "${args[@]}"; do
            [[ $word != *';' ]] || word="${word%;}\\;"
            escaped+=( "$word" )
        done
        if [[ ${launch_req[dry_run]} == 1 ]]; then
            _ms_mux_preview "${tmux_cmd[@]}" "${escaped[@]}"
            return 0
        fi
        if ! result=$(command "${tmux_cmd[@]}" "${escaped[@]}"); then
            if [[ -z $launch_req[instance] ]] && (( $#launch_env )); then
                local version
                version=$(command "${tmux_cmd[@]}" -V 2>/dev/null)
                if [[ $version =~ '^tmux ([0-9]+)\.([0-9]+)' ]] &&
                    (( match[1] < 3 || (match[1] == 3 && match[2] < 2) )); then
                    print -ru2 -- "tmux: new-session environment options need tmux 3.2 or later (found $version)"
                fi
            fi
            return 1
        fi
        [[ $result == \$<->$'\t'\$<->:@<->.%<-> ]] || {
            print -ru2 -- 'tmux: launch returned an invalid address'
            return 1
        }
        if [[ -z ${launch_req[instance]} ]]; then
            print -ru2 -- 'tmux: attach with tmux attach -t marksharc'
        elif [[ ${launch_req[place]} == hidden ]]; then
            local window=${${result#*$'\t'}%.%*}
            print -ru2 -- "tmux: hidden window. Select with $(_ms_mux_preview "${tmux_cmd[@]}" select-window -t "$window")"
        fi
        print -r -- "$result"
        ;;
esac
