# editor module, init phase: EDITOR. Interactive only, so an agent or batch shell never
# starts an editor that waits on a terminal.
if set -q _ms_opt_editor_command; and test -n "$_ms_opt_editor_command"
    set -gx EDITOR "$_ms_opt_editor_command"
else if _ms_fish_command_available emacs
    set -gx EDITOR 'emacs -nw'
else
    set -gx EDITOR vi
end
return 0
