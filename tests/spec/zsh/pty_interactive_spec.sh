Describe 'interactive zsh PTY behaviours'
  pty_nav_case() {
    emulate -L zsh
    ms_fixture
    ms_copy_module path nav
    mkdir -p "$HOME/nav-root/alpha" "$HOME/nav-root/beta"
    ms_pty -dic '
      cd "$HOME/nav-root/alpha"
      cd "$HOME/nav-root/beta"
      dirhistory_back
      back1=$PWD
      eval cs > "$TEST_ROOT/cs.out" 2>&1 || exit 99
      [[ $(<"$TEST_ROOT/cs.out") == *"marksharc: init phase: done"* ]] || exit 98
      dirhistory_forward
      fwd1=$PWD
      print -r -- "OPTS=$([[ -o autocd && -o pushdsilent && -o pushdminus ]] && print ok) BACK=$back1 FWD=$fwd1"
      exit' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *"OPTS=ok BACK=$HOME/nav-root/alpha FWD=$HOME/nav-root/beta"* ]] || { print -r -- "$out"; return 2; }
  }
  It 'tracks directory navigation and preserves history across cs reload in a PTY'
    When run pty_nav_case
    The status should be success
  End

  pty_titles_case() {
    emulate -L zsh
    ms_fixture
    ms_copy_module path mux titles
    mkdir -p "$HOME/title-dir"
    ms_pty SHLVL=0 TERM=xterm-256color -dic '
      cd "$HOME/title-dir"
      eval cs > "$TEST_ROOT/cs.out" 2>&1 || exit 99
      [[ $(<"$TEST_ROOT/cs.out") == *"marksharc: init phase: done"* ]] || exit 98
      typeset -i count=0
      local fn
      for fn in "${chpwd_functions[@]}"; do
        [[ $fn == chdir-set-title ]] && (( count++ ))
      done
      print -r -- "HOOKS=$count"
      exit' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'HOOKS=1'* && $out == *'title-dir'* ]] || { print -r -- "$out"; return 2; }
  }
  It 'updates terminal titles on cd and avoids duplicate chpwd hooks across reload in a PTY'
    When run pty_titles_case
    The status should be success
  End

  pty_tools_reload_case() {
    emulate -L zsh
    ms_fixture
    ms_copy_module path zsh-options editor pager ls completion completion-fzf-tab
    mkdir -p "$TEST_ROOT/fpath"
    print 'print COMPINIT >> "$OPLOG"' > "$TEST_ROOT/fpath/compinit"
    local sha=$(awk '$1 == "plugin" && $2 == "fzf-tab" { print $4 }' "$MARKSHARC_ROOT/modules/completion-fzf-tab/zsh.plugins")
    local plugin_dir="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$sha"
    mkdir -p "$plugin_dir"
    print 'print FZF_TAB_LOADED >> "$OPLOG"' > "$plugin_dir/fzf-tab.plugin.zsh"
    stub_command emacs 'exit 0'
    stub_command less 'exit 0'
    ms_pty FPATH="$TEST_ROOT/fpath:$FPATH" -dic '
      zopts_ok() { [[ ! -o bgnice && -o globdots && -o extendedglob && -o menucomplete && ${aliases[j]} == "jobs -l" ]] && print ok; }
      print -r -- "BEFORE:$(zopts_ok)|$EDITOR|$PAGER|$LESS|${aliases[ll]}"
      eval cs > "$TEST_ROOT/cs.out" 2>&1 || exit 99
      [[ $(<"$TEST_ROOT/cs.out") == *"marksharc: init phase: done"* ]] || exit 98
      print -r -- "AFTER:$(zopts_ok)|$EDITOR|$PAGER|$LESS|${aliases[ll]}"
      exit' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'BEFORE:ok|emacs -nw|less -R|-FRX|ls -lA'* && $out == *'AFTER:ok|emacs -nw|less -R|-FRX|ls -lA'* ]] || { print -r -- "$out"; return 2; }
    [[ $(grep -c '^COMPINIT$' "$OPLOG") == 1 && $(grep -c '^FZF_TAB_LOADED$' "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 3; }
  }
  It 'initialises zsh-options, editor, pager, ls, completion and pinned fzf-tab once in a PTY and keeps them across reload'
    When run pty_tools_reload_case
    The status should be success
  End
End
