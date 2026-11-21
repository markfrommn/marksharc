# zoxide module, init phase: cached init, once per shell.
(( ${_ms_reloading:-0} )) || _ms_init_cached zoxide zoxide init zsh || true
true
