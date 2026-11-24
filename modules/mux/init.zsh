# tmux updates its session environment on attach. A running shell imports it before
# reading another command, including when it was already sitting at a prompt on attach.
if [[ -n $TMUX && -n $TMUX_PANE ]]; then
    _ms_mux_refresh_client() {
        refresh-env auto 2>/dev/null || true
    }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _ms_mux_refresh_client
    add-zsh-hook preexec _ms_mux_refresh_client
    _ms_mux_cleanup() {
        add-zsh-hook -d precmd _ms_mux_refresh_client
        add-zsh-hook -d preexec _ms_mux_refresh_client
    }
    typeset -gaU _ms_init_cleanups
    _ms_init_cleanups+=( _ms_mux_cleanup )
    _ms_mux_refresh_client
fi
