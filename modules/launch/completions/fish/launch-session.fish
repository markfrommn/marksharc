function __ms_launch_session_hosts
    printf '%s\n' local localhost remote $MARKSHARC_HOST
    set -l entries ("$MARKSHARC_HOME/bin/marksharc" hosts list 2>/dev/null)
    if set -q entries[1]
        string split -f 1 \t -- $entries | string match -rv ' '
    end
end

function __ms_launch_session_positional
    set -l tokens (commandline -pxc)
    contains -- -- $tokens; and return 1
    argparse --stop-nonopt host= pwd= command= mux= mux-id= place= name= env= \
        in-shell no-focus dry-run quiet h/help -- $tokens[2..] 2>/dev/null; or return 1
    for name in _flag_host _flag_pwd _flag_command 'argv[1]'
        set -q $name; and return 1
    end
    return 0
end

function __ms_launch_session_targets
    __ms_launch_session_hosts | string match -rv ':' | string replace -r '$' ':'
    __fish_complete_directories
end

complete -c launch-session -n __ms_launch_session_positional -f -a '(__ms_launch_session_targets)'
complete -c launch-session -l help -s h -d 'Show usage'
complete -c launch-session -l host -x -a '(__ms_launch_session_hosts)' -d 'Choose a host'
complete -c launch-session -l pwd -x -a '(__fish_complete_directories)' -d 'Set the starting directory'
complete -c launch-session -l command -x -a '(__fish_complete_command)' -d 'Choose a program'
complete -c launch-session -l mux -x -a 'hc herdr tmux herdr-core' -d 'Choose a multiplexer'
complete -c launch-session -l mux-id -x -d 'Choose a multiplexer instance'
complete -c launch-session -l place -x -a 'workspace tab hidden' -d 'Set terminal placement'
complete -c launch-session -l name -x -d 'Set a display name'
complete -c launch-session -l env -x -d 'Set a session variable'
complete -c launch-session -l in-shell -d 'Run after interactive startup'
complete -c launch-session -l no-focus -d 'Keep the current view'
complete -c launch-session -l dry-run -d 'Preview multiplexer commands'
complete -c launch-session -l quiet -d 'Suppress the result line'
