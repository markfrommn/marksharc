# completion-fzf-tab module, init phase (spec 6.8, 6.9): load the pinned plugins named
# by this module's zsh.plugins registry from the XDG cache. Startup never touches the
# network; zsh-plugin-update clones. Loads once per shell, after native completion exists
# and before the line-editor plugins (order 95 and above) wrap widgets.
# Suppressed when completion-carapace is active unless completion-carapace.allow_fzf_tab
# is on or MARKSHARC_COMPLETION_UI forces fzf-tab/both.
# The theme module sets FZF_DEFAULT_COMMAND first when it is enabled; ag is the fallback.
if have_command ag && [[ -z ${FZF_DEFAULT_COMMAND-} ]]; then
    export FZF_DEFAULT_COMMAND='ag --hidden -g ""'
fi

if (( ! $+functions[_ms_completion_fzf_tab_active] )) || _ms_completion_fzf_tab_active; then
    if (( ! ${_ms_reloading:-0} )); then
        _ms_plugins_load completion-fzf-tab
        typeset -gi _ms_completion_ui_fzf_tab=1
    fi
else
    _ms_trace "module completion-fzf-tab: skipped (suppressed by completion-carapace; set completion-carapace.allow_fzf_tab on to force both)"
fi
true
