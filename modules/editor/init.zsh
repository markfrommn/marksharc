# editor module, init phase: EDITOR. Interactive only, so an agent or batch shell never
# starts an editor that waits on a terminal.
if [[ -n ${_ms_opt_editor_command-} ]]; then
    export EDITOR=$_ms_opt_editor_command
elif have_command emacs; then
    export EDITOR='emacs -nw'
else
    export EDITOR=vi
fi
true
