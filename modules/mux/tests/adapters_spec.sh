Describe 'multiplexer adapter contract'
  mux() { "$MARKSHARC_ROOT/modules/mux/bin/marksharc-mux" "$@"; }

  adapter_case() {
    emulate -L zsh
    export TERM=xterm
    local adapter=$1 expected
    case $adapter in
      tmux)
        export TMUX=/tmp/fixture,1,0 TMUX_PANE=%7
        stub_command tmux 'printf "%s\n" "$*" >> "$OPLOG"
          case "$1" in
            list-sessions) echo "work";;
            show-environment) printf "DISPLAY=\"localhost:12.0\"; export DISPLAY;\n";;
          esac'
        expected=work;;
      herdr)
        export HERDR_WORKSPACE_ID=w1 HERDR_TAB_ID=t1 HERDR_PANE_ID=p1
        stub_command herdr 'printf "%s\n" "$*" >> "$OPLOG"
          if [ "$*" = "session list" ]; then printf "NAME STATE PID SOCKET\nwork running 42 /tmp/herdr.sock\n"; fi'
        expected=$'work\t/tmp/herdr.sock';;
      herdr-core)
        export HC_TERMINAL_ID=t7
        export HC_SOCKET="$TEST_ROOT/unrelated.sock" HC_TERMINAL_SOCKET="$TEST_ROOT/core.sock"
        "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HC_TERMINAL_SOCKET" || return 2
        stub_command hc 'test "$HC_SOCKET" = "$HC_TERMINAL_SOCKET" || exit 2
          printf "%s\n" "$*" >> "$OPLOG"; if [ "$1" = ls ]; then echo "[{}]"; fi'
        expected='[{}]';;
      wezterm)
        export WEZTERM_PANE=5
        stub_command wezterm 'printf "%s\n" "$*" >> "$OPLOG"; if [ "$2" = list ]; then echo "[{}]"; fi'
        expected='[{}]';;
      plain) expected='';;
    esac
    [[ $(mux detect) == "$adapter" ]] || return 1
    [[ $(mux sessions "$adapter") == "$expected" ]] || return 2
    mux set_titles 'repo' 'two words' 'path tail' 'sub dir' 'zsh-chdir' > "$TEST_ROOT/title" || return 3
    export MARKSHARC_DIRECTIVES="$TEST_ROOT/directives"
    : > "$MARKSHARC_DIRECTIVES"
    mux refresh_env client || return 4
    case $adapter in
      tmux)
        grep -Fxq 'rename-window -t %7 -- two words' "$OPLOG" &&
          grep -Fxq 'select-pane -t %7 -T path tail' "$OPLOG" &&
          grep -Fxq $'setenv\tDISPLAY\tlocalhost:12.0' "$MARKSHARC_DIRECTIVES";;
      herdr) grep -Fxq 'tab rename t1 two words' "$OPLOG" && [[ ! -s $MARKSHARC_DIRECTIVES ]];;
      herdr-core)
        grep -Fxq 'label t7 marksharc.workspace=repo marksharc.tab=two words marksharc.pane=path tail' "$OPLOG" &&
          [[ $(<"$TEST_ROOT/title") == $'\e]2;path tail\a' && ! -s $MARKSHARC_DIRECTIVES ]];;
      wezterm) grep -Fxq 'cli set-tab-title --pane-id 5 -- two words' "$OPLOG" && [[ ! -s $MARKSHARC_DIRECTIVES ]];;
      plain) [[ $(<"$TEST_ROOT/title") == $'\e]1;two words\a' && ! -s $MARKSHARC_DIRECTIVES ]];;
    esac
  }
  Context 'adapter capabilities'
    Parameters:value tmux herdr herdr-core wezterm plain
    It 'detects, titles, enumerates and reads client environment through the adapter'
      When run adapter_case "$1"
      The status should be success
    End
  End

  nested_case() {
    emulate -L zsh
    export HERDR_TAB_ID=t1 WEZTERM_PANE=5 TERM=xterm
    stub_command herdr 'printf "herdr %s\n" "$*" >> "$OPLOG"; exit 1'
    stub_command wezterm 'printf "wezterm %s\n" "$*" >> "$OPLOG"'
    [[ $(mux detect) == $'herdr\nwezterm' ]] || return 1
    [[ -z $(mux set_titles work tab pane) ]] || return 2
    grep -Fxq 'herdr tab rename t1 tab' "$OPLOG" &&
      grep -Fxq 'wezterm cli set-tab-title --pane-id 5 -- tab' "$OPLOG"
  }
  It 'dispatches titles to both nested adapters even if the first fails'
    When run nested_case
    The status should be success
  End
End
