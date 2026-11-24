# python module, env phase: when pyenv is installed and uv is not, the pyenv shims and
# bin directories go into the manager tier. uv needs nothing.
if (( ${_ms_env_rebuild:-1} )); then
    if (( ${+functions[_ms_mise_owns]} )) && _ms_mise_owns python; then
        unset PYENV_ROOT
    elif (( ${+functions[_ms_path_add]} )) && [[ -f $HOME/.pyenv/bin/pyenv ]] && ! _ms_command_available uv; then
        export PYENV_ROOT=$HOME/.pyenv
        _ms_path_add manager "$PYENV_ROOT/shims" "$PYENV_ROOT/bin"
    fi
fi
true
