# Caller-state protocol. Fields are data, never shell code.
_ms_directive_fields() {
    local field line='' separator=''
    for field in "$@"; do
        field=${field//\%/\%25}
        field=${field//$'\t'/\%09}
        field=${field//$'\n'/\%0A}
        line+="$separator$field"
        separator=$'\t'
    done
    print -r -- "$line"
}

_ms_directive_emit() {
    emulate -L zsh
    [[ -n ${MARKSHARC_DIRECTIVES-} ]] || return 0
    _ms_directive_fields "$@" >> "$MARKSHARC_DIRECTIVES"
}

_ms_apply_directives() {
    emulate -L zsh
    local _ms_line _ms_op _ms_name _ms_decoded _ms_status
    local -a _ms_fields
    (( ${+_ms_exit_status} )) || local _ms_exit_status=''
    zmodload -F zsh/parameter p:parameters 2>/dev/null || return 1
    while IFS= read -r _ms_line || [[ -n $_ms_line ]]; do
        _ms_fields=( "${(@ps:\t:)_ms_line}" )
        _ms_op=${_ms_fields[1]-}
        case $_ms_op in
            cd|pushd)
                (( $#_ms_fields == 2 )) || continue
                _ms_decoded=${_ms_fields[2]//\%0A/$'\n'}
                _ms_decoded=${_ms_decoded//\%09/$'\t'}
                _ms_decoded=${_ms_decoded//\%25/\%}
                builtin "$_ms_op" -- "$_ms_decoded" >/dev/null || return 1 ;;
            setenv)
                (( $#_ms_fields == 3 )) || continue
                _ms_name=$_ms_fields[2]
                [[ $_ms_name =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || continue
                case ${parameters[$_ms_name]-} in
                    integer*|float*|array*|association*|*readonly*)
                        print -ru2 -- "marksharc: unsafe directive target: $_ms_name"
                        return 1 ;;
                esac
                _ms_decoded=${_ms_fields[3]//\%0A/$'\n'}
                _ms_decoded=${_ms_decoded//\%09/$'\t'}
                _ms_decoded=${_ms_decoded//\%25/\%}
                export "$_ms_name=$_ms_decoded" ;;
            unsetenv)
                (( $#_ms_fields == 2 )) || continue
                _ms_name=$_ms_fields[2]
                [[ $_ms_name =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || continue
                unset "$_ms_name" ;;
            exit)
                if (( $#_ms_fields == 1 )); then
                    _ms_exit_status=0
                else
                    _ms_status=${_ms_fields[2]-}
                    while [[ ${#_ms_status} -gt 1 && $_ms_status == 0* ]]; do _ms_status=${_ms_status[2,-1]}; done
                    if (( $#_ms_fields == 2 )) && [[ $_ms_status == <-> && ${#_ms_status} -le 3 ]] && (( 10#$_ms_status <= 255 )); then
                        _ms_exit_status=$(( 10#$_ms_status ))
                    else
                        print -ru2 -- 'marksharc: invalid exit directive status'
                    fi
                fi ;;
            *) print -ru2 -- "marksharc: unknown directive: $_ms_op" ;;
        esac
    done < "$1"
}

_ms_run_with_directives() {
    emulate -L zsh
    local _ms_directives_file _ms_directives_rc _ms_apply_rc _ms_remove_rc _ms_exit_status=''
    _ms_directives_file=$(command mktemp "${TMPDIR:-/tmp}/marksharc-directives.XXXXXXXX") || return 1
    MARKSHARC_DIRECTIVES=$_ms_directives_file "$@"
    _ms_directives_rc=$?
    _ms_apply_directives "$_ms_directives_file"
    _ms_apply_rc=$?
    (( _ms_directives_rc != 0 )) || _ms_directives_rc=$_ms_apply_rc
    command rm -f -- "$_ms_directives_file"
    _ms_remove_rc=$?
    if (( _ms_directives_rc == 0 && _ms_apply_rc == 0 && _ms_remove_rc == 0 )) && [[ -n $_ms_exit_status ]]; then
        builtin exit "$_ms_exit_status"
    fi
    (( _ms_directives_rc != 0 )) || _ms_directives_rc=$_ms_remove_rc
    return $_ms_directives_rc
}
