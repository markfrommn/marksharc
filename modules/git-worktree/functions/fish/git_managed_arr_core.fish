# Private helper: git_managed_arr_core managed|unmanaged <variable> <files...>
# Stores the files git tracks (managed) or does not track (unmanaged) in <variable>, a variable
# that already exists in the caller's scope. Pathspecs are literal, so spaces, globs and leading
# dashes in names are file names. Returns git's status when it fails for any reason other than
# "not tracked" (for example outside a repository).
function git_managed_arr_core --no-scope-shadowing --description 'Select tracked or untracked files'
    set -l _ms_gm_mode "$argv[1]"
    set -l _ms_gm_dest "$argv[2]"
    string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- "$_ms_gm_dest"; or return 1
    contains -- "$_ms_gm_mode" managed unmanaged; or return 1
    set -l _ms_gm_selected
    for _ms_gm_file in $argv[3..]
        command git --literal-pathspecs ls-files --error-unmatch -- "$_ms_gm_file" >/dev/null 2>&1
        set -l _ms_gm_result $status
        if begin
                test "$_ms_gm_mode" = managed; and test $_ms_gm_result -eq 0
            end
            or begin
                test "$_ms_gm_mode" = unmanaged; and test $_ms_gm_result -eq 1
            end
            set -a _ms_gm_selected "$_ms_gm_file"
        else if test $_ms_gm_result -gt 1
            return $_ms_gm_result
        end
    end
    set $_ms_gm_dest $_ms_gm_selected
end
