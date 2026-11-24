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
    sessions) HC_SOCKET=${HC_TERMINAL_SOCKET:-${HC_SOCKET-}} command hc ls --json ;;
esac
