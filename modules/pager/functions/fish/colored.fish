# colored COMMAND [ARG...]: run a function or command with the coloured man page
# environment (less termcap, less as the pager, plain C locale for groff).
function colored --description 'Run a command with coloured man page settings'
    set -q argv[1]; or return 2
    set -lx LESS_TERMCAP_mb $_ms_fish_less_termcap_mb
    set -lx LESS_TERMCAP_md $_ms_fish_less_termcap_md
    set -lx LESS_TERMCAP_me $_ms_fish_less_termcap_me
    set -lx LESS_TERMCAP_so $_ms_fish_less_termcap_so
    set -lx LESS_TERMCAP_se $_ms_fish_less_termcap_se
    set -lx LESS_TERMCAP_us $_ms_fish_less_termcap_us
    set -lx LESS_TERMCAP_ue $_ms_fish_less_termcap_ue
    set -l pager $PAGER
    set -l less (command -s less)
    set -q less[1]; and set pager $less[1]
    set -lx PAGER $pager
    set -lx GROFF_NO_SGR 1
    set -lx LC_ALL C
    set -lx LANG C
    if test "$argv[1]" = command
        command $argv[2..]
    else if functions -q -- $argv[1]
        $argv
    else
        command $argv
    end
end
