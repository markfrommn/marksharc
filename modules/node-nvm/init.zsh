# node-nvm module, init phase: nvm loads on first use, and node switches on directory changes
# from the nearest .nvmrc. The env phase already put the default node on PATH, so node, npm
# and the rest work without nvm.sh, which is slow to source; it is sourced (with --no-use, so
# it leaves PATH alone) the first time nvm runs or an .nvmrc needs it.
autoload -Uz add-zsh-hook
typeset -g HAVE_NVM=
if [[ -s $NVM_DIR/nvm.sh ]]; then
    HAVE_NVM=1
    # A reload keeps an nvm that is already loaded, and the first-use stub otherwise.
    if (( ! ${+functions[nvm]} )); then
        nvm() { _ms_nvm_load || return $?; nvm "$@"; }
    fi
fi

if [[ -n $HAVE_NVM ]]; then
    # _ms_nvm_load: source nvm.sh once per shell, replacing the first-use stub.
    _ms_nvm_load() {
        [[ -n ${_ms_nvm_loaded-} ]] && return 0
        unfunction nvm 2>/dev/null
        if ! source "$NVM_DIR/nvm.sh" --no-use || (( ! ${+functions[nvm]} )); then
            print -ru2 -- "nvm: could not load $NVM_DIR/nvm.sh"
            nvm() { _ms_nvm_load || return $?; nvm "$@"; }
            return 1
        fi
        [[ ! -s $NVM_DIR/bash_completion ]] || source "$NVM_DIR/bash_completion"
        typeset -g _ms_nvm_loaded=1
    }
    load-nvmrc() {
        local -a previous_path=( "${path[@]}" )
        local node_version nvmrc_path= nvmrc_node_version dir=$PWD result=0
        while :; do
            if [[ -f $dir/.nvmrc ]]; then nvmrc_path=$dir/.nvmrc; break; fi
            [[ -z $dir || $dir == / ]] && break
            dir=${dir:h}
        done
        # No .nvmrc and nvm never loaded: node is still the env phase's choice.
        [[ -n $nvmrc_path || -n ${_ms_nvm_loaded-} ]] || return 0
        _ms_nvm_load || return 1
        node_version=$(nvm version) || return 1
        if [[ -n $nvmrc_path ]]; then
            nvmrc_node_version=$(nvm version "$(<"$nvmrc_path")")
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
