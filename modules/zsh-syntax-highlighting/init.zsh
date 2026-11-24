# zsh-syntax-highlighting module, init phase (spec 6.8). The plugin wraps every widget
# that exists when it is sourced, so it loads last of all (order 99): after fzf-tab,
# atuin, the nav widgets and zsh-autosuggestions. Long buffers (a pasted script) are not
# highlighted, which keeps typing responsive.
typeset -ga ZSH_HIGHLIGHT_HIGHLIGHTERS=( ${=_ms_opt_zsh_syntax_highlighting_highlighters-main brackets} )
(( $#ZSH_HIGHLIGHT_HIGHLIGHTERS )) || ZSH_HIGHLIGHT_HIGHLIGHTERS=( main )
typeset -g ZSH_HIGHLIGHT_MAXLENGTH=${ZSH_HIGHLIGHT_MAXLENGTH:-512}
(( ${_ms_reloading:-0} )) || _ms_plugins_load zsh-syntax-highlighting
true
