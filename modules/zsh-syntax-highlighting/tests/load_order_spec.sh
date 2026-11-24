Describe 'line-editor plugin load order (spec 6.4, 6.8)'
  conf_order() { local line; for line in "${(@f)$(<"$MARKSHARC_ROOT/modules/$1/module.conf")}"; do [[ $line == 'order '* ]] && { print -r -- ${line#order }; return; }; done; print 50; }
  pin_sha() { local -a w; w=( ${=${(M)${(f)"$(<"$MARKSHARC_ROOT/modules/$1/zsh.plugins")"}:#plugin *}[1]} ); print -r -- $w[4]; }
  bands_case() {
    emulate -L zsh
    local fzf_tab=$(conf_order completion-fzf-tab) atuin=$(conf_order history-atuin) nav=$(conf_order nav)
    local suggest=$(conf_order zsh-autosuggestions) highlight=$(conf_order zsh-syntax-highlighting)
    (( fzf_tab < atuin && nav < suggest && atuin < suggest && suggest < highlight )) || { print -r -- "$fzf_tab $nav $atuin $suggest $highlight"; return 1; }
    (( suggest >= 95 )) || return 2
    # zsh-syntax-highlighting wraps every widget that exists when it loads: nothing loads after it.
    local conf mod
    for conf in "$MARKSHARC_ROOT"/modules/*/module.conf; do
      mod=${conf:h:t}
      [[ $mod == zsh-syntax-highlighting ]] && continue
      (( $(conf_order $mod) < highlight )) || { print -r -- "$mod loads with or after zsh-syntax-highlighting"; return 3; }
    done
  }
  It 'orders fzf-tab, atuin and nav before autosuggestions, and syntax highlighting last of all'
    When run bands_case
    The status should be success
  End
  startup_case() {
    emulate -L zsh
    ms_fixture_full
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    stub_command atuin 'printf "%s\n" "print ATUIN_INIT >> \"\$OPLOG\"" "atuin-search() { :; }; zle -N atuin-search"'
    stub_command git 'echo "FORBIDDEN git $*" >> "$OPLOG"; exit 99'
    local name entry
    for name in completion-fzf-tab zsh-autosuggestions zsh-syntax-highlighting; do
      case $name in
        completion-fzf-tab) entry=fzf-tab ;;
        *) entry=$name ;;
      esac
      mkdir -p "$XDG_CACHE_HOME/marksharc/plugins/$entry@$(pin_sha $name)"
      print -r -- "print -r -- PLUGIN:$entry >> \"\$OPLOG\"" > "$XDG_CACHE_HOME/marksharc/plugins/$entry@$(pin_sha $name)/$entry.plugin.zsh"
    done
    print -r -- 'typeset -ga ZSH_AUTOSUGGEST_CLEAR_WIDGETS=( up-line-or-history )' >> "$XDG_CACHE_HOME/marksharc/plugins/zsh-autosuggestions@$(pin_sha zsh-autosuggestions)/zsh-autosuggestions.plugin.zsh"
    local script='print -r -- "STRATEGY=${(j:,:)ZSH_AUTOSUGGEST_STRATEGY} CLEAR=${(j:,:)ZSH_AUTOSUGGEST_CLEAR_WIDGETS[1,3]} HL=${(j:,:)ZSH_HIGHLIGHT_HIGHLIGHTERS}"'
    script+='; eval cs >/dev/null 2>&1; print READY'
    ms_pty -dic "$script" || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *READY* ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(<"$TEST_ROOT/out") == *'STRATEGY=atuin,history,completion CLEAR=up-line-or-history,atuin-search,atuin-search-viins HL=main,brackets'* ]] || { cat "$TEST_ROOT/out"; return 3; }
    local order=${(j: :)${(M)${(f)"$(<"$OPLOG")"}:#(PLUGIN:*|ATUIN_INIT)}}
    # Each plugin is sourced once, in band order; the reload sources none of them again.
    [[ $order == 'PLUGIN:fzf-tab ATUIN_INIT PLUGIN:zsh-autosuggestions PLUGIN:zsh-syntax-highlighting' ]] || { cat "$OPLOG"; return 4; }
    [[ $(<"$OPLOG") != *'FORBIDDEN git'* ]] || { cat "$OPLOG"; return 5; }
  }
  It 'sources the pinned plugins once, in band order, with atuin before autosuggestions'
    When run startup_case
    The status should be success
  End
  missing_case() {
    emulate -L zsh
    ms_fixture_full
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    stub_command git 'echo "FORBIDDEN git $*" >> "$OPLOG"; exit 99'
    # No clones at all, and completion-fzf-tab (the loader's home) switched off.
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'module completion-fzf-tab off' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_pty -dic 'print -r -- "LOADED=${+functions[_zsh_highlight]}${+functions[_zsh_autosuggest_start]}"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *LOADED=00* && $(<"$TEST_ROOT/out") == *READY* ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(<"$TEST_ROOT/out") != *'command not found'* && $(<"$TEST_ROOT/out") != *zsh-plugin-load* ]] || { cat "$TEST_ROOT/out"; return 3; }
    # With fzf-tab off, a clone still loads through the core helper.
    local root="$XDG_CACHE_HOME/marksharc/plugins/zsh-syntax-highlighting@$(pin_sha zsh-syntax-highlighting)"
    mkdir -p "$root"
    print -r -- 'print -r -- PLUGIN:zsh-syntax-highlighting >> "$OPLOG"' > "$root/zsh-syntax-highlighting.plugin.zsh"
    ms_pty -dic 'print READY' || { cat "$TEST_ROOT/out"; return 4; }
    [[ $(grep -c '^PLUGIN:zsh-syntax-highlighting$' "$OPLOG") == 1 && $(<"$OPLOG") != *'FORBIDDEN git'* ]] || { cat "$OPLOG"; return 5; }
  }
  It 'starts silently without clones and loads a clone when completion-fzf-tab is off'
    When run missing_case
    The status should be success
  End
End
