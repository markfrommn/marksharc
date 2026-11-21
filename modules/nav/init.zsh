# nav module, init phase: directory-stack options and native Alt-arrow directory
# history and directory-stack navigation (replaces the OMZ dirhistory and dircycle).

setopt pushdtohome cdablevars autocd pushdsilent pushdminus
unsetopt autoparamslash

typeset -ga dirhistory_past dirhistory_future
(( ${+dirhistory_past} )) || dirhistory_past=("$PWD")
(( ${+dirhistory_future} )) || dirhistory_future=()

_dirhistory_push_past() {
    emulate -L zsh
    if (( $#dirhistory_past == 0 )) || [[ $dirhistory_past[-1] != "$1" ]]; then
        dirhistory_past+=("$1")
    fi
    integer limit=${DIRHISTORY_SIZE:-50}
    (( limit > 0 )) || limit=1
    while (( $#dirhistory_past > limit )); do
        shift dirhistory_past
    done
}

_dirhistory_push_future() {
    emulate -L zsh
    if (( $#dirhistory_future == 0 )) || [[ $dirhistory_future[-1] != "$1" ]]; then
        dirhistory_future+=("$1")
    fi
    integer limit=${DIRHISTORY_SIZE:-50}
    (( limit > 0 )) || limit=1
    while (( $#dirhistory_future > limit )); do
        shift dirhistory_future
    done
}

_dirhistory_pop_past() {
    emulate -L zsh
    (( $#dirhistory_past > 0 )) || return 1
    typeset -g "$1=${dirhistory_past[-1]}"
    dirhistory_past[-1]=()
}

_dirhistory_pop_future() {
    emulate -L zsh
    (( $#dirhistory_future > 0 )) || return 1
    typeset -g "$1=${dirhistory_future[-1]}"
    dirhistory_future[-1]=()
}

chpwd_dirhistory() {
    emulate -L zsh
    _dirhistory_push_past "$PWD"
    if [[ -z ${DIRHISTORY_CD+x} ]]; then
        dirhistory_future=()
    fi
}

dirhistory_cd() {
    emulate -L zsh
    local DIRHISTORY_CD=1
    builtin cd -- "$1"
}

dirhistory_back() {
    emulate -L zsh
    local current='' target=''
    _dirhistory_pop_past current
    if [[ -z $current ]]; then
        dirhistory_past=("$PWD")
        return 0
    fi
    _dirhistory_pop_past target
    if [[ -n $target ]]; then
        dirhistory_cd "$target" || return 1
        _dirhistory_push_future "$current"
    else
        _dirhistory_push_past "$current"
    fi
}

dirhistory_forward() {
    emulate -L zsh
    local target=''
    _dirhistory_pop_future target
    if [[ -n $target ]]; then
        dirhistory_cd "$target" || return 1
        _dirhistory_push_past "$target"
    fi
}

_dirhistory_first_child() {
    emulate -L zsh
    setopt null_glob glob_dots
    local -a children=( *(N-/) )
    (( $#children > 0 )) || return 1
    children=( "${(@o)children}" )
    REPLY=$children[1]
}

dirhistory_up() {
    emulate -L zsh
    builtin cd -- .. || return 1
}

dirhistory_down() {
    emulate -L zsh
    local REPLY
    _dirhistory_first_child || return 1
    builtin cd -- "$REPLY"
}

autoload -Uz add-zsh-hook
add-zsh-hook chpwd chpwd_dirhistory

dirhistory_zle_dirhistory_back() {
    zle .kill-buffer
    dirhistory_back
    zle .accept-line
}

dirhistory_zle_dirhistory_future() {
    zle .kill-buffer
    dirhistory_forward
    zle .accept-line
}

dirhistory_zle_dirhistory_up() {
    zle .kill-buffer
    dirhistory_up
    zle .accept-line
}

dirhistory_zle_dirhistory_down() {
    zle .kill-buffer
    dirhistory_down
    zle .accept-line
}

zle -N dirhistory_zle_dirhistory_back
zle -N dirhistory_zle_dirhistory_future
zle -N dirhistory_zle_dirhistory_up
zle -N dirhistory_zle_dirhistory_down

switch-to-dir() {
    emulate -L zsh
    if [[ $1 == -- ]]; then
        [[ -d $2 ]] && builtin pushd -q -- "$2" &>/dev/null
        return $?
    fi
    setopt nopushdminus
    (( ${#dirstack} > 0 )) || return 1
    while ! builtin pushd -q "$1" &>/dev/null; do
        builtin popd -q "$1"
        (( ${#dirstack} > 0 )) || return 1
    done
}

_dirhistory_cycle_prompt() {
    emulate -L zsh
    local fn
    for fn in chpwd $chpwd_functions precmd $precmd_functions; do
        (( $+functions[$fn] )) && "$fn"
    done
    zle reset-prompt
}

insert-cycledleft() {
    switch-to-dir +1 || return $?
    _dirhistory_cycle_prompt
}
zle -N insert-cycledleft

insert-cycledright() {
    switch-to-dir -0 || return $?
    _dirhistory_cycle_prompt
}
zle -N insert-cycledright

insert-cycledup() {
    switch-to-dir -- .. || return $?
    _dirhistory_cycle_prompt
}
zle -N insert-cycledup

insert-cycleddown() {
    local REPLY
    _dirhistory_first_child || return 1
    switch-to-dir -- "$REPLY" || return $?
    _dirhistory_cycle_prompt
}
zle -N insert-cycleddown

zmodload zsh/terminfo 2>/dev/null || true
typeset _dirhistory_keymap _dirhistory_sequence
for _dirhistory_keymap in emacs vicmd viins; do
    for _dirhistory_sequence in '\e[3D' '\e[1;3D' '\e\e[D' '\eO3D'; do
        bindkey -M "$_dirhistory_keymap" "$_dirhistory_sequence" dirhistory_zle_dirhistory_back
    done
    for _dirhistory_sequence in '\e[3C' '\e[1;3C' '\e\e[C' '\eO3C'; do
        bindkey -M "$_dirhistory_keymap" "$_dirhistory_sequence" dirhistory_zle_dirhistory_future
    done
    for _dirhistory_sequence in '\e[3A' '\e[1;3A' '\e\e[A' '\eO3A'; do
        bindkey -M "$_dirhistory_keymap" "$_dirhistory_sequence" dirhistory_zle_dirhistory_up
    done
    for _dirhistory_sequence in '\e[3B' '\e[1;3B' '\e\e[B' '\eO3B'; do
        bindkey -M "$_dirhistory_keymap" "$_dirhistory_sequence" dirhistory_zle_dirhistory_down
    done

    case ${TERM_PROGRAM:-} in
        Apple_Terminal)
            bindkey -M "$_dirhistory_keymap" '^[b' dirhistory_zle_dirhistory_back
            bindkey -M "$_dirhistory_keymap" '^[f' dirhistory_zle_dirhistory_future
            bindkey -M "$_dirhistory_keymap" '^[[A' dirhistory_zle_dirhistory_up
            bindkey -M "$_dirhistory_keymap" '^[[B' dirhistory_zle_dirhistory_down
            ;;
        ghostty)
            bindkey -M "$_dirhistory_keymap" '^[b' dirhistory_zle_dirhistory_back
            bindkey -M "$_dirhistory_keymap" '^[f' dirhistory_zle_dirhistory_future
            bindkey -M "$_dirhistory_keymap" '^[[1;3A' dirhistory_zle_dirhistory_up
            bindkey -M "$_dirhistory_keymap" '^[[1;3B' dirhistory_zle_dirhistory_down
            ;;
        iTerm.app)
            bindkey -M "$_dirhistory_keymap" '^[^[[D' dirhistory_zle_dirhistory_back
            bindkey -M "$_dirhistory_keymap" '^[b' dirhistory_zle_dirhistory_back
            bindkey -M "$_dirhistory_keymap" '^[^[[C' dirhistory_zle_dirhistory_future
            bindkey -M "$_dirhistory_keymap" '^[f' dirhistory_zle_dirhistory_future
            bindkey -M "$_dirhistory_keymap" '^[^[[A' dirhistory_zle_dirhistory_up
            bindkey -M "$_dirhistory_keymap" '^[^[[B' dirhistory_zle_dirhistory_down
            ;;
    esac

    [[ -n ${terminfo[kcub1]:-} ]] && bindkey -M "$_dirhistory_keymap" "^[${terminfo[kcub1]}" dirhistory_zle_dirhistory_back
    [[ -n ${terminfo[kcuf1]:-} ]] && bindkey -M "$_dirhistory_keymap" "^[${terminfo[kcuf1]}" dirhistory_zle_dirhistory_future
    [[ -n ${terminfo[kcuu1]:-} ]] && bindkey -M "$_dirhistory_keymap" "^[${terminfo[kcuu1]}" dirhistory_zle_dirhistory_up
    [[ -n ${terminfo[kcud1]:-} ]] && bindkey -M "$_dirhistory_keymap" "^[${terminfo[kcud1]}" dirhistory_zle_dirhistory_down

    bindkey -M "$_dirhistory_keymap" '\e[1;6D' insert-cycledleft
    bindkey -M "$_dirhistory_keymap" '\e[1;6C' insert-cycledright
    bindkey -M "$_dirhistory_keymap" '\e[1;6A' insert-cycledup
    bindkey -M "$_dirhistory_keymap" '\e[1;6B' insert-cycleddown
done
unset _dirhistory_keymap _dirhistory_sequence
