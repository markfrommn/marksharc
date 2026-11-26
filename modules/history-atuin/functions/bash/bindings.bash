# shellcheck disable=SC2004 # Keymap keys are associative array strings.
# Readline's reusable dumps include ordinary functions, macros and shell commands.
_ms_bash_atuin_keymap() {
    local -n bindings=$1
    # Bash 5.3 uses a space instead of a colon in the shell-command dump.
    local map kind line key pattern='^"(([^"\\]|\\.)*)"(:|[[:blank:]])'
    for map in emacs vi-insert vi-command; do
        # Bash 4.4 and 5.0 share the shell-command table between maps and
        # can list an old bind -x entry after a Readline function replaces it.
        # The active function or macro in the requested map takes precedence.
        for kind in X p s; do
            while IFS= read -r line; do
                [[ $line =~ $pattern ]] || continue
                key=$map:${BASH_REMATCH[1]}
                # shellcheck disable=SC2034 # Writes to the caller's map.
                bindings[$key]=$kind:$line
            done < <(bind -m "$map" "-$kind" 2>/dev/null)
        done
    done
}

_ms_bash_atuin_restore_key() {
    local map=${1%%:*} key=${1#*:} definition=$2
    bind -m "$map" -r "$key" 2>/dev/null || :
    case ${definition%%:*} in
        p|s) bind -m "$map" "${definition#*:}" ;;
        X) bind -m "$map" -x "${definition#*:}" ;;
    esac
}

_ms_bash_atuin_record_keys() {
    local -n before=$1 after=$2
    local key
    for key in "${!after[@]}"; do
        [[ ${before[$key]-} != "${after[$key]}" ]] || continue
        if [[ ${_ms_bash_atuin_key_replaced[$key]+yes} ]]; then
            _ms_bash_atuin_restore_key "$key" "${before[$key]-}"
        else
            _ms_bash_atuin_key_before[$key]=${before[$key]-}
            _ms_bash_atuin_key_after[$key]=${after[$key]}
        fi
    done
}

_ms_bash_atuin_clean_keys() {
    local key
    local -A current=()
    _ms_bash_atuin_keymap current
    for key in "${!_ms_bash_atuin_key_after[@]}"; do
        if [[ ${current[$key]-} == "${_ms_bash_atuin_key_after[$key]}" ]]; then
            _ms_bash_atuin_restore_key "$key" "${_ms_bash_atuin_key_before[$key]}"
        else
            _ms_bash_atuin_key_replaced[$key]=1
        fi
    done
    _ms_bash_atuin_key_before=() _ms_bash_atuin_key_after=()
}
