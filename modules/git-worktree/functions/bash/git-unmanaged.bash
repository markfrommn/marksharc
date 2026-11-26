function git-unmanaged {
    local -a selected=()
    git_managed_arr_core unmanaged selected "$@" || return
    if [[ ${MARKSHARC_SESSION-} == interactive ]]; then printf 'Git Un-Managed: %s\n' "${selected[*]}"; fi
}
