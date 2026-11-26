function refresh-env {
    _ms_bash_run_with_directives "$MARKSHARC_HOME/modules/mux/bin/marksharc-mux" refresh_env "${1:-all}"
}
