# pager module, init phase: PAGER, LESS, MANPATH, coloured man pages (the OMZ less_termcap
# mapping, scoped to the man call), a coloured diff, and diffcp (functions/fish/diffcp.fish).
if _ms_fish_command_available less
    set -gx PAGER 'less -R'
end
set -gx LESS -FRX
set -l _ms_manpath /usr/share/man
test -d /usr/local/man; and set -a _ms_manpath /usr/local/man
set -gx MANPATH $_ms_manpath

# The termcap values (bold red blink and bold, bold yellow on blue standout, bold green
# underline), kept apart from the environment so only man and colored see them.
set -g _ms_fish_less_termcap_mb \e'[01;31m'
set -g _ms_fish_less_termcap_md \e'[01;31m'
set -g _ms_fish_less_termcap_me \e'[00m'
set -g _ms_fish_less_termcap_so \e'[01;33m'\e'[44m'
set -g _ms_fish_less_termcap_se \e'[00m'
set -g _ms_fish_less_termcap_us \e'[01;32m'
set -g _ms_fish_less_termcap_ue \e'[00m'

# Keep fish's own man function (it prepends fish's man pages and maps : [ . to their
# pages) as the thing that runs, and wrap a copy of it. A reload keeps the copy.
if command -sq man
    if not functions -q _ms_fish_man_plain
        if functions -q man
            functions -c man _ms_fish_man_plain
        else
            function _ms_fish_man_plain
                command man $argv
            end
        end
    end
    function man --wraps man --description 'Format and display the on-line manual pages, in colour'
        colored _ms_fish_man_plain $argv
    end
    _ms_fish_track_functions man
end
for _ms_name in dman debman
    if command -sq $_ms_name
        function $_ms_name --wraps $_ms_name --inherit-variable _ms_name --description 'Coloured Debian man pages'
            colored command $_ms_name $argv
        end
        _ms_fish_track_functions $_ms_name
    end
end

# Use diff --color=always if available, then default the wrapper to --color=auto.
if command diff --color=always /dev/null /dev/null &>/dev/null
    function diff --wraps diff --description 'diff with --color=auto'
        command diff --color=auto $argv
    end
    _ms_fish_track_functions diff
end
return 0
