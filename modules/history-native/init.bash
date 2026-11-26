# A usable Atuin integration owns persistence. Otherwise use a Bash-specific file.
case ${_ms_bash_history_backend-} in atuin-ble|atuin-bash-preexec) return 0 ;; esac

_ms_bash_native_history() {
    local history_dir=${XDG_STATE_HOME:-$HOME/.local/state}/marksharc
    command mkdir -p -- "$history_dir" 2>/dev/null || return
    _ms_bash_set_option HISTFILE "$history_dir/history.bash" || return
    _ms_bash_set_option HISTSIZE 10000
    _ms_bash_set_option HISTFILESIZE 10000
    if ! shopt -q histappend; then
        shopt -s histappend
        _ms_bash_register_cleanup _ms_bash_native_history_cleanup
    fi
}

_ms_bash_native_history_cleanup() { shopt -u histappend; }

function h { builtin history 35; }
_ms_bash_native_history
