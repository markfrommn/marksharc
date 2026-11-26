_ms_mise_owns python && return 0
type -P uv >/dev/null && return 0
[[ -x ${PYENV_ROOT:-$HOME/.pyenv}/bin/pyenv ]] || return 0

_ms_bash_pyenv_init() {
    local root=${PYENV_ROOT:-$HOME/.pyenv} before=$PATH shell_before
    _ms_bash_set_env PYENV_ROOT "$root"
    shell_before=$(_ms_bash_effect variable PYENV_SHELL)
    _ms_bash_init_cached -k "$root" pyenv "$root/bin/pyenv" init - bash >/dev/null 2>&1 || :
    _ms_bash_record_effect variable PYENV_SHELL "$shell_before" "$(_ms_bash_effect variable PYENV_SHELL)"
    if [[ $(command "$root/bin/pyenv" commands 2>/dev/null) == *virtualenv-init* ]]; then
        # The optional plugin installs its own prompt callback.
        local PROMPT_COMMAND=''
        _ms_bash_init_cached -k "$root" pyenv-virtualenv "$root/bin/pyenv" virtualenv-init - bash >/dev/null 2>&1 || :
        if declare -F _pyenv_virtualenv_hook >/dev/null; then
            _ms_bash_register_prompt _ms_bash_pyenv_virtualenv
        fi
    fi
    # The env phase handles manager ordering. pyenv's init can prepend shims
    # again; keep the tiered PATH and any existing explicit activation.
    export PATH=$before
}

_ms_bash_pyenv_virtualenv() { _pyenv_virtualenv_hook; }
_ms_bash_pyenv_init
