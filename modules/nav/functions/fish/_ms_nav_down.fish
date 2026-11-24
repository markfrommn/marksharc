# Alt-Down: on an empty command line change to the first child directory and repaint the
# prompt; otherwise keep fish's default action for the key.
function _ms_nav_down
    if test -n "$(commandline)"; or commandline --paging-mode
        commandline -f history-token-search-forward
        return 0
    end
    set -l child (_ms_nav_first_child | string collect -N)
    if test -n "$child"
        # ./ keeps a name that starts with a dash from being read as an option.
        cd "./$child"
    end
    commandline -f repaint
end
