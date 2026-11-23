# Caller-state protocol. Fields are data, never shell code.
_ms_directive_emit() {
    emulate -L zsh
    [[ -n ${MARKSHARC_DIRECTIVES-} ]] || return 0
    local field line='' separator=''
    for field in "$@"; do
        field=${field//\%/\%25}
        field=${field//$'\t'/\%09}
        field=${field//$'\n'/\%0A}
        line+="$separator$field"
        separator=$'\t'
    done
    print -r -- "$line" >> "$MARKSHARC_DIRECTIVES"
}

_ms_apply_directives() {
    emulate -L zsh
    local _ms_line _ms_op _ms_name _ms_decoded
    local -a _ms_fields
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
                _ms_decoded=${_ms_fields[3]//\%0A/$'\n'}
                _ms_decoded=${_ms_decoded//\%09/$'\t'}
                _ms_decoded=${_ms_decoded//\%25/\%}
                export "$_ms_name=$_ms_decoded" ;;
            unsetenv)
                (( $#_ms_fields == 2 )) || continue
                _ms_name=$_ms_fields[2]
                [[ $_ms_name =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || continue
                unset "$_ms_name" ;;
            *) print -ru2 -- "marksharc: unknown directive: $_ms_op" ;;
        esac
    done < "$1"
}

_ms_run_with_directives() {
    emulate -L zsh
    local _ms_directives_file _ms_directives_rc
    _ms_directives_file=$(command mktemp "${TMPDIR:-/tmp}/marksharc-directives.XXXXXXXX") || return 1
    MARKSHARC_DIRECTIVES=$_ms_directives_file "$@"
    _ms_directives_rc=$?
    if (( _ms_directives_rc == 0 )); then
        _ms_apply_directives "$_ms_directives_file" || _ms_directives_rc=$?
    fi
    command rm -f -- "$_ms_directives_file"
    return $_ms_directives_rc
}
