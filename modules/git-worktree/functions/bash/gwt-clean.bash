function gwt-clean {
    local _ms_hooks='' _ms_entry
    # The hook array is configured by the caller's overlay.
    # shellcheck disable=SC2154
    for _ms_entry in "${gwt_clean_pre_remove_hooks[@]}"; do
        _ms_hooks+="${_ms_hooks:+$'\n'}$_ms_entry"
    done
    MARKSHARC_GWT_CLEAN_HOOKS=$_ms_hooks \
        _ms_bash_run_with_directives gwt-clean "$@"
}
