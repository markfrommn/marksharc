# Framework hook registries. Callbacks are shell function names, not shell code.
_ms_bash_prompt_hooks=()
_ms_bash_first_prompt_hooks=()
_ms_bash_chpwd_hooks=()
_ms_bash_preexec_hooks=()
_ms_bash_prompt_replay=:

_ms_bash_register_prompt() { _ms_bash_hook_add _ms_bash_prompt_hooks "$1"; }
_ms_bash_register_first_prompt() { _ms_bash_hook_add _ms_bash_first_prompt_hooks "$1"; }
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

_ms_bash_prompt_dispatch() {
    local callback
    if (( ${#_ms_bash_first_prompt_hooks[@]} )); then
        local -a first_prompt=("${_ms_bash_first_prompt_hooks[@]}")
        _ms_bash_first_prompt_hooks=()
        for callback in "${first_prompt[@]}"; do
            if declare -F "$callback" >/dev/null; then "$callback" || :; fi
        done
    fi
    if [[ ! ${_ms_bash_hook_pwd_set-} || $_ms_bash_hook_pwd != "$PWD" ]]; then
        _ms_bash_hook_pwd=$PWD
        _ms_bash_hook_pwd_set=1
        for callback in "${_ms_bash_chpwd_hooks[@]}"; do
            if declare -F "$callback" >/dev/null; then "$callback" || :; fi
        done
    fi
    for callback in "${_ms_bash_prompt_hooks[@]}"; do
        if declare -F "$callback" >/dev/null; then "$callback" "$@" || :; fi
    done
}

# Arguments are expanded before a backend callback or PROMPT_COMMAND runs.
_ms_bash_ble_prompt() { _ms_bash_prompt_dispatch "$?" "${BLE_PIPESTATUS[@]}"; }
_ms_bash_bp_prompt() {
    local status=$? pipeline=("${BP_PIPESTATUS[@]}")
    _ms_bash_prompt_dispatch "$status" "${pipeline[@]}"
    if [[ ! ${_ms_bash_bp_owned-} ]]; then _ms_bash_bp_wrap_foreign; fi
    _ms_bash_prompt_build_replay _ms_bash_bp_replay "${_ms_bash_bp_foreign-}" "$status" "${pipeline[@]}"
}

# bash-preexec keeps its prologue and epilogue at the outermost prompt level.
# Wrap the first foreign command between them after deferred installation, so
# it sees BP_PIPESTATUS rather than the status of the backend's prologue.
_ms_bash_bp_wrap_foreign() {
    # shellcheck disable=SC2016 # Match the backend's literal prompt command.
    local prologue='__bp_precmd_invoke_cmd "$_"' epilogue=__bp_interactive_mode
    local index=0 prior=${PROMPT_COMMAND[0]-} prefix='' suffix='' foreign
    case $prior in
        "$prologue"$'\n'*)
            prefix=$prologue$'\n'
            foreign=${prior#"$prefix"}
            ;;
        "$prologue")
            for index in "${!PROMPT_COMMAND[@]}"; do
                (( index != 0 )) || continue
                prior=${PROMPT_COMMAND[index]}
                break
            done
            (( index != 0 )) || return 0
            foreign=$prior
            ;;
        *) return 0 ;;
    esac
    if [[ $foreign == *$'\n'"$epilogue" ]]; then
        suffix=$'\n'$epilogue
        foreign=${foreign%"$suffix"}
    fi
    [[ -n $foreign && $foreign != "$epilogue" ]] || return 0
    _ms_bash_bp_foreign=$foreign
    _ms_bash_bp_prior=$prior
    _ms_bash_bp_index=$index
    # shellcheck disable=SC2016
    _ms_bash_bp_owned=$prefix'eval "$_ms_bash_bp_replay"'$suffix
    _ms_bash_bp_replace "$_ms_bash_bp_owned"
}

_ms_bash_bp_replace() {
    if [[ $(declare -p PROMPT_COMMAND 2>/dev/null) == 'declare -a'* ]]; then
        PROMPT_COMMAND[_ms_bash_bp_index]=$1
    else
        # shellcheck disable=SC2178 # Keep the scalar form on Bash 4.4 and 5.0.
        PROMPT_COMMAND=$1
    fi
}

_ms_bash_has_bash_preexec() {
    [[ -n ${bash_preexec_imported-}${__bp_imported-} &&
       ${PROMPT_COMMAND[*]-} == *'__bp_'* ]] &&
        declare -F __bp_precmd_invoke_cmd >/dev/null
}

# The bundled backend's first-prompt installer and installed hooks survive
# module reload. Only the callbacks registered through this file are retired.
_ms_bash_is_backend_function() {
    [[ ${_ms_bash_atuin_loaded_preexec-} == 1 && $1 == __bp_* ]]
}

_ms_bash_prompt_capture() {
    _ms_bash_prompt_dispatch "$@"
    _ms_bash_prompt_build_replay _ms_bash_prompt_replay "${_ms_bash_prompt_foreign-}" "$@"
}

_ms_bash_prompt_build_replay() {
    local -n replay=$1
    local foreign=$2 status=$3 code separator='' pipeline_status=0
    shift 3
    replay=:
    [[ -n $foreign ]] || return 0

    # A shell function's return resets PIPESTATUS. Recreate the captured pipeline
    # inside the same eval as the first foreign prompt command, so it sees both
    # the incoming status and the full pipeline. The values are shell statuses.
    replay=''
    for code in "$@"; do
        [[ $code =~ ^[0-9]+$ ]] || code=1
        replay+="${separator}_ms_bash_prompt_return $code"
        separator=' | '
        if [[ ! -o pipefail || $code != 0 ]]; then pipeline_status=$code; fi
    done
    if [[ -z $replay ]]; then
        replay="_ms_bash_prompt_return $status"
    elif [[ $pipeline_status != "$status" ]]; then
        # Negated pipelines retain their original PIPESTATUS but invert $?.
        replay="! $replay"
    fi
    replay+="; $foreign"
}

_ms_bash_prompt_return() { return "$1"; }

# A directory widget runs between prompts. Update the same callbacks and let
# the editor redraw the current buffer with the new prompt.
_ms_bash_widget_redraw() {
    if [[ ${_ms_bash_prompt_owned-} ]]; then
        _ms_bash_prompt_capture 0 0
        eval "$_ms_bash_prompt_replay"
    else
        _ms_bash_prompt_dispatch 0 0
    fi
    if declare -F ble/widget/redraw-line >/dev/null; then
        ble/widget/redraw-line
    else
        printf '\r\033[2K%s' "${PS1@P}"
    fi
}

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
    [[ ${_ms_bash_hooks_installed-} != 1 ]] || return 0
    _ms_bash_hooks_installed=1
    _ms_bash_hook_pwd_set=
    if (( ${#_ms_bash_first_prompt_hooks[@]} || ${#_ms_bash_prompt_hooks[@]} || ${#_ms_bash_chpwd_hooks[@]} )); then
        if declare -F blehook >/dev/null; then
            blehook 'PRECMD!=_ms_bash_ble_prompt'
            _ms_bash_prompt_backend=ble
        elif _ms_bash_has_bash_preexec; then
            _ms_bash_hook_add precmd_functions _ms_bash_bp_prompt
            _ms_bash_prompt_backend=bash_preexec
        else
            _ms_bash_prompt_install
        fi
    fi
    (( ${#_ms_bash_preexec_hooks[@]} )) || return 0
    # shellcheck disable=SC2154 # The backend declares this registry.
    if declare -F blehook >/dev/null; then
        blehook 'PREEXEC!=_ms_bash_preexec_dispatch'
        _ms_bash_preexec_backend=ble
    elif _ms_bash_has_bash_preexec || declare -p preexec_functions >/dev/null 2>&1; then
        _ms_bash_hook_add preexec_functions _ms_bash_preexec_dispatch
        _ms_bash_preexec_backend=bash_preexec
    fi
}

_ms_bash_hook_remove() {
    local -n registry_ref=$1
    local index
    for index in "${!registry_ref[@]}"; do
        [[ ${registry_ref[index]} != "$2" ]] || unset 'registry_ref[index]'
    done
}

_ms_bash_hooks_reset() {
    local prefix
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
    case ${_ms_bash_prompt_backend-} in
        ble) blehook 'PRECMD-=_ms_bash_ble_prompt' ;;
        bash_preexec)
            if [[ ${_ms_bash_bp_owned-} && ${PROMPT_COMMAND[_ms_bash_bp_index]-} == "$_ms_bash_bp_owned" ]]; then
                _ms_bash_bp_replace "$_ms_bash_bp_prior"
            fi
            unset _ms_bash_bp_owned _ms_bash_bp_prior _ms_bash_bp_index _ms_bash_bp_foreign _ms_bash_bp_replay
            _ms_bash_hook_remove precmd_functions _ms_bash_bp_prompt ;;
    esac
    case ${_ms_bash_preexec_backend-} in
        ble) blehook 'PREEXEC-=_ms_bash_preexec_dispatch' ;;
        bash_preexec) _ms_bash_hook_remove preexec_functions _ms_bash_preexec_dispatch ;;
    esac
    _ms_bash_prompt_hooks=()
    _ms_bash_first_prompt_hooks=()
    _ms_bash_chpwd_hooks=()
    _ms_bash_preexec_hooks=()
    unset _ms_bash_hooks_installed _ms_bash_hook_pwd_set _ms_bash_preexec_backend \
        _ms_bash_prompt_backend _ms_bash_prompt_owned _ms_bash_prompt_index _ms_bash_prompt_foreign
}
