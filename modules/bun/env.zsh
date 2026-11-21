# bun module: BUN_INSTALL and ~/.bun/bin in the user tier, in every session class.
if (( ${_ms_env_rebuild:-1} )) && [[ -d $HOME/.bun ]]; then
    export BUN_INSTALL=$HOME/.bun
    (( ${+functions[_ms_path_add]} )) && _ms_path_add user "$BUN_INSTALL/bin"
fi
true
