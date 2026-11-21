# go-gvm module, env phase. Every session class gets gvm's Go from builtins only (no
# sourcing, no forks, no output, never --default): the Go named by gvm's default
# environment, else the numerically newest installed Go. The directories go into the
# manager tier, ahead of Homebrew. A finalizer then makes GOROOT agree with the first
# go on the final PATH.

# _ms_gvm_select: REPLY = the gvm Go name to use, empty when none is installed.
_ms_gvm_select() {
    emulate -L zsh
    setopt numericglobsort
    local root=${GVM_ROOT:-$HOME/.gvm} name= line dir
    local -a dirs
    REPLY=
    [[ -d $root/gos ]] || return 1
    if [[ -r $root/environments/default ]]; then
        while IFS= read -r line; do
            if [[ $line == *gvm_go_name=* ]]; then
                name=${line##*gvm_go_name=}
                name=${name//[\"\' ]/}
                break
            fi
        done < "$root/environments/default"
    fi
    if [[ -z $name || ! -x $root/gos/$name/bin/go ]]; then
        name=
        dirs=( $root/gos/go*(N/on) )
        for dir in ${(Oa)dirs}; do
            [[ -x $dir/bin/go ]] && { name=${dir:t}; break; }
        done
    fi
    [[ -n $name && -x $root/gos/$name/bin/go ]] || return 1
    REPLY=$name
}

# _ms_gvm_first: REPLY = the gvm Go name of the first go on PATH, empty when that go is
# not a gvm Go or there is none.
_ms_gvm_first() {
    emulate -L zsh
    local root=${GVM_ROOT:-$HOME/.gvm} dir first=
    REPLY=
    for dir in "${path[@]}"; do
        if [[ -x $dir/go && ! -d $dir/go ]]; then first=$dir/go; break; fi
    done
    [[ -n $first && ${first:h:h:h} == $root/gos ]] && REPLY=${first:h:h:t}
    return 0
}

# GOROOT names the Go that is first on PATH. A gvm Go sets it to its own directory; for
# any other Go an inherited GOROOT that points elsewhere is removed so the go binary
# finds its own root. With no go on PATH nothing changes. The init phase calls this
# again after gvm has been sourced (gvm's default environment resets GOROOT).
_ms_gvm_sync_goroot() {
    emulate -L zsh
    local root=${GVM_ROOT:-$HOME/.gvm} dir first= want
    for dir in "${path[@]}"; do
        if [[ -x $dir/go && ! -d $dir/go ]]; then first=$dir/go; break; fi
    done
    [[ -n $first ]] || return 0
    if [[ ${first:h:h:h} == $root/gos ]]; then
        export GOROOT=${first:h:h}
    elif [[ -n ${GOROOT-} ]]; then
        want=$GOROOT/bin/go
        [[ ${first:A} == ${want:A} ]] || unset GOROOT
    fi
    return 0
}

# Env finalizer: only a rebuild changes anything (a child inherits a consistent GOROOT).
_ms_gvm_finalize() {
    (( ${_ms_env_rebuild:-1} )) || return 0
    _ms_gvm_sync_goroot
}

if (( ${_ms_env_rebuild:-1} )); then
    if (( ${+functions[_ms_path_add]} )) && _ms_gvm_select; then
        typeset _ms_gvm_root=${GVM_ROOT:-$HOME/.gvm} _ms_gvm_name=$REPLY
        if [[ $MARKSHARC_SESSION == interactive ]]; then
            # An interactive gvm activation sets GOPATH to the pkgset, so go install writes to
            # its global/bin, which gvm puts on PATH before it exists: add it unchecked, with
            # gvm's overlay and own bin directories.
            _ms_path_add -f manager "$_ms_gvm_root/pkgsets/$_ms_gvm_name/global/bin"
            _ms_path_add manager "$_ms_gvm_root/gos/$_ms_gvm_name/bin"
            _ms_path_add -f manager "$_ms_gvm_root/pkgsets/$_ms_gvm_name/global/overlay/bin"
            _ms_path_add manager "$_ms_gvm_root/bin"
        else
            # Agent and batch shells keep GOPATH at its default, so only existing directories.
            _ms_path_add manager "$_ms_gvm_root/pkgsets/$_ms_gvm_name/global/bin" "$_ms_gvm_root/gos/$_ms_gvm_name/bin"
        fi
        unset _ms_gvm_root _ms_gvm_name
    fi
    (( ${_ms_env_finalizers[(Ie)_ms_gvm_finalize]} )) || _ms_env_finalizers+=( _ms_gvm_finalize )
fi
true
