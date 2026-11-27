# pager module, init phase: PAGER, LESS, MANPATH, native coloured man pages (the OMZ
# less_termcap mapping), a coloured diff, and diffcp.
if have_command less; then
    export PAGER='less -R'
fi
export LESS=-FRX
# Extend MANPATH rather than replace it: what earlier modules set (brew's share/man) stays
# first, the system directories follow when absent, each entry appears once, and one empty
# entry goes last so man still searches its defaults and the share/man directory beside
# each bin on PATH.
() {
    emulate -L zsh
    local -aU dirs
    dirs=( ${${(s/:/)MANPATH}:#} /usr/share/man )
    [[ -d /usr/local/man ]] && dirs+=( /usr/local/man )
    export MANPATH="${(j/:/)dirs}:"
}

autoload -Uz colors
colors

typeset -AHg less_termcap
less_termcap[mb]="${fg_bold[red]}"
less_termcap[md]="${fg_bold[red]}"
less_termcap[me]="${reset_color}"
less_termcap[so]="${fg_bold[yellow]}${bg[blue]}"
less_termcap[se]="${reset_color}"
less_termcap[us]="${fg_bold[green]}"
less_termcap[ue]="${reset_color}"

colored() {
    emulate -L zsh
    local -a environment
    local key value
    for key value in "${(@kv)less_termcap}"; do
        environment+=( "LESS_TERMCAP_${key}=${value}" )
    done
    environment+=(
        "PAGER=${commands[less]:-$PAGER}"
        GROFF_NO_SGR=1
        LC_ALL=C
        LANG=C
    )
    command env "${environment[@]}" "$@"
}

man dman debman() {
    colored "$0" "$@"
}

# Use diff --color=always if available, then default the wrapper to --color=auto.
if command diff --color=always /dev/null{,} &>/dev/null; then
    unset -f diff 2>/dev/null
    function diff {
        command diff --color=auto "$@"
    }
fi

# A version that colours for less -R automatically.
unset -f diffcp 2>/dev/null
function diffcp {
    command diff --color=always "$@" | less -R
}
