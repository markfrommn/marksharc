function cwf-new {
    local _ms_hooks='' _ms_excludes='' _ms_entry
    # Hook arrays are configured by the caller's overlay.
    # shellcheck disable=SC2154
    for _ms_entry in "${cwf_new_post_create_hooks[@]}"; do
        _ms_hooks+="${_ms_hooks:+$'\n'}$_ms_entry"
    done
    # shellcheck disable=SC2154
    for _ms_entry in "${cwf_new_copy_exclude[@]}"; do
        _ms_excludes+="${_ms_excludes:+$'\n'}$_ms_entry"
    done
    MARKSHARC_CWF_NEW_HOOKS=$_ms_hooks \
    MARKSHARC_CWF_NEW_COPY_EXCLUDE=$_ms_excludes \
        _ms_bash_run_with_directives cwf-new "$@"
}
