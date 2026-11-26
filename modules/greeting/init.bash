[[ ${_ms_bash_reloading-} != 1 ]] || return 0
case ${_ms_opt_greeting_fortune-off} in
    on|1|yes|true) command fortune ;;
esac
