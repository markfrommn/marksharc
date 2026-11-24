# A missing key means the adapter has no opinion. An empty value is an explicit removal.
mux_emit_env() {
    local key=$1 value=$2
    if [[ -n $value ]]; then
        [[ ${(P)key} == "$value" ]] || _ms_directive_emit setenv "$key" "$value"
    elif (( ${+parameters[$key]} )); then
        _ms_directive_emit unsetenv "$key"
    fi
    return 0
}

mux_display_fallback() {
    local timer=${commands[gtimeout]:-${commands[timeout]-}}
    # Passive startup never probes. Without a timer, even one stale address can hang Xlib.
    [[ -n $timer ]] && (( $+commands[xdpyinfo] )) || return 0
    local current=$1 entry number candidate selected='' host
    if [[ -n $current ]] && "$timer" -k 0.1 0.25 xdpyinfo -display "$current" >/dev/null 2>&1; then
        return 0
    fi
    display=''
    (( persistent )) && [[ -n ${SSH_CONNECTION}${SSH_TTY} || $current == localhost:<->* ]] || return 0

    # xauth stores forwarded localhost displays as <host>/unix:N. Limit probes to
    # SSH's loopback display range and keep an inherited live display when available.
    local -aU candidates=()
    if (( $+commands[xauth] )); then
        host=$(command hostname 2>/dev/null)
        while read -r entry _rest; do
            [[ $entry == ("$host"|"${host%%.*}")/unix:<-> || $entry == localhost:<-> ]] || continue
            number=${entry##*:}
            [[ $number == <10-65535> ]] || continue
            candidates+=( "localhost:$number.0" )
        done < <("$timer" -k 0.1 0.25 xauth -n -i list 2>/dev/null)
    fi
    (( $#candidates )) || candidates=( localhost:10.0 )
    # With too many candidates, no bounded scan can rule out ambiguity.
    (( $#candidates <= 4 )) || return 0
    for candidate in "${candidates[@]}"; do
        [[ $candidate != "$current" ]] || continue
        if "$timer" -k 0.1 0.25 xdpyinfo -display "$candidate" >/dev/null 2>&1; then
            [[ -z $selected ]] || return 0
            selected=$candidate
        fi
    done
    display=$selected
}

mux_refresh_agent() {
    local socket
    if [[ $mode == all ]]; then
        fpath=( "$framework/modules/ssh-agent/lib" $fpath )
        autoload -Uz _ms_agent_probe _ms_agent_discover
    fi
    if (( ${+client_env[SSH_AUTH_SOCK]} )); then
        socket=$client_env[SSH_AUTH_SOCK]
        if [[ -S $socket && -O $socket ]] &&
            { [[ $mode != all ]] || SSH_AUTH_SOCK="$socket" _ms_agent_probe; }; then
            if [[ $socket != "$SSH_AUTH_SOCK" ]]; then
                mux_emit_env SSH_AUTH_SOCK "$socket"
                mux_emit_env SSH_AGENT_PID ''
            fi
            return 0
        fi
        # Attach may remove forwarding. Keep a separately configured local agent.
        if [[ -S $SSH_AUTH_SOCK && -O $SSH_AUTH_SOCK &&
            ( -n $SSH_AGENT_PID || $SSH_AUTH_SOCK != */ssh-*/agent.* ) ]] &&
            { [[ $mode != all ]] || _ms_agent_probe; }; then
            return 0
        fi
        socket=''
        if [[ $mode == all ]] && _ms_agent_discover; then
            socket=$REPLY
        fi
    elif [[ $mode == all ]]; then
        _ms_agent_probe && return 0
        local -a forwarding=()
        if (( persistent )) && [[ -n ${SSH_CONNECTION}${SSH_TTY} || $SSH_AUTH_SOCK == */ssh-*/agent.* ]]; then
            forwarding=( --forwarded )
        fi
        _ms_agent_discover "${forwarding[@]}"
        socket=$REPLY
    else
        return 0
    fi
    mux_emit_env SSH_AUTH_SOCK "$socket"
    mux_emit_env SSH_AGENT_PID ''
}

mux_refresh() {
    local mode=$1 adapter display snapshot
    local -A client_env=()
    local -a keys=( DISPLAY XAUTHORITY )
    case $mode in
        all|client|auto) keys+=( SSH_AUTH_SOCK ) ;;
        display|display-startup) ;;
        *) return 2 ;;
    esac
    mux_detect
    local -i persistent=0
    for adapter in "${active[@]}"; do
        [[ $adapter == plain ]] || persistent=1
        mux_adapter "$adapter" refresh_env "${keys[@]}"
    done
    if [[ $mode == auto ]]; then
        (( ${#client_env} )) || return 0
        snapshot=$(
            printf '%s\0' "$TMUX" "$TMUX_PANE" "${+client_env[DISPLAY]}" "$client_env[DISPLAY]" \
                "${+client_env[XAUTHORITY]}" "$client_env[XAUTHORITY]" \
                "${+client_env[SSH_AUTH_SOCK]}" "$client_env[SSH_AUTH_SOCK]" | command cksum
        ) || return 1
        [[ $snapshot != "$MARKSHARC_MUX_SNAPSHOT" ]] || return 0
        _ms_directive_emit setenv MARKSHARC_MUX_SNAPSHOT "$snapshot" || return 1
        mode=client
    fi

    if (( ${+client_env[XAUTHORITY]} )); then
        mux_emit_env XAUTHORITY "$client_env[XAUTHORITY]"
        if [[ -n $client_env[XAUTHORITY] ]]; then
            export XAUTHORITY=$client_env[XAUTHORITY]
        else
            unset XAUTHORITY
        fi
    fi
    if (( ${+client_env[DISPLAY]} )) || [[ $mode != client ]]; then
        display=${client_env[DISPLAY]-${DISPLAY-}}
        if (( ! ${+client_env[DISPLAY]} )) && [[ $mode == all || $mode == display ]] && (( persistent )); then
            mux_display_fallback "$display"
        fi
        mux_emit_env DISPLAY "$display"
        mux_emit_env DISPLAY_ORIG "$display"
    fi

    mux_refresh_agent
}
