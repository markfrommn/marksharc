function fix-tmux {
    if [[ -n ${TMUX-} ]]; then
        refresh-env client
    else
        printf 'Not in tmux\n'
    fi
}
