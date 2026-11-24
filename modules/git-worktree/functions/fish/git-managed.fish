# Lists which of the given files git tracks. The list is printed in an interactive session only.
function git-managed --description 'Which of the given files git manages'
    set -l selected
    git_managed_arr_core managed selected $argv; or return
    test "$MARKSHARC_SESSION" = interactive; and echo "Git Managed: $selected"
    return 0
end
