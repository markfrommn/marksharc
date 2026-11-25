case $1 in
    detect)
        [[ -n ${HERDR_PANE_ID}${HERDR_TAB_ID}${HERDR_WORKSPACE_ID} ]] &&
            { [[ -x $HERDR_BIN_PATH ]] || (( $+commands[herdr] )); }
        ;;
    set_titles)
        local herdr=herdr
        [[ ! -x $HERDR_BIN_PATH ]] || herdr=$HERDR_BIN_PATH
        if [[ -n $HERDR_WORKSPACE_ID ]]; then
            command "$herdr" workspace report-metadata "$HERDR_WORKSPACE_ID" --source "$6" --token "topname=$2-rm" >/dev/null 2>&1
            command "$herdr" workspace report-metadata "$HERDR_WORKSPACE_ID" --source "$6" --token "subname=$5" >/dev/null 2>&1
            command "$herdr" workspace rename "$HERDR_WORKSPACE_ID" "$2" >/dev/null 2>&1
        fi
        [[ -z $HERDR_TAB_ID ]] || command "$herdr" tab rename "$HERDR_TAB_ID" "$3" >/dev/null 2>&1
        [[ -z $HERDR_PANE_ID ]] || command "$herdr" pane rename "$HERDR_PANE_ID" "$4" >/dev/null 2>&1
        ;;
    refresh_env) return 0 ;;
    supports) [[ ${2-} == (launch|remote|place-workspace|place-tab|place-hidden) ]] ;;
    instances|current|machines|launch)
        local herdr=herdr instance output index name target socket root=''
        local -A json_values=() json_types=()
        local -a cli=() args=()
        [[ ! -x $HERDR_BIN_PATH ]] || herdr=$HERDR_BIN_PATH
        cli=( "$herdr" )
        case $1 in
            instances)
                output=$(command "$herdr" session list --json) || return 1
                _ms_json_parse "$output" && [[ $json_types[/sessions] == array ]] || return 1
                for (( index = 0; index < json_values[/sessions]; index++ )); do
                    [[ ${json_values[/sessions/$index/running]} == true ]] || continue
                    name=${json_values[/sessions/$index/name]}
                    socket=${json_values[/sessions/$index/socket_path]}
                    [[ -n $name && $name != *[[:cntrl:]]* && $socket != *[[:cntrl:]]* ]] || continue
                    printf '%s\t%s\n' "$name" "$socket"
                done
                ;;
            current)
                [[ $HERDR_ENV == 1 && -n $HERDR_PANE_ID && -n $HERDR_SESSION ]] || return 1
                command "$herdr" workspace list >/dev/null 2>&1 || return 1
                print -r -- "$HERDR_SESSION"
                ;;
            machines)
                output=$(command "$herdr" machine list --json) || return 1
                _ms_json_parse "$output" && [[ ${json_types[$root]} == array ]] || return 1
                for (( index = 0; index < ${json_values[$root]}; index++ )); do
                    [[ ${json_values[/$index/enabled]} == true ]] || continue
                    name=${json_values[/$index/label]}
                    target=${json_values[/$index/target]}
                    [[ -n $name && $name != *[[:cntrl:]]* && $target != *[[:cntrl:]]* ]] || continue
                    printf '%s\t%s\t\n' "$name" "$target"
                done
                ;;
            launch)
                if (( $#launch_argv )); then
                    print -ru2 -- 'herdr launch: pass commands in LAUNCH_RUN via --env'
                    return 2
                fi
                instance=${launch_req[instance]:-${HERDR_SESSION:-default}}
                if [[ -n $launch_req[machine] ]]; then
                    if [[ -n $launch_req[cwd] && $launch_req[cwd] != /* ]]; then
                        print -ru2 -- 'herdr launch: use an absolute --cwd for a remote workspace'
                        return 2
                    fi
                    cli+=( --machine "$launch_req[machine]" )
                elif [[ $HERDR_ENV != 1 || -z $HERDR_PANE_ID || $instance != "$HERDR_SESSION" ]]; then
                    cli+=( --session "$instance" )
                fi
                if [[ $launch_req[place] == tab && -z $launch_req[machine] &&
                    $HERDR_ENV == 1 && $instance == "$HERDR_SESSION" && -n $HERDR_WORKSPACE_ID ]]; then
                    args=( tab create --workspace "$HERDR_WORKSPACE_ID" )
                else
                    args=( workspace create )
                    [[ $launch_req[place] != tab ]] || print -ru2 -- 'herdr launch: tab placement uses a new workspace'
                fi
                [[ -z $launch_req[cwd] ]] || args+=( --cwd "$launch_req[cwd]" )
                case $launch_req[name] in
                    '') ;;
                    -*) args+=( "--label=$launch_req[name]" ) ;;
                    *) args+=( --label "$launch_req[name]" ) ;;
                esac
                local assignment pane workspace
                for assignment in "${launch_env[@]}"; do
                    args+=( --env "$assignment" )
                done
                if [[ $launch_req[focus] == 0 || $launch_req[place] == hidden ]]; then
                    args+=( --no-focus )
                else
                    args+=( --focus )
                fi
                if [[ $launch_req[dry_run] == 1 ]]; then
                    _ms_mux_preview "${cli[@]}" "${args[@]}"
                    return
                fi
                output=$(command "${cli[@]}" "${args[@]}") || return 1
                _ms_json_parse "$output" || return 1
                pane=${json_values[/result/root_pane/pane_id]}
                [[ $json_types[/result/root_pane/pane_id] == string && -n $pane && $pane != *[[:cntrl:]]* ]] || {
                    print -ru2 -- 'herdr launch: creation did not return a root pane id'
                    return 1
                }
                if [[ $launch_req[place] == hidden ]]; then
                    workspace=${json_values[/result/root_pane/workspace_id]}
                    [[ -z $workspace ]] || print -ru2 -- "herdr launch: hidden workspace. Focus with $(_ms_mux_preview "${cli[@]}" workspace focus "$workspace")"
                fi
                printf '%s\t%s\n' "$instance" "$pane"
                ;;
        esac
        ;;
    sessions)
        local output row session state pid socket
        output=$(command herdr session list) || return 1
        local -a rows=( "${(@f)output}" )
        for row in "${rows[@]:1}"; do
            [[ -n ${row//[[:space:]]/} ]] || continue
            read -r session state pid socket <<< "$row"
            [[ $session =~ '^[A-Za-z0-9_.-]+$' && -n $socket ]] || {
                print -ru2 'Unsupported Herdr session row'; return 1
            }
            printf '%s\t%s\n' "$session" "$socket"
        done
        ;;
esac
