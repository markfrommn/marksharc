# Framework hook registries. Callbacks are shell function names, not shell code.
_ms_bash_prompt_hooks=()
_ms_bash_chpwd_hooks=()
_ms_bash_preexec_hooks=()

_ms_bash_register_prompt() { _ms_bash_hook_add _ms_bash_prompt_hooks "$1"; }
_ms_bash_register_chpwd() { _ms_bash_hook_add _ms_bash_chpwd_hooks "$1"; }
_ms_bash_register_preexec() { _ms_bash_hook_add _ms_bash_preexec_hooks "$1"; }

_ms_bash_hook_add() {
    local registry=$1 callback=$2 entry
    [[ $callback =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
    local -n hooks=$registry
    for entry in "${hooks[@]}"; do
        [[ $entry != "$callback" ]] || return 0
    done
    hooks+=("$callback")
}

_ms_bash_preexec_dispatch() {
    local callback
    for callback in "${_ms_bash_preexec_hooks[@]}"; do
        if declare -F "$callback" >/dev/null; then "$callback" "$@" || :; fi
    done
}

# This function is the first command in PROMPT_COMMAND. Expanding its arguments
# captures the preceding command and all pipeline results before any hook runs.
_ms_bash_prompt_capture() {
    local status=$1 callback code separator='' pipeline_status=0
    shift
    local -a pipeline=("$@")
    if [[ ! ${_ms_bash_hook_pwd_set-} || $_ms_bash_hook_pwd != "$PWD" ]]; then
        _ms_bash_hook_pwd=$PWD
        _ms_bash_hook_pwd_set=1
        for callback in "${_ms_bash_chpwd_hooks[@]}"; do
            if declare -F "$callback" >/dev/null; then "$callback" || :; fi
        done
    fi
    for callback in "${_ms_bash_prompt_hooks[@]}"; do
        if declare -F "$callback" >/dev/null; then "$callback" "$status" "${pipeline[@]}" || :; fi
    done
    _ms_bash_prompt_replay=:
    [[ -n ${_ms_bash_prompt_foreign-} ]] || return 0

    # A shell function's return resets PIPESTATUS. Recreate the captured pipeline
    # inside the same eval as the first foreign prompt command, so it sees both
    # the incoming status and the full pipeline. The values are shell statuses.
    _ms_bash_prompt_replay=''
    for code in "${pipeline[@]}"; do
        [[ $code =~ ^[0-9]+$ ]] || code=1
        _ms_bash_prompt_replay+="${separator}_ms_bash_prompt_return $code"
        separator=' | '
        if [[ ! -o pipefail || $code != 0 ]]; then pipeline_status=$code; fi
    done
    if [[ -z $_ms_bash_prompt_replay ]]; then
        _ms_bash_prompt_replay="_ms_bash_prompt_return $status"
    elif [[ $pipeline_status != "$status" ]]; then
        # Negated pipelines retain their original PIPESTATUS but invert $?.
        _ms_bash_prompt_replay="! $_ms_bash_prompt_replay"
    fi
    _ms_bash_prompt_replay+="; ${_ms_bash_prompt_foreign-}"
}

_ms_bash_prompt_return() { return "$1"; }

_ms_bash_prompt_install() {
    local declaration flags
    local -a indices
    declaration=$(declare -p PROMPT_COMMAND 2>/dev/null) || declaration=
    flags=${declaration#declare -}
    flags=${flags%% *}
    case $flags in *[Ainrul]*) return 0 ;; esac
    _ms_bash_prompt_was_set=${PROMPT_COMMAND+x}
    _ms_bash_prompt_array=0
    if [[ $flags == *a* ]]; then
        _ms_bash_prompt_array=1
        indices=("${!PROMPT_COMMAND[@]}")
        if (( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) )); then
            _ms_bash_prompt_index=${indices[0]:-0}
        else
            _ms_bash_prompt_index=0
        fi
        _ms_bash_prompt_index_was_set=${PROMPT_COMMAND[_ms_bash_prompt_index]+yes}
        _ms_bash_prompt_foreign=${PROMPT_COMMAND[_ms_bash_prompt_index]-}
        PROMPT_COMMAND[_ms_bash_prompt_index]='_ms_bash_prompt_capture "$?" "${PIPESTATUS[@]}"; eval "$_ms_bash_prompt_replay"'
    else
        _ms_bash_prompt_foreign=${PROMPT_COMMAND-}
        # shellcheck disable=SC2178 # This branch handles the scalar form.
        PROMPT_COMMAND='_ms_bash_prompt_capture "$?" "${PIPESTATUS[@]}"; eval "$_ms_bash_prompt_replay"'
    fi
    _ms_bash_prompt_owned=${PROMPT_COMMAND[${_ms_bash_prompt_index:-0}]}
}

_ms_bash_hooks_install() {
    local callback
    [[ ${_ms_bash_hooks_installed-} != 1 ]] || return 0
    _ms_bash_hooks_installed=1
    _ms_bash_hook_pwd_set=
    if (( ${#_ms_bash_prompt_hooks[@]} || ${#_ms_bash_chpwd_hooks[@]} )); then
        _ms_bash_prompt_install
    fi
    (( ${#_ms_bash_preexec_hooks[@]} )) || return 0
    if declare -F blehook >/dev/null; then
        blehook 'PREEXEC!=_ms_bash_preexec_dispatch'
        _ms_bash_preexec_backend=ble
    elif declare -p preexec_functions >/dev/null 2>&1; then
        for callback in "${preexec_functions[@]}"; do
            [[ $callback != _ms_bash_preexec_dispatch ]] || return 0
        done
        preexec_functions+=(_ms_bash_preexec_dispatch)
        _ms_bash_preexec_backend=bash_preexec
    fi
}

_ms_bash_hooks_reset() {
    local callback prefix
    local -a retained=()
    [[ ${_ms_bash_hooks_installed-} == 1 ]] || return 0
    if [[ ${_ms_bash_prompt_owned-} && $_ms_bash_prompt_array == 1 ]]; then
        if [[ ${PROMPT_COMMAND[_ms_bash_prompt_index]-} == "$_ms_bash_prompt_owned" ]]; then
            if [[ $_ms_bash_prompt_index_was_set ]]; then
                PROMPT_COMMAND[_ms_bash_prompt_index]=$_ms_bash_prompt_foreign
            else
                unset 'PROMPT_COMMAND[_ms_bash_prompt_index]'
            fi
        fi
    elif [[ ${_ms_bash_prompt_owned-} ]]; then
        prefix=$_ms_bash_prompt_owned
        if [[ ${PROMPT_COMMAND-} == "$prefix"* ]]; then
            # shellcheck disable=SC2178,SC2128 # This branch handles the scalar form.
            PROMPT_COMMAND=${_ms_bash_prompt_foreign}${PROMPT_COMMAND#"$prefix"}
            if [[ -z ${PROMPT_COMMAND[0]} && -z $_ms_bash_prompt_was_set ]]; then unset PROMPT_COMMAND; fi
        fi
    fi
    case ${_ms_bash_preexec_backend-} in
        ble) blehook 'PREEXEC-=_ms_bash_preexec_dispatch' ;;
        bash_preexec)
            for callback in "${preexec_functions[@]}"; do
                [[ $callback == _ms_bash_preexec_dispatch ]] || retained+=("$callback")
            done
            preexec_functions=("${retained[@]}") ;;
    esac
    _ms_bash_prompt_hooks=()
    _ms_bash_chpwd_hooks=()
    _ms_bash_preexec_hooks=()
    unset _ms_bash_hooks_installed _ms_bash_hook_pwd_set _ms_bash_preexec_backend \
        _ms_bash_prompt_owned _ms_bash_prompt_index _ms_bash_prompt_foreign
}
