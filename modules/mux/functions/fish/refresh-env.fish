function refresh-env --description 'Refresh DISPLAY and SSH_AUTH_SOCK in this shell'
    _ms_fish_run_with_directives "$MARKSHARC_HOME/modules/mux/bin/marksharc-mux" refresh_env $argv
end
