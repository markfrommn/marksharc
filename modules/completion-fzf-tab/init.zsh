# completion-fzf-tab module, init phase (spec 6.8): load the pinned plugins named by this
# module's zsh.plugins registry from the XDG cache. Startup never touches the network;
# zsh-plugin-update clones. Loads once per shell, after native completion exists and
# before the line-editor plugins (order 95 and above) wrap widgets.
# The theme module sets FZF_DEFAULT_COMMAND first when it is enabled; ag is the fallback.
if have_command ag && [[ -z ${FZF_DEFAULT_COMMAND-} ]]; then
    export FZF_DEFAULT_COMMAND='ag --hidden -g ""'
fi

(( ${_ms_reloading:-0} )) || _ms_plugins_load completion-fzf-tab
true
