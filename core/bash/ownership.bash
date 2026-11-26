# Reload tracks the declarations it installed and retires only matching effects.
declare -gA _ms_bash_previous=() _ms_bash_installed=() _ms_bash_replaced=() _ms_bash_process_functions=()
declare -ga _ms_bash_owned_path=()

_ms_bash_effect() {
    case $1 in
        function) builtin declare -f -- "$2" ;;
        alias) builtin alias -- "$2" 2>/dev/null ;;
        complete) builtin complete -p -- "$2" 2>/dev/null ;;
        variable) builtin declare -p -- "$2" 2>/dev/null ;;
    esac || :
}

_ms_bash_restore_effect() {
    local _ms_kind=$1 _ms_name=$2 _ms_definition=$3
    if [[ -n $_ms_definition ]]; then
        # Definitions come from Bash's own introspection of live, trusted shell
        # code and variables. Disable alias expansion for faithful restoration.
        local _ms_expand=0
        if shopt -q expand_aliases; then _ms_expand=1; shopt -u expand_aliases; fi
        case $_ms_kind in
            variable)
                builtin unset -v -- "$_ms_name"
                builtin eval "builtin declare -g ${_ms_definition#declare }" ;;
            *) builtin eval "$_ms_definition" ;;
        esac
        if (( _ms_expand )); then shopt -s expand_aliases; fi
    else
        case $_ms_kind in
            function) builtin unset -f -- "$_ms_name" ;;
            alias) builtin unalias -- "$_ms_name" 2>/dev/null ;;
            complete) builtin complete -r -- "$_ms_name" 2>/dev/null ;;
            variable) builtin unset -v -- "$_ms_name" ;;
        esac
    fi
    return 0
}

_ms_bash_record_effect() {
    local _ms_key=$1:$2
    [[ $3 != "$4" ]] || return 0
    if [[ ${_ms_bash_replaced[$_ms_key]+yes} ]]; then
        _ms_bash_restore_effect "$1" "$2" "$3"
        return
    fi
    if [[ ! ${_ms_bash_previous[$_ms_key]+yes} ]]; then
        _ms_bash_previous[$_ms_key]=$3
    fi
    _ms_bash_installed[$_ms_key]=$4
}

_ms_bash_set_scalar() {
    local _ms_key=variable:$1 _ms_before _ms_flags
    [[ $1 =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ && ! ${_ms_bash_replaced[$_ms_key]+yes} ]] || return 0
    if [[ $3 == option && ${!1+x} && ${!1} == "$2" ]]; then return 0; fi
    _ms_before=$(_ms_bash_effect variable "$1")
    _ms_flags=${_ms_before#declare -}
    _ms_flags=${_ms_flags%% *}
    # Bash's other attributes can coerce values or redirect the assignment.
    case $_ms_flags in ''|-|x) ;; *) return 1 ;; esac
    if [[ $3 == export ]]; then
        builtin export "$1=$2" || return
    else
        builtin printf -v "$1" '%s' "$2" || return
    fi
    _ms_bash_record_effect variable "$1" "$_ms_before" "$(_ms_bash_effect variable "$1")"
}

_ms_bash_set_env() {
    [[ $1 != _ms_* ]] || return 1
    _ms_bash_set_scalar "$1" "$2" export
}
_ms_bash_set_option() { _ms_bash_set_scalar "$1" "$2" option; }

# The loader snapshots native function/alias definitions around the init phase.
_ms_bash_snapshot_definitions() {
    local -n _ms_snapshot=$1
    local _ms_key _ms_function _ms_definition _ms_alias
    while IFS= read -r -d '' _ms_key && IFS= read -r -d '' _ms_definition; do
        # The caller supplies an associative array.
        # shellcheck disable=SC2004
        _ms_snapshot[$_ms_key]=${_ms_definition%$'\n'}
    done < <(
        while IFS= read -r _ms_function; do
            if [[ ${_ms_bash_process_functions[$_ms_function]+yes} ]]; then continue; fi
            # The editor loads more libraries lazily after the initial snapshot.
            if [[ ${_ms_bash_active_editor-} == ble ]]; then
                case $_ms_function in ble/*|ble-*|_ble_*) continue ;; esac
            fi
            printf 'function:%s\0' "$_ms_function"
            builtin declare -f -- "$_ms_function"
            printf '\0'
        done < <(compgen -A function)
        for _ms_alias in "${!BASH_ALIASES[@]}"; do
            printf 'alias:%s\0' "$_ms_alias"
            builtin alias -- "$_ms_alias"
            printf '\0'
        done
    )
}

_ms_bash_record_definitions() {
    local -n _ms_prior=$1 _ms_current=$2
    local _ms_key
    for _ms_key in "${!_ms_current[@]}"; do
        if [[ $_ms_key == function:* ]] && _ms_bash_is_backend_function "${_ms_key#*:}"; then continue; fi
        _ms_bash_record_effect "${_ms_key%%:*}" "${_ms_key#*:}" "${_ms_prior[$_ms_key]-}" "${_ms_current[$_ms_key]}"
    done
    for _ms_key in "${!_ms_prior[@]}"; do
        [[ ${_ms_current[$_ms_key]+yes} ]] ||
            _ms_bash_record_effect "${_ms_key%%:*}" "${_ms_key#*:}" "${_ms_prior[$_ms_key]}" ''
    done
}

_ms_bash_reset_effects() {
    local _ms_key _ms_kind _ms_name _ms_current
    for _ms_key in "${!_ms_bash_installed[@]}"; do
        _ms_kind=${_ms_key%%:*}
        _ms_name=${_ms_key#*:}
        _ms_current=$(_ms_bash_effect "$_ms_kind" "$_ms_name")
        if [[ $_ms_current == "${_ms_bash_installed[$_ms_key]}" ]]; then
            _ms_bash_restore_effect "$_ms_kind" "$_ms_name" "${_ms_bash_previous[$_ms_key]}"
        else
            _ms_bash_replaced[$_ms_key]=1
        fi
    done
    _ms_bash_installed=() _ms_bash_previous=()
}

_ms_bash_record_path() {
    local _ms_path
    local -a _ms_parts
    IFS=: read -r -a _ms_parts <<< "$PATH"
    _ms_bash_owned_path=()
    for _ms_path in "${_ms_parts[@]}"; do
        [[ :$1: == *":$_ms_path:"* ]] || _ms_bash_owned_path+=("$_ms_path")
    done
}

_ms_bash_reset_path() {
    local _ms_path _ms_owned IFS=:
    local -a _ms_parts _ms_kept=()
    read -r -a _ms_parts <<< "$PATH"
    for _ms_path in "${_ms_parts[@]}"; do
        for _ms_owned in "${_ms_bash_owned_path[@]}"; do
            [[ $_ms_path != "$_ms_owned" ]] || continue 2
        done
        _ms_kept+=("$_ms_path")
    done
    export PATH="${_ms_kept[*]}"
}
