# Lists which of the given files git does not track. The list is printed in an interactive session only.
function git-unmanaged --description 'Which of the given files git does not manage'
    set -l selected
    git_managed_arr_core unmanaged selected $argv; or return
    test "$MARKSHARC_SESSION" = interactive; and echo "Git Un-Managed: $selected"
    return 0
end
