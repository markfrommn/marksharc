# brew module, env phase: Homebrew's directories go into the brew tier (macOS) or the
# configured tier (Linuxbrew, default local: today's order puts it after the system
# directories on Linux). Nothing is forked; brew shellenv is applied in init.zsh.
(( ${+functions[_ms_path_add]} )) || return 0
(( ${_ms_env_rebuild:-1} )) || return 0
_ms_path_add brew /opt/homebrew/bin /opt/homebrew/sbin
_ms_path_add ${_ms_opt_brew_linuxbrew_tier:-local} /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin
true
