if [[ -n ${_ms_opt_editor_command-} ]]; then
    _ms_bash_set_env EDITOR "$_ms_opt_editor_command"
elif type -P emacs >/dev/null; then
    _ms_bash_set_env EDITOR 'emacs -nw'
else
    _ms_bash_set_env EDITOR vi
fi
