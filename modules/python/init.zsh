# python module, init phase: uv is preferred; without it, pyenv's cached init output.
if (( ${+functions[_ms_mise_owns]} )) && _ms_mise_owns python; then
    return 0
fi
if have_command uv; then
    _ms_trace "uv found, preferring it to pyenv"
elif [[ -f $HOME/.pyenv/bin/pyenv ]]; then
    export PYENV_ROOT=$HOME/.pyenv
    typeset -gU path
    path+=( "$PYENV_ROOT/bin" )
    _ms_init_cached -k "$PYENV_ROOT" pyenv pyenv init --path || true
    if have_command pyenv || fn_exists pyenv; then
        _ms_init_cached -k "$PYENV_ROOT" pyenv pyenv init - || true
        # pyenv-virtualenv may be a plugin or a system package: ask pyenv.
        if [[ $(pyenv commands 2>/dev/null) == *virtualenv-init* ]]; then
            _ms_init_cached -k "$PYENV_ROOT" pyenv pyenv virtualenv-init - || true
        fi
    fi
fi
true
