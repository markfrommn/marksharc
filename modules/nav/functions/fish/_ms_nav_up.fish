# Alt-Up: on an empty command line change to the parent directory and repaint the prompt;
# otherwise keep fish's default action for the key.
function _ms_nav_up
    if test -n "$(commandline)"; or commandline --paging-mode
        commandline -f history-token-search-backward
        return 0
    end
    cd ..
    commandline -f repaint
end
