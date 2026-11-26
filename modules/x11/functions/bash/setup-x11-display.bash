function setup-x11-display {
    local _ms_mode=display
    [[ ${1-} != --startup ]] || _ms_mode=display-startup
    _ms_bash_run_with_directives "$MARKSHARC_HOME/modules/mux/bin/marksharc-mux" refresh_env "$_ms_mode"
}
