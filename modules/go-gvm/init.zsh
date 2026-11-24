# go-gvm module, init phase (interactive only). gvm loads on first use: sourcing it takes about
# a second and replaces cd with a slow wrapper. Startup only names the Go that is first on PATH
# (the env phase's selection, or a parent shell's explicit gvm use) in the variables gvm use
# would set, and syncs GOROOT to it. The default environment is never rewritten (no
# --default), and startup prints nothing. The go.mod hook loads gvm only to switch versions.
autoload -Uz add-zsh-hook
if (( ${+functions[_ms_mise_owns]} )) && _ms_mise_owns go; then
    add-zsh-hook -d chpwd _gvm_auto_use
    return 0
fi
if [[ -f ${GVM_ROOT:-$HOME/.gvm}/scripts/gvm ]]; then
    if (( ! ${+functions[gvm]} )); then
        # The first gvm Go on PATH is a parent shell's explicit gvm use; else the selection.
        _ms_gvm_first
        typeset -g _ms_gvm_want=$REPLY
        if [[ -z $_ms_gvm_want ]] && _ms_gvm_select; then _ms_gvm_want=$REPLY; fi
        if [[ -n $_ms_gvm_want ]]; then
            export GVM_ROOT=${GVM_ROOT:-$HOME/.gvm}
            # An inherited activation of the same Go keeps its pkgset.
            if [[ ${gvm_go_name-} != $_ms_gvm_want || -z ${GOPATH-} ]]; then
                export gvm_go_name=$_ms_gvm_want gvm_pkgset_name=global
                export GOPATH=$GVM_ROOT/pkgsets/$_ms_gvm_want/global
                export GVM_OVERLAY_PREFIX=$GOPATH/overlay
            fi
        fi
        unset _ms_gvm_want
        _ms_gvm_sync_goroot
        gvm() { _ms_gvm_load || return $?; gvm "$@"; }
        typeset -g _ms_gvm_first_use_stub=1
    fi

    # _ms_gvm_load: source gvm once per shell, replacing the first-use stub. Sourcing activates
    # gvm's default environment and runs cd ., so the Go in use, OLDPWD and the directory
    # stack are restored afterwards, and the chpwd hooks stand aside meanwhile (even when the
    # load is interrupted).
    _ms_gvm_load() {
        [[ -n ${_ms_gvm_loaded-} ]] && return 0
        local want=${gvm_go_name-} result=0 saved_oldpwd=$OLDPWD
        local -a saved=( "${path[@]}" ) saved_dirs=( "${dirstack[@]}" )
        unfunction gvm 2>/dev/null
        unset _ms_gvm_first_use_stub
        unset GVM_VERSION
        {
            typeset -g _ms_gvm_loading=1
            typeset -gx chdir_set_title_skip=yes
            source "${GVM_ROOT:-$HOME/.gvm}/scripts/gvm" >/dev/null 2>&1
        } always {
            unset _ms_gvm_loading chdir_set_title_skip
            OLDPWD=$saved_oldpwd
            dirstack=( "${saved_dirs[@]}" )
        }
        if (( ${+functions[gvm]} )); then
            typeset -g _ms_gvm_loaded=1
            if [[ -n $want && ${gvm_go_name-} != $want ]]; then
                gvm use "$want" >/dev/null 2>&1
            fi
            path=( "${saved[@]}" )
            _ms_gvm_sync_goroot
        else
            print -ru2 -- "gvm: could not load ${GVM_ROOT:-$HOME/.gvm}/scripts/gvm"
            path=( "${saved[@]}" )
            gvm() { _ms_gvm_load || return $?; gvm "$@"; }
            typeset -g _ms_gvm_first_use_stub=1
            result=1
        fi
        return $result
    }

    # Switch Go on directory change from go.mod.
    _gvm_auto_use() {
        [[ -f go.mod && -z ${_ms_gvm_loading-} ]] || return 0
        local line go_ver=
        while IFS= read -r line; do
            if [[ $line =~ '^go [0-9]+\.[0-9]+' ]]; then
                go_ver=go${${=line}[2]}
                break
            fi
        done < go.mod
        if [[ -n $go_ver && $go_ver != ${gvm_go_name-} ]]; then
            gvm use "$go_ver" > /dev/null 2>&1 || echo "GVM: $go_ver is not installed."
        fi
    }
    add-zsh-hook chpwd _gvm_auto_use
    _gvm_auto_use
fi
true
