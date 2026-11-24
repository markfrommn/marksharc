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
