Describe 'mux module'
  fix_tmux_case() {
    emulate -L zsh
    cat > "$TEST_ROOT/bin/tmux" <<'DATA'
#!/bin/sh
[ "$1 $2" = 'show-env -s' ] && printf 'FIXED_BY_TMUX="two words"; export FIXED_BY_TMUX;\n'
DATA
    chmod +x "$TEST_ROOT/bin/tmux"
    load_mfn mux fix-tmux
    unset TMUX
    [[ $(fix-tmux) == 'Not in tmux' ]] || return 1
    TMUX=/tmp/fixture,1,0
    fix-tmux
    [[ $FIXED_BY_TMUX == 'two words' ]]
  }
  It 'fix-tmux re-imports the tmux client environment only inside tmux'
    When run fix_tmux_case
    The status should be success
  End
End
