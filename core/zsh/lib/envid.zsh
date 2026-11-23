# -*- mode: shell-script; sh-shell: zsh -*-
# MARKSHARC_ENV id (spec 6.6). The id is derived cheaply from the render inputs:
# the mtime and size of every core, module and config file, plus $HOME, folded with
# shell arithmetic. No forks. An empty id (zsh/stat unavailable) means "always rebuild".

_ms_env_id() {
    emulate -L zsh
    _ms_env_id_value=
    zmodload -F zsh/stat b:zstat 2>/dev/null || return 0
    local f c hex config=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}
    integer h=17
    local -A st
    local -a files=(
        "$MARKSHARC_HOME"/core/**/*(.N) "$MARKSHARC_HOME"/modules/**/*(.N)
        "$config"/**/*(.N)
    )
    for f in $files; do
        zstat -H st -- "$f" 2>/dev/null || continue
        for c in ${(s::)f}; do (( h = (h * 31 + #c) % 4294967291 )); done
        (( h = (h * 31 + st[mtime] + st[size]) % 4294967291 ))
    done
    for c in ${(s::)HOME}${(s::)config}${(s::)MARKSHARC_HOST}; do
        (( h = (h * 31 + #c) % 4294967291 ))
    done
    printf -v hex '%08x' $h
    _ms_env_id_value=1.${MARKSHARC_OS}.${MARKSHARC_ARCH}.${EUID}.$hex
}
