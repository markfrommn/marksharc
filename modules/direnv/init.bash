case ${_ms_opt_direnv_enable-off} in on|1|yes|true) ;; *) return 0 ;; esac

_ms_bash_direnv_init() {
    # Load the provider's implementation and keep its transport local.
    # shellcheck disable=SC2034
    local PROMPT_COMMAND='' BLE_VERSION=''
    # Older direnv versions assign vars without declaring it.
    _ms_bash_init_cached direnv direnv hook bash >/dev/null 2>&1 || return
    declare -F _direnv_hook >/dev/null && _ms_bash_register_prompt _ms_bash_direnv_prompt
}

_ms_bash_direnv_prompt() {
    # shellcheck disable=SC2034
    local vars
    _direnv_hook
}
_ms_bash_direnv_init
