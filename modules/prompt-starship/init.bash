_ms_bash_starship_init() {
    local config=${_ms_opt_prompt_starship_config-} name
    # shellcheck disable=SC2034 # Source the provider with its transport isolated.
    local PROMPT_COMMAND='' BLE_VERSION='' bash_preexec_imported=defined
    # shellcheck disable=SC2034
    local -a preexec_functions=() precmd_functions=()
    local -A before=()
    case $config in
        '') ;;
        \~/*) config=$HOME/${config#'~/'} ;;
        */*) ;;
        *) config=${BASH_SOURCE[0]%/*}/presets/$config.toml ;;
    esac
    if [[ -f $config && -r $config ]]; then _ms_bash_set_env STARSHIP_CONFIG "$config"; fi
    for name in PS2 STARSHIP_SHELL STARSHIP_SESSION_KEY; do
        before[$name]=$(_ms_bash_effect variable "$name")
    done
    _ms_bash_init_cached starship starship init bash --print-full-init >/dev/null 2>&1 || return
    declare -F starship_precmd >/dev/null || return 1
    for name in PS2 STARSHIP_SHELL STARSHIP_SESSION_KEY; do
        _ms_bash_record_effect variable "$name" "${before[$name]}" "$(_ms_bash_effect variable "$name")"
    done
    _ms_bash_starship_original=$(_ms_bash_effect variable PS1)
    unset _ms_bash_starship_last
    _ms_bash_register_cleanup _ms_bash_starship_cleanup
    _ms_bash_register_prompt _ms_bash_starship_prompt
    if declare -F blehook >/dev/null || _ms_bash_has_bash_preexec; then
        _ms_bash_register_preexec starship_preexec
    elif [[ ${PS0-} != *'_ms_bash_starship_time'* && ! ${_ms_bash_starship_ps0_replaced-} ]]; then
        # Capture duration using the same PS0 mechanism as Starship's Readline
        # integration. Keep it separate from any backend that appends to PS0.
        # shellcheck disable=SC2016
        _ms_bash_starship_ps0='${STARSHIP_START_TIME:$((STARSHIP_START_TIME="$(_ms_bash_starship_time)",0)):0}'
        _ms_bash_starship_ps0_was_set=${PS0+x}
        PS0=$_ms_bash_starship_ps0${PS0-}
    fi
}

_ms_bash_starship_time() { command starship time; }

_ms_bash_starship_prompt() {
    local status=$1
    shift
    # shellcheck disable=SC2034 # Starship reads the backend's pipeline snapshot.
    local -a BP_PIPESTATUS=("$@")
    # Starship reads the previous status and the backend's pipeline snapshot.
    if [[ ! ${_ms_bash_starship_replaced-} ]]; then
        if [[ ${_ms_bash_starship_last+x} && ${PS1-} != "$_ms_bash_starship_last" ]]; then
            _ms_bash_starship_replaced=1
        else
            _ms_bash_prompt_return "$status"
            starship_precmd
            _ms_bash_starship_last=${PS1-}
        fi
    fi
}

_ms_bash_starship_cleanup() {
    if [[ ${_ms_bash_starship_ps0-} ]]; then
        if [[ ${PS0-} == "$_ms_bash_starship_ps0"* ]]; then
            PS0=${PS0#"$_ms_bash_starship_ps0"}
            [[ -n $PS0 || $_ms_bash_starship_ps0_was_set ]] || unset PS0
        else
            _ms_bash_starship_ps0_replaced=1
        fi
        unset _ms_bash_starship_ps0
    fi
    if [[ ${_ms_bash_starship_last+x} ]]; then
        if [[ ${PS1-} == "$_ms_bash_starship_last" ]]; then
            _ms_bash_restore_effect variable PS1 "$_ms_bash_starship_original"
        else
            _ms_bash_starship_replaced=1
        fi
    fi
    unset STARSHIP_START_TIME STARSHIP_PREEXEC_READY
}

_ms_bash_starship_init
