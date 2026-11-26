[[ -n ${LAUNCH_RUN-} ]] || return 0

_ms_bash_launch_run() {
    local _ms_payload=${LAUNCH_RUN-} _ms_replace_shell=${LAUNCH_RUN_EXEC-} _ms_bash_decoded
    local -a _ms_launch_words=()
    unset LAUNCH_RUN LAUNCH_RUN_EXEC
    while [[ $_ms_payload == *$'\t'* ]]; do
        _ms_bash_decode_field "${_ms_payload%%$'\t'*}"
        _ms_launch_words+=("$_ms_bash_decoded")
        _ms_payload=${_ms_payload#*$'\t'}
    done
    _ms_bash_decode_field "$_ms_payload"
    _ms_launch_words+=("$_ms_bash_decoded")
    [[ -n ${_ms_launch_words[0]} ]] || return 0
    if [[ $_ms_replace_shell == 1 ]]; then
        builtin exec -- "${_ms_launch_words[@]}"
        builtin exit "$?"
    fi
    "${_ms_launch_words[@]}"
}

_ms_bash_register_first_prompt _ms_bash_launch_run
