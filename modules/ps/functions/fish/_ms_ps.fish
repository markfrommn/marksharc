# _ms_ps <all|own> <plain|jobs> [pattern...]
#
# The ps helpers' shared implementation, as in zsh. Portable BSD-style flags and explicit -o
# columns give the same layout on macOS and Linux. The listing is captured first and
# filtered in the shell with a regular expression (several patterns are alternatives), so
# no grep process exists to match itself; the header line is always kept and the ps
# invocation's own line is dropped. No pattern lists everything.
#
# With procs installed and the ps.procs option on, ps still selects the processes and procs
# draws them: the selected PIDs become procs keywords (a number matches a PID exactly), and
# the job view adds the parent, process group and state columns. All processes with no
# pattern is plain procs; when nothing is selected nothing is printed.
function _ms_ps
    set -l scope $argv[1]
    set -l view $argv[2]
    set -e argv[1..2]
    set -l use_procs 0
    if contains -- "$_ms_opt_ps_procs" on 1 yes true ''; and command -q procs
        set use_procs 1
    end
    set -l args x
    test "$scope" = all; and set args ax
    set -l procs_args
    if test "$view" = jobs
        set -a args -o pid,ppid,pgid,tpgid,stat,tty,user,command
        set procs_args --insert Ppid --insert Pgid --insert State
    else
        set -a args -o pid,ppid,user,stat,etime,command
    end
    set -l pat
    if not set -q argv[1]
        if test $use_procs -eq 0
            command ps $args
            return
        else if test "$scope" = all
            command procs $procs_args
            return
        end
    else
        set pat (string join '|' -- $argv)
        string match -qr -- "$pat" x 2>/dev/null
        if test $status -gt 1
            printf 'ps: invalid pattern: %s\n' "$pat" >&2
            return 2
        end
    end
    set -l out (command ps $args); or return $status
    set -l selfcmd "ps "(string join ' ' -- $args)
    test $use_procs -eq 1; or printf '%s\n' $out[1]
    set -l pids
    for line in $out[2..]
        string match -q -- "*$selfcmd" "$line"; and continue
        if test -n "$pat"
            string match -qr -- "$pat" "$line"; or continue
        end
        if test $use_procs -eq 1
            set -a pids (string split -n ' ' -- (string trim -- "$line"))[1]
        else
            printf '%s\n' "$line"
        end
    end
    if test $use_procs -eq 1; and set -q pids[1]
        command procs $procs_args --or $pids
        return
    end
    return 0
end
