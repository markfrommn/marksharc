# greeting module, init phase: fortune, once per shell (not on cs/li), opt-in with
# "set greeting.fortune on".
if [[ ${_ms_opt_greeting_fortune-off} == (on|1|yes|true) ]] && (( ! ${_ms_reloading:-0} )); then
    fortune
fi
true
