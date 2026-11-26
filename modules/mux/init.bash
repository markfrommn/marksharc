if [[ -n ${TMUX-} && -n ${TMUX_PANE-} ]]; then
    _ms_mux_refresh_client() { refresh-env auto 2>/dev/null || :; }
    _ms_bash_register_prompt _ms_mux_refresh_client
    _ms_bash_register_preexec _ms_mux_refresh_client
    _ms_mux_refresh_client
fi
