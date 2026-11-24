function fix-tmux --description 'Re-import forwarding variables from the tmux client'
    if test -n "$TMUX"
        refresh-env client
    else
        echo 'Not in tmux'
    end
end
