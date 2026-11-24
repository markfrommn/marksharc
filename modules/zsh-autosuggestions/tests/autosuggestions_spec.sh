Describe 'zsh-autosuggestions configuration'
  strategy_case() {
    emulate -L zsh
    local init="\$MARKSHARC_HOME/modules/zsh-autosuggestions/init.zsh"
    # Without atuin the atuin strategy is dropped; history and completion remain.
    ms_unit "MARKSHARC_SESSION=interactive; have_command() { [[ \$1 != atuin ]] && (( \${+commands[\$1]} )); }; source $init; print -r -- \"\${(j:,:)ZSH_AUTOSUGGEST_STRATEGY} \${+functions[_zsh_autosuggest_strategy_atuin]} \${ZSH_AUTOSUGGEST_USE_ASYNC-} \$ZSH_AUTOSUGGEST_MANUAL_REBIND\"" || return 1
    [[ $(<"$TEST_ROOT/out") == 'history,completion 0 1 1' ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    # With atuin, the strategy asks atuin for the newest command with the buffer as prefix.
    stub_command atuin 'printf "%s\n" "$*" >> "$OPLOG"; echo "git status --short"'
    ms_unit "MARKSHARC_SESSION=interactive; source $init; _zsh_autosuggest_strategy_atuin 'git st'; print -r -- \"\${(j:,:)ZSH_AUTOSUGGEST_STRATEGY}|\$suggestion\"" || return 3
    [[ $(<"$TEST_ROOT/out") == 'atuin,history,completion|git status --short' ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 4; }
    [[ $(<"$OPLOG") == 'search --cmd-only --limit 1 --search-mode prefix -- git st' ]] || { cat "$OPLOG"; return 5; }
    # Unknown names are dropped, an empty result falls back to history, async can be turned off.
    ms_unit "MARKSHARC_SESSION=interactive; _ms_opt_zsh_autosuggestions_strategy='bogus completion'; _ms_opt_zsh_autosuggestions_async=off; source $init; print -r -- \"\${(j:,:)ZSH_AUTOSUGGEST_STRATEGY} \${+ZSH_AUTOSUGGEST_USE_ASYNC}\"" || return 6
    [[ $(<"$TEST_ROOT/out") == 'completion 0' ]] || { cat "$TEST_ROOT/out"; return 7; }
    ms_unit "MARKSHARC_SESSION=interactive; have_command() { return 1; }; _ms_opt_zsh_autosuggestions_strategy=bogus; source $init; source $init; print -r -- \"\${(j:,:)ZSH_AUTOSUGGEST_STRATEGY}\"" || return 8
    [[ $(<"$TEST_ROOT/out") == history ]] || { cat "$TEST_ROOT/out"; return 9; }
  }
  It 'selects the available strategies, with atuin only when it is installed'
    When run strategy_case
    The status should be success
  End
  highlighters_case() {
    emulate -L zsh
    local init="\$MARKSHARC_HOME/modules/zsh-syntax-highlighting/init.zsh"
    ms_unit "MARKSHARC_SESSION=interactive; source $init; print -r -- \"\${(j:,:)ZSH_HIGHLIGHT_HIGHLIGHTERS} \$ZSH_HIGHLIGHT_MAXLENGTH\"" || return 1
    [[ $(<"$TEST_ROOT/out") == 'main,brackets 512' ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    ms_unit "MARKSHARC_SESSION=interactive; _ms_opt_zsh_syntax_highlighting_highlighters='main pattern cursor'; source $init; print -r -- \"\${(j:,:)ZSH_HIGHLIGHT_HIGHLIGHTERS}\"" || return 3
    [[ $(<"$TEST_ROOT/out") == 'main,pattern,cursor' ]] || { cat "$TEST_ROOT/out"; return 4; }
  }
  It 'enables the configured highlighters with a length limit'
    When run highlighters_case
    The status should be success
  End
End
