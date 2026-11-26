function git-managed {
    local -a selected=()
    git_managed_arr_core managed selected "$@" || return
    if [[ ${MARKSHARC_SESSION-} == interactive ]]; then printf 'Git Managed: %s\n' "${selected[*]}"; fi
}
