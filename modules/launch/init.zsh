[[ ${MARKSHARC_SESSION-} == interactive && -n ${LAUNCH_RUN-} ]] || return 0

autoload -Uz add-zsh-hook

_ms_launch_run_cleanup() {
    add-zsh-hook -d precmd _ms_launch_run
    _ms_init_cleanups=( "${(@)_ms_init_cleanups:#_ms_launch_run_cleanup}" )
    unfunction _ms_launch_run _ms_launch_run_cleanup
}

_ms_launch_run() {
    emulate -L zsh
    local payload=${LAUNCH_RUN-} replace_shell=${LAUNCH_RUN_EXEC-} word
    _ms_launch_run_cleanup
    unset LAUNCH_RUN LAUNCH_RUN_EXEC
    [[ -n $payload ]] || return 0

    local -a fields=( "${(@ps:\t:)payload}" ) words=()
    for word in "${fields[@]}"; do
        word=${word//\%0A/$'\n'}
        word=${word//\%09/$'\t'}
        words+=( "${word//\%25/%}" )
    done
    [[ -n $words[1] ]] || return 0
    if [[ $replace_shell == 1 ]]; then
        exec -- "${words[@]}"
        exit $?
    fi
    "${words[@]}"
    # A command failure must not suppress the remaining precmd hooks.
    return 0
}

typeset -gaU _ms_init_cleanups
_ms_init_cleanups+=( _ms_launch_run_cleanup )
add-zsh-hook precmd _ms_launch_run
