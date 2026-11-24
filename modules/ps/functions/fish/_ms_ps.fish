# _ms_ps <all|own> <plain|jobs> [pattern...]
#
# The ps helpers' shared implementation, as in zsh. Portable BSD-style flags and explicit -o
# columns give the same layout on macOS and Linux. The listing is captured first and
# filtered in the shell with a regular expression (several patterns are alternatives), so
# no grep process exists to match itself; the header line is always kept and the ps
# invocation's own line is dropped. No pattern lists everything.
function _ms_ps
    set -l scope $argv[1]
    set -l view $argv[2]
    set -e argv[1..2]
    set -l args x
    test "$scope" = all; and set args ax
    if test "$view" = jobs
        set -a args -o pid,ppid,pgid,tpgid,stat,tty,user,command
    else
        set -a args -o pid,ppid,user,stat,etime,command
    end
    if not set -q argv[1]
        command ps $args
        return
    end
    set -l pat (string join '|' -- $argv)
    string match -qr -- "$pat" x 2>/dev/null
    if test $status -gt 1
        printf 'ps: invalid pattern: %s\n' "$pat" >&2
        return 2
    end
    set -l out (command ps $args); or return $status
    set -l selfcmd "ps "(string join ' ' -- $args)
    printf '%s\n' $out[1]
    for line in $out[2..]
        string match -q -- "*$selfcmd" "$line"; and continue
        string match -qr -- "$pat" "$line"; and printf '%s\n' "$line"
    end
    return 0
end
