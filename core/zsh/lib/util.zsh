# -*- mode: shell-script; sh-shell: zsh -*-
# Core helpers shared by every phase. Sourced at top level by zshenv.zsh.

# Verbose trace (spec 6.10): stderr only, and only when MARKSHARC_VERBOSE is set.
_ms_trace() {
    (( ${_ms_verbose:-0} )) || return 0
    print -ru2 -- "marksharc: $*"
}

# Milliseconds since the epoch into REPLY, with sub-millisecond precision.
_ms_now() {
    zmodload -F zsh/datetime p:EPOCHREALTIME 2>/dev/null
    REPLY=$(( EPOCHREALTIME * 1000 ))
}

have_command() {
    setopt localoptions noxtrace
    command -v "$1" >/dev/null 2>&1
}

fn_exists() {
    setopt localoptions noxtrace
    (( $+functions[$1] ))
}

# Are we in or under docker? Reads files with builtins.
in_docker() {
    setopt localoptions noxtrace
    [[ -f /.dockerenv ]] && return 0
    [[ -r /proc/1/cgroup && $(</proc/1/cgroup) == *docker* ]] && return 0
    # PID 1 is probably docker; not bulletproof but works on mac and windows.
    (( $$ == 1 ))
}

# Interactive echo: prints only for interactive sessions. While a startup phase
# is running it feeds the verbose trace instead, so startup stays silent.
iecho() {
    setopt localoptions noxtrace
    if (( ${_ms_starting:-0} )); then
        [[ $1 == -n ]] && shift
        _ms_trace "$*"
    elif [[ ${MARKSHARC_SESSION-} == interactive ]]; then
        echo $*
    fi
    return 0
}

# Interactive print to stderr, with the same startup rule as iecho.
ierr() {
    setopt localoptions noxtrace
    if (( ${_ms_starting:-0} )); then
        _ms_trace "$*"
    elif [[ ${MARKSHARC_SESSION-} == interactive ]]; then
        print -u2 $*
    fi
    return 0
}

# Define a function given a name and body.
make_function() {
    if (( $# != 2 )); then
        echo "make_function requires exactly 2 arguments:  <name>, <body>"
        return 1
    fi
    functions[$1]=$2
}

# Remove all functions whose names match a regex.
purge_functions() {
    if (( $# != 1 )); then
        echo "purge_functions requires exactly 1 argument <string to match as regex>"
        return 1
    fi
    local afunc
    for afunc in ${(k)functions}; do
        if [[ $afunc =~ $1 ]]; then unfunction $afunc 2>/dev/null; fi
    done
}
