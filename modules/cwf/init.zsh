# Hook registries for cwf-new (see the function): other modules append to them.
typeset -gaU cwf_new_post_create_hooks cwf_new_copy_exclude

# Setup cwf including completions when the tooling checkout is known (COMMON_DEV_TOOLS).
if [[ -n ${COMMON_DEV_TOOLS-} && -d $COMMON_DEV_TOOLS ]]; then
    _ms_trace "loading cwf funcs using $COMMON_DEV_TOOLS"
    # Not cached: the output may depend on the tooling repository contents. Once per shell.
    if (( ! ${_ms_reloading:-0} )); then
        typeset _ms_cwf_tmp
        _ms_cwf_tmp=$(mktemp /tmp/cwf-zsh.XXXXXX)
        if [[ -n $_ms_cwf_tmp ]] && cwf shell zsh > "$_ms_cwf_tmp"; then source "$_ms_cwf_tmp"; fi
        [[ -z $_ms_cwf_tmp ]] || rm -f -- "$_ms_cwf_tmp"
        unset _ms_cwf_tmp
    fi
fi
