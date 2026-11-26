declare -gA _ms_bash_atuin_key_before=() _ms_bash_atuin_key_after=()
declare -gA _ms_bash_atuin_key_replaced

_ms_bash_atuin_cleanup() {
    _ms_bash_atuin_clean_keys
    unset __atuin_initialized ATUIN_HISTORY_ID
}

_ms_bash_atuin_init() {
    local name initial_backend='' status=0 context config cache_backend=readline
    # shellcheck disable=SC2034 # The key snapshots are passed by name.
    local -A old_keys=() new_keys=() old_variables=()
    local -a variables=(ATUIN_SESSION ATUIN_SHLVL ATUIN_PREEXEC_BACKEND)
    # shellcheck disable=SC2034 # Provider registrations are scoped to init.
    local -a preexec_functions=() precmd_functions=() BLE_ONLOAD=()
    if declare -F blehook >/dev/null; then
        initial_backend=ble
        cache_backend=ble
    elif [[ -n ${bash_preexec_imported-}${__bp_imported-} ]]; then
        # A replacement PROMPT_COMMAND can detach bash-preexec while its
        # import guard remains set. A fresh shell is needed to reinstall it.
        if ! _ms_bash_has_bash_preexec; then
            _ms_bash_history_backend=atuin-unavailable
            return 1
        fi
        initial_backend=bash-preexec
    fi
    # Leave an explicitly configured Atuin instance to its owner.
    if [[ ${__atuin_initialized-} == true && -n ${ATUIN_SESSION-} && -n $initial_backend ]]; then
        _ms_bash_history_backend=atuin-$initial_backend
        _ms_bash_set_option HISTFILE ''
        return
    fi
    for name in "${variables[@]}"; do old_variables[$name]=$(_ms_bash_effect variable "$name"); done
    if [[ ${_ms_bash_atuin_session-} ]]; then
        export ATUIN_SESSION=$_ms_bash_atuin_session ATUIN_SHLVL=$SHLVL
    else
        unset ATUIN_SESSION ATUIN_SHLVL
    fi

    # MarkSharc registers its own ble.sh callbacks. Keep upstream's Bash
    # function definitions and bindings, and allow bundled bash-preexec only
    # when Readline needs it.
    # shellcheck disable=SC2034
    local BLE_VERSION='' ATUIN_NO_BUILTIN_PREEXEC=${ATUIN_NO_BUILTIN_PREEXEC-}
    [[ $initial_backend != ble ]] || ATUIN_NO_BUILTIN_PREEXEC=1
    config=${ATUIN_CONFIG_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/atuin}/config.toml
    context=${ATUIN_NOBIND-}
    if [[ -f $config && -r $config ]]; then context+="|$(command cksum < "$config")"; fi
    _ms_bash_atuin_keymap old_keys
    _ms_bash_init_cached -k "$cache_backend|$context" atuin atuin init bash >/dev/null 2>&1 || status=$?
    _ms_bash_atuin_keymap new_keys
    _ms_bash_atuin_record_keys old_keys new_keys
    if [[ -z $initial_backend ]] && _ms_bash_has_bash_preexec; then
        # The backend may already be queued in PROMPT_COMMAND even if a later
        # part of Atuin init fails. Its definitions must survive a reload.
        _ms_bash_atuin_loaded_preexec=1
    fi
    if [[ $initial_backend != ble ]] && _ms_bash_has_bash_preexec; then
        initial_backend=bash-preexec
    fi
    if (( status != 0 )) || [[ -z $initial_backend || -z ${ATUIN_SESSION-} || ! -o history ]] ||
       ! declare -F __atuin_preexec __atuin_precmd >/dev/null ||
       ! _ms_bash_set_option HISTFILE ''; then
        _ms_bash_atuin_cleanup
        for name in "${variables[@]}"; do
            _ms_bash_restore_effect variable "$name" "${old_variables[$name]}"
        done
        _ms_bash_history_backend=atuin-unavailable
        return 1
    fi
    _ms_bash_atuin_session=$ATUIN_SESSION
    for name in "${variables[@]}"; do
        _ms_bash_record_effect variable "$name" "${old_variables[$name]}" "$(_ms_bash_effect variable "$name")"
    done
    if [[ $initial_backend == ble ]] && declare -F bleopt >/dev/null &&
       declare -F __atuin_bind_blesh_onload >/dev/null; then
        # The provider's Readline-style widgets need its ble.sh input option.
        name=$(_ms_bash_effect variable bleopt_decode_error_cseq_discard)
        __atuin_bind_blesh_onload
        _ms_bash_record_effect variable bleopt_decode_error_cseq_discard "$name" \
            "$(_ms_bash_effect variable bleopt_decode_error_cseq_discard)"
    fi
    _ms_bash_history_backend=atuin-$initial_backend
    _ms_bash_register_preexec __atuin_preexec
    _ms_bash_register_prompt _ms_bash_atuin_prompt
    _ms_bash_register_cleanup _ms_bash_atuin_cleanup
}

_ms_bash_atuin_prompt() {
    _ms_bash_prompt_return "$1"
    __atuin_precmd
}

_ms_bash_atuin_init || return 0

function history {
    if (( $# == 0 )); then
        command atuin history list --format '{time}  {command}' 2>/dev/null && return 0
    elif (( $# == 1 )) && [[ $1 =~ ^-[0-9]+$ ]]; then
        command atuin history list --format '{time}  {command}' 2>/dev/null | command tail -n "${1#-}"
        (( PIPESTATUS[0] == 0 )) && return 0
        builtin history "${1#-}"
        return
    fi
    builtin history "$@"
}

function h { \history -35; }
