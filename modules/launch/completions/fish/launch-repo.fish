function __ms_launch_repo_names
    set -l host local
    set -l tokens (commandline -opc)
    set -l index (contains -i -- --host $tokens)
    if test -n "$index"
        set host $tokens[(math $index + 1)]
    end
    set -l current (commandline -ct)
    set -l prefix ''
    if string match -q '*:*' -- $current
        set host (string split -m 1 : -- $current)[1]
        set prefix "$host:"
    end
    contains -- $host '' local localhost $MARKSHARC_HOST; and set host local
    string match -qr '^[A-Za-z0-9._@:-]+$' -- $host; or return
    set -l cache "$XDG_CACHE_HOME"
    test -n "$cache"; or set cache "$HOME/.cache"
    set -l machine "$MARKSHARC_HOST"
    test -n "$machine"; or set machine (hostname -s)
    set -l file "$cache/marksharc/$machine/repos/$host.tsv"
    test -r "$file"; or return
    while read -l row
        set -l fields (string split \t -- $row)
        test (count $fields) -ge 4; or continue
        if test "$fields[3]" = base
            echo $prefix$fields[1]
        else if test "$fields[3]" = worktree
            if test "$tokens[-1]" = --worktree
                echo $fields[1]
                set -q fields[5]; and echo $fields[5]
            else
                echo $prefix(path basename -- $fields[4])/$fields[1]
            end
        end
    end <$file
end

complete -c launch-repo -f -a '(__ms_launch_repo_names)'
complete -c launch-repo -s h -l help -d 'Show usage'
complete -c launch-repo -l host -x -d 'Choose a host'
complete -c launch-repo -l repo -x -a '(__ms_launch_repo_names)' -d 'Choose a repository'
complete -c launch-repo -l worktree -x -a '(__ms_launch_repo_names)' -d 'Choose a worktree'
complete -c launch-repo -l command -x -a '(__fish_complete_command)' -d 'Choose a program'
complete -c launch-repo -l mux -x -a 'hc herdr tmux herdr-core' -d 'Choose a multiplexer'
complete -c launch-repo -l mux-id -x -d 'Choose an instance'
complete -c launch-repo -l place -x -a 'workspace tab hidden' -d 'Set placement'
complete -c launch-repo -l name -x -d 'Set a display name'
complete -c launch-repo -l env -x -d 'Set a session variable'
complete -c launch-repo -l rescan -d 'Refresh the inventory'
complete -c launch-repo -l in-shell -d 'Run after shell init'
complete -c launch-repo -l no-focus -d 'Keep focus'
complete -c launch-repo -l dry-run -d Preview
complete -c launch-repo -l quiet -d 'Suppress result'
