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
esac
