# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; sh-indentation: 4; sh-shell: zsh -*-

#
# history-atuin module, init phase (spec 6.12): atuin is the only history store.
# Cached atuin init (Ctrl-R, Up, hooks), no native history file, in-memory history
# stays for !! and recall, and history and h list atuin's store. Quiet and offline:
# nothing is printed and no atuin command runs besides the cached init.
#

(( ${_ms_reloading:-0} )) || _ms_init_cached atuin atuin init zsh || true

# Policy variables are shell-local, never exported to children.
unset HISTFILE
typeset +x -g HISTSIZE=5000 SAVEHIST=0
unsetopt sharehistory incappendhistory appendhistory
setopt histignoredups histreduceblanks

# history          every atuin entry, oldest first, "<time>  <command>"
# history -N       the last N of those lines
# history <other>  the in-memory builtin (recall, !!, fc)
# When atuin init did not run, ATUIN_SESSION is unset and atuin refuses to
# list; a fresh session id then goes to that one call only.
history() {
    emulate -L zsh
    if ! have_command atuin; then
        builtin history "$@"
        return
    fi
    local fmt='{time}  {command}'
    if (( $# == 0 )); then
        ATUIN_SESSION=${ATUIN_SESSION:-$(command atuin uuid 2>/dev/null)} \
            command atuin history list --format "$fmt"
    elif [[ $# == 1 && $1 == -<-> ]]; then
        ATUIN_SESSION=${ATUIN_SESSION:-$(command atuin uuid 2>/dev/null)} \
            command atuin history list --format "$fmt" | command tail -n "${1#-}"
    else
        builtin history "$@"
    fi
}

h() { history -35; }
true
