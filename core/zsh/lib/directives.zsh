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

_ms_directive_decode() {
    REPLY=${1//\%0A/$'\n'}
    REPLY=${REPLY//\%09/$'\t'}
    REPLY=${REPLY//\%25/\%}
}

_ms_apply_directives() {
    emulate -L zsh
    local line op name value
    local -a fields
    while IFS= read -r line || [[ -n $line ]]; do
        fields=( "${(@ps:\t:)line}" )
        op=${fields[1]-}
        case $op in
            cd|pushd)
                (( $#fields == 2 )) || continue
                _ms_directive_decode "$fields[2]"
                builtin "$op" -- "$REPLY" >/dev/null || return 1 ;;
            setenv)
                (( $#fields == 3 )) || continue
                name=$fields[2]
                [[ $name =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || continue
                _ms_directive_decode "$fields[3]"
                export "$name=$REPLY" ;;
            unsetenv)
                (( $#fields == 2 )) || continue
                name=$fields[2]
                [[ $name =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || continue
                unset "$name" ;;
            *) print -ru2 -- "marksharc: unknown directive: $op" ;;
        esac
    done < "$1"
}
