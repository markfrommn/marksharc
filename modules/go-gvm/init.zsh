# go-gvm module, init phase (interactive only): the gvm function, activated once per
# shell for the Go that is first on PATH (the env phase's selection, or a parent shell's
# explicit gvm use), then GOROOT synced to it, and the go.mod hook. The default
# environment is never rewritten (no --default), startup prints nothing. Sourcing gvm
# prepends to PATH, so the manager tier's order is restored afterwards.
autoload -Uz add-zsh-hook
if [[ -f ${GVM_ROOT:-$HOME/.gvm}/scripts/gvm ]] && (( ! ${+functions[gvm]} )); then
    typeset -ga _ms_gvm_saved=( "${path[@]}" )
    # The first gvm Go on PATH now is a parent shell's explicit gvm use (sourcing gvm below
    # prepends its default environment, so look before it).
    _ms_gvm_first
    typeset -g _ms_gvm_want=$REPLY
    unset GVM_VERSION
    source "${GVM_ROOT:-$HOME/.gvm}/scripts/gvm" >/dev/null 2>&1
    if (( ${+functions[gvm]} )); then
        # Sourcing gvm activated its default environment (GOROOT and GOPATH reset to it).
        # The Go to honour is the first gvm Go that was on PATH, else the env phase's selection.
        if [[ -z $_ms_gvm_want ]] && _ms_gvm_select; then _ms_gvm_want=$REPLY; fi
        if [[ -n $_ms_gvm_want && ${gvm_go_name-} != $_ms_gvm_want ]]; then
            gvm use "$_ms_gvm_want" >/dev/null 2>&1
        fi
    fi
    unset _ms_gvm_want
    path=( "${_ms_gvm_saved[@]}" )
    unset _ms_gvm_saved
    _ms_gvm_sync_goroot
fi

if [[ -n ${GVM_VERSION-} ]]; then
    # Switch Go on directory change from go.mod.
    _gvm_auto_use() {
        if [[ -f go.mod ]]; then
            local go_ver=$(grep -E '^go [0-9]+\.[0-9]+' go.mod | awk '{print "go"$2}')
            if [[ -n $go_ver ]]; then
                local current_ver=$(gvm list | grep '=>' | awk '{print $2}')
                if [[ $current_ver != "$go_ver" ]]; then
                    gvm use "$go_ver" > /dev/null 2>&1 || echo "GVM: $go_ver is not installed."
                fi
            fi
        fi
    }
    add-zsh-hook chpwd _gvm_auto_use
    _gvm_auto_use
fi
true
