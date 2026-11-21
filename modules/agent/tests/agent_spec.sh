Describe 'agent module marker option'
  config_case() {
    emulate -L zsh
    ms_fixture
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'set agent.markers MY_AGENT OTHER_AGENT' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_mod agent module.conf 'describe "x"
option markers "" "x"'
    ms_run MY_AGENT=1 -c 'print -r -- $MARKSHARC_SESSION' || return 1
    [[ $(<"$TEST_ROOT/out") == agent && ! -s "$TEST_ROOT/err" ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    ms_run OTHER_AGENT=yes -c 'print -r -- $MARKSHARC_SESSION' || return 3
    [[ $(<"$TEST_ROOT/out") == agent ]] || return 4
    # The configured list replaces the default one.
    ms_run CLAUDECODE=1 -c 'print -r -- $MARKSHARC_SESSION' || return 5
    [[ $(<"$TEST_ROOT/out") == batch ]] || { cat "$TEST_ROOT/out"; return 6; }
    # Without the option the default list applies.
    rm "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_run CLAUDECODE=1 -c 'print -r -- $MARKSHARC_SESSION' || return 7
    [[ $(<"$TEST_ROOT/out") == agent ]] || return 8
  }
  It 'lets config.conf replace the marker list before any module loads'
    When run config_case
    The status should be success
  End
  declares_case() {
    emulate -L zsh
    [[ $(<"$MARKSHARC_ROOT/modules/agent/module.conf") == *'option markers'* ]]
  }
  It 'declares the markers option'
    When run declares_case
    The status should be success
  End
End
