# Apply the caller-state protocol without evaluating its fields as shell code.
_ms_bash_decode_field() {
    _ms_bash_decoded=${1//%0A/$'\n'}
    _ms_bash_decoded=${_ms_bash_decoded//%09/$'\t'}
    _ms_bash_decoded=${_ms_bash_decoded//%25/%}
}

_ms_bash_safe_target() {
    local _ms_name=$1 _ms_declaration _ms_attributes
    [[ $_ms_name =~ ^[A-Za-z_][A-Za-z0-9_]*$ && $_ms_name != _ms_* ]] || return 1
    _ms_declaration=$(declare -p "$_ms_name" 2>/dev/null) || return 0
    _ms_attributes=${_ms_declaration#declare -}
    _ms_attributes=${_ms_attributes%% *}
    case $_ms_attributes in -|x) return 0 ;; *) return 1 ;; esac
}

_ms_bash_apply_directives() {
    local _ms_line _ms_rest _ms_op _ms_bash_decoded _ms_name _ms_status
    local -a _ms_fields
    [[ ${_ms_exit_status+x} ]] || local _ms_exit_status=''
    while IFS= read -r _ms_line || [[ -n $_ms_line ]]; do
        _ms_fields=()
        _ms_rest=$_ms_line
        while [[ $_ms_rest == *$'\t'* ]]; do
            _ms_fields+=("${_ms_rest%%$'\t'*}")
            _ms_rest=${_ms_rest#*$'\t'}
        done
        _ms_fields+=("$_ms_rest")
        _ms_op=${_ms_fields[0]}
        case $_ms_op in
            cd|pushd)
                (( ${#_ms_fields[@]} == 2 )) || continue
                _ms_bash_decode_field "${_ms_fields[1]}"
                case $_ms_bash_decoded in
                    '') return 1 ;;
                    /*) ;;
                    *) _ms_bash_decoded=./$_ms_bash_decoded ;;
                esac
                builtin "$_ms_op" -- "$_ms_bash_decoded" >/dev/null || return 1
                ;;
            setenv|unsetenv)
                if [[ $_ms_op == setenv ]]; then
                    (( ${#_ms_fields[@]} == 3 )) || continue
                else
                    (( ${#_ms_fields[@]} == 2 )) || continue
                fi
                _ms_name=${_ms_fields[1]}
                [[ $_ms_name =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
                if ! _ms_bash_safe_target "$_ms_name"; then
                    printf 'marksharc: unsafe directive target: %s\n' "$_ms_name" >&2
                    return 1
                fi
                if [[ $_ms_op == setenv ]]; then
                    _ms_bash_decode_field "${_ms_fields[2]}"
                    export "$_ms_name=$_ms_bash_decoded" || return 1
                else
                    unset -v "$_ms_name" || return 1
                fi
                ;;
            exit)
                if (( ${#_ms_fields[@]} == 1 )); then
                    _ms_exit_status=0
                else
                    _ms_status=${_ms_fields[1]}
                    while [[ ${#_ms_status} -gt 1 && $_ms_status == 0* ]]; do _ms_status=${_ms_status:1}; done
                    if (( ${#_ms_fields[@]} == 2 )) && [[ $_ms_status =~ ^[0-9]+$ && ${#_ms_status} -le 3 ]] && (( 10#$_ms_status <= 255 )); then
                        _ms_exit_status=$((10#$_ms_status))
                    else
                        printf 'marksharc: invalid exit directive status\n' >&2
                    fi
                fi
                ;;
            *) printf 'marksharc: unknown directive: %s\n' "$_ms_op" >&2 ;;
        esac
    done < "$1"
}

_ms_bash_run_with_directives() {
    local _ms_file _ms_command_status=0 _ms_apply_status=0 _ms_remove_status=0 _ms_exit_status=''
    local _ms_tmp=${TMPDIR:-/tmp} _ms_rm
    # A directive can change both the working directory and PATH.
    [[ $_ms_tmp == /* ]] || _ms_tmp=$PWD/$_ms_tmp
    _ms_rm=$(type -P -- rm) || return 1
    [[ $_ms_rm == /* ]] || _ms_rm=$PWD/$_ms_rm
    _ms_file=$(command mktemp "$_ms_tmp/marksharc-directives.XXXXXXXX") || return 1
    MARKSHARC_DIRECTIVES=$_ms_file command "$@" || _ms_command_status=$?
    _ms_bash_apply_directives "$_ms_file" || _ms_apply_status=$?
    command "$_ms_rm" -f -- "$_ms_file" || _ms_remove_status=$?
    if (( _ms_command_status == 0 && _ms_apply_status == 0 && _ms_remove_status == 0 )) && [[ -n $_ms_exit_status ]]; then
        builtin exit "$_ms_exit_status"
    fi
    (( _ms_command_status == 0 )) || return "$_ms_command_status"
    (( _ms_apply_status == 0 )) || return "$_ms_apply_status"
    return "$_ms_remove_status"
}
