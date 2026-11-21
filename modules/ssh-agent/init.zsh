# Once per shell (not on reload); runs late because ssh-add may prompt for a passphrase.
(( ${_ms_reloading:-0} )) || setup-ssh-agent || true
