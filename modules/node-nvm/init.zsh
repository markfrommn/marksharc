# node-nvm module, init phase: load nvm.sh once per shell and switch node on directory
# changes from the nearest .nvmrc. Keep this after nvm has loaded.
autoload -Uz add-zsh-hook
typeset -g HAVE_NVM=
if [[ -s $NVM_DIR/nvm.sh ]]; then
    # nvm.sh is slow; a reload keeps the already-loaded nvm function.
    if (( ${+functions[nvm]} )); then
        HAVE_NVM=1
    elif source "$NVM_DIR/nvm.sh"; then
        [[ ! -s $NVM_DIR/bash_completion ]] || source "$NVM_DIR/bash_completion"
        HAVE_NVM=1
    fi
fi

if [[ -n $HAVE_NVM ]]; then
    load-nvmrc() {
        local -a previous_path=( "${path[@]}" )
        local node_version nvmrc_path nvmrc_node_version result=0
        node_version=$(nvm version) || return 1
        nvmrc_path=$(nvm_find_nvmrc)
        if [[ -n $nvmrc_path ]]; then
            nvmrc_node_version=$(nvm version "$(cat -- "$nvmrc_path")")
            if [[ $nvmrc_node_version == N/A ]]; then
                nvm install; result=$?
            elif [[ $nvmrc_node_version != $node_version ]]; then
                nvm use; result=$?
            fi
        elif [[ $node_version != "$(nvm version default)" ]]; then
            nvm use default; result=$?
        fi
        if (( result != 0 )); then path=( "${previous_path[@]}" ); fi
        return $result
    }
    add-zsh-hook chpwd load-nvmrc
    load-nvmrc
else
    _ms_trace "removing the chpwd nvmrc hook"
    add-zsh-hook -d chpwd load-nvmrc
fi
true
