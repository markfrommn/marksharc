# cwf-new: the write-once command, with its directives (exports, pushd) applied to this shell.
# Hook registries are fish lists; the executable reads them newline-joined, as from zsh.
function cwf-new --description 'Create a cwf session worktree and enter it'
    set -lx MARKSHARC_CWF_NEW_HOOKS (string join \n -- $cwf_new_post_create_hooks | string collect)
    set -lx MARKSHARC_CWF_NEW_COPY_EXCLUDE (string join \n -- $cwf_new_copy_exclude | string collect)
    _ms_fish_run_with_directives cwf-new $argv
end
