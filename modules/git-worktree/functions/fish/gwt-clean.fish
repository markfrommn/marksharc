# gwt-clean: the write-once command, with its directives applied to this shell.
# Pre-remove hooks are a fish list; the executable reads them newline-joined, as from zsh.
function gwt-clean --description 'Remove a merged git worktree and return to its base'
    set -lx MARKSHARC_GWT_CLEAN_HOOKS (string join \n -- $gwt_clean_pre_remove_hooks | string collect)
    _ms_fish_run_with_directives gwt-clean $argv
end
