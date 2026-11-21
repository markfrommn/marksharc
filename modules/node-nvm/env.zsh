# node-nvm module, env phase. nvm.sh is slow and only an interactive shell needs the nvm
# function, so every session class gets the default node's bin directory in the
# manager tier (ahead of Homebrew) from the files nvm itself keeps: no sourcing, no forks.

# _ms_nvm_default: REPLY = bin directory of the default node version, from
# $NVM_DIR/alias/default (a version, a partial version, node/stable, or another alias
# such as lts/* followed through the alias files) and $NVM_DIR/versions/node.
_ms_nvm_default() {
    emulate -L zsh
    setopt numericglobsort
    local dir=${NVM_DIR:-$HOME/.nvm} name pat hops=0
    local -a vers
    REPLY=
    [[ -r $dir/alias/default ]] || return 1
    IFS= read -r name < "$dir/alias/default" 2>/dev/null
    while (( hops++ < 6 )); do
        name=${name//[[:space:]]/}
        [[ -n $name ]] || return 1
        if [[ $name != (v|)<->* && $name != (node|stable|system) && -r $dir/alias/$name ]]; then
            IFS= read -r name < "$dir/alias/$name" 2>/dev/null
            continue
        fi
        break
    done
    case $name in
        node|stable) pat='v*' ;;
        v<->*) pat="($name|$name.*)" ;;
        <->*) pat="(v$name|v$name.*)" ;;
        *) return 1 ;;
    esac
    vers=( $dir/versions/node/${~pat}(N/on) )
    (( $#vers )) || return 1
    [[ -d $vers[-1]/bin ]] || return 1
    REPLY=$vers[-1]/bin
}

if (( ${_ms_env_rebuild:-1} )); then
    export NVM_DIR=${NVM_DIR:-$HOME/.nvm}
    if (( ${+functions[_ms_path_add]} )) && _ms_nvm_default; then
        _ms_path_add manager "$REPLY"
    fi
fi
true
