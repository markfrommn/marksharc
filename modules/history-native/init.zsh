# -*- mode: shell-script; indent-tabs-mode: nil; sh-basic-offset: 4; sh-indentation: 4; sh-shell: zsh -*-

#
# history-native module, init phase (spec 6.12): the fallback for hosts without atuin.
# One small history file under the state directory and a fixed option set. When atuin
# is installed the history-atuin module owns history and this file does nothing.
#
have_command atuin && return 0

typeset +x -g HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/marksharc/history"
command mkdir -p -- "${HISTFILE:h}" 2>/dev/null
typeset +x -g HISTSIZE=10000 SAVEHIST=10000
unsetopt sharehistory
setopt extendedhistory incappendhistory histignoredups histreduceblanks \
       histsavenodups histverify

h() { history -35; }
true
