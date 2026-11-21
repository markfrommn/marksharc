# direnv module, init phase: the cached hook, only when the enable option is on.
if [[ ${_ms_opt_direnv_enable-off} == (on|1|yes|true) ]] && (( ! ${_ms_reloading:-0} )); then
    _ms_init_cached direnv direnv hook zsh || true
fi
true
