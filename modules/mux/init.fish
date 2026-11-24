if test -n "$TMUX"; and test -n "$TMUX_PANE"
    function _ms_mux_refresh_client --on-event fish_prompt --on-event fish_preexec
        refresh-env auto 2>/dev/null; or true
    end
    _ms_mux_refresh_client
end
true
