# Apply the caller-state protocol as data in the current fish process.
function _ms_apply_directives --no-scope-shadowing
    while read -l _ms_line
        set -l _ms_fields (string split \t -- "$_ms_line")
        set -l _ms_op $_ms_fields[1]
        switch $_ms_op
            case cd pushd
                test (count $_ms_fields) -eq 2; or continue
                set -l _ms_raw (string replace -a '%0A' \n -- "$_ms_fields[2]" | string replace -a '%09' \t | string replace -a '%25' '%' | string collect -N)
                set -l _ms_value (string split -r -m 1 -f 1 \n -- "$_ms_raw")
                if test "$_ms_op" = cd
                    builtin cd -- "$_ms_value" >/dev/null; or return 1
                else
                    pushd "$_ms_value" >/dev/null; or return 1
                end
            case setenv
                test (count $_ms_fields) -eq 3; or continue
                string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- "$_ms_fields[2]"; or continue
                set -l _ms_value ''
                if test -n "$_ms_fields[3]"
                    set -l _ms_raw (string replace -a '%0A' \n -- "$_ms_fields[3]" | string replace -a '%09' \t | string replace -a '%25' '%' | string collect -N)
                    set _ms_value (string split -r -m 1 -f 1 \n -- "$_ms_raw")
                end
                true
                set -gx "$_ms_fields[2]" "$_ms_value"; or return 1
            case unsetenv
                test (count $_ms_fields) -eq 2; or continue
                string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- "$_ms_fields[2]"; or continue
                if set -q -U "$_ms_fields[2]"
                    printf 'marksharc: unsafe directive target: %s\n' "$_ms_fields[2]" >&2
                    return 1
                end
                if set -q -g "$_ms_fields[2]"
                    set -e -g "$_ms_fields[2]"; or return 1
                end
            case exit
                if test (count $_ms_fields) -eq 1
                    set _ms_exit_status 0
                else
                    set -l normalized (string replace -r '^0+' '' -- "$_ms_fields[2]")
                    test -n "$normalized"; or set normalized 0
                    if test (count $_ms_fields) -eq 2; and string match -qr '^[0-9]+$' -- "$_ms_fields[2]"; and test (string length -- "$normalized") -le 3; and test $normalized -le 255
                        set _ms_exit_status $normalized
                    else
                        printf 'marksharc: invalid exit directive status\n' >&2
                    end
                end
            case '*'
                printf 'marksharc: unknown directive: %s\n' "$_ms_op" >&2
        end
    end <"$argv[1]"
end

function _ms_fish_run_with_directives
    set -l _ms_exit_status ''
    set -l tmp /tmp
    set -q TMPDIR; and test -n "$TMPDIR"; and set tmp "$TMPDIR"
    set -lx MARKSHARC_DIRECTIVES (command mktemp "$tmp/marksharc-directives.XXXXXXXX"); or return 1
    command $argv
    set -l command_status $status
    _ms_apply_directives "$MARKSHARC_DIRECTIVES"
    set -l apply_status $status
    command rm -f -- "$MARKSHARC_DIRECTIVES"
    set -l remove_status $status
    if test $command_status -eq 0; and test $apply_status -eq 0; and test $remove_status -eq 0; and test -n "$_ms_exit_status"
        builtin exit $_ms_exit_status
    end
    test $command_status -ne 0; and return $command_status
    test $apply_status -ne 0; and return $apply_status
    return $remove_status
end
