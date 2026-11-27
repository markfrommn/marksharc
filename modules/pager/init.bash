if type -P less >/dev/null; then _ms_bash_set_env PAGER 'less -R'; fi
_ms_bash_set_env LESS -FRX
# Extend MANPATH rather than replace it: what earlier modules set (brew's share/man) stays
# first, the system directories follow when absent, each entry appears once, and one empty
# entry goes last so man still searches its defaults and the share/man directory beside
# each bin on PATH.
_ms_pager_manpath=${MANPATH:+$MANPATH:}/usr/share/man:
[[ ! -d /usr/local/man ]] || _ms_pager_manpath+=/usr/local/man:
_ms_pager_out='' _ms_pager_rest=$_ms_pager_manpath
while [[ -n $_ms_pager_rest ]]; do
    _ms_pager_dir=${_ms_pager_rest%%:*} _ms_pager_rest=${_ms_pager_rest#*:}
    [[ -n $_ms_pager_dir && :$_ms_pager_out: != *:"$_ms_pager_dir":* ]] || continue
    _ms_pager_out+=${_ms_pager_out:+:}$_ms_pager_dir
done
_ms_bash_set_env MANPATH "${_ms_pager_out}:"
unset _ms_pager_manpath _ms_pager_out _ms_pager_rest _ms_pager_dir

colored() {
    (( $# )) || return 2
    local PAGER GROFF_NO_SGR=1 LC_ALL=C LANG=C
    local LESS_TERMCAP_mb=$'\e[01;31m' LESS_TERMCAP_md=$'\e[01;31m' LESS_TERMCAP_me=$'\e[00m'
    local LESS_TERMCAP_so=$'\e[01;33m\e[44m' LESS_TERMCAP_se=$'\e[00m'
    local LESS_TERMCAP_us=$'\e[01;32m' LESS_TERMCAP_ue=$'\e[00m'
    PAGER=$(type -P less) || PAGER=${PAGER:-less}
    export PAGER GROFF_NO_SGR LC_ALL LANG LESS_TERMCAP_mb LESS_TERMCAP_md LESS_TERMCAP_me
    export LESS_TERMCAP_so LESS_TERMCAP_se LESS_TERMCAP_us LESS_TERMCAP_ue
    "$@"
}
man() { colored command man "$@"; }
dman() { colored command dman "$@"; }
debman() { colored command debman "$@"; }
if command diff --color=always /dev/null /dev/null >/dev/null 2>&1; then
    diff() { command diff --color=auto "$@"; }
fi
diffcp() { command diff --color=always "$@" | command less -R; }
