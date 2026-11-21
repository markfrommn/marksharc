Describe 'cs and li reload'
  reload_case() {
    emulate -L zsh
    ms_fixture
    ms_mod probe module.conf 'describe "probe"'
    ms_mod probe env.zsh 'print -r -- "env rebuild=$_ms_env_rebuild reloading=$_ms_reloading" >> "$OPLOG"'
    ms_mod probe init.zsh 'print -r -- "init reloading=$_ms_reloading" >> "$OPLOG"'
    ms_pty -dic 'eval cs; print -r -- "AFTER verbose=${MARKSHARC_VERBOSE-unset} reloading=$_ms_reloading"; eval li; exit' || return 1
    [[ $(<"$OPLOG") == $'env rebuild=1 reloading=0\ninit reloading=0\nenv rebuild=1 reloading=1\ninit reloading=1\nenv rebuild=1 reloading=1\ninit reloading=1' ]] || { cat "$OPLOG"; return 2; }
    # Both aliases trace to stderr (the PTY merges it); verbosity does not stick.
    [[ $(<"$TEST_ROOT/out") == *'marksharc: env phase: start'* && $(<"$TEST_ROOT/out") == *'marksharc: module probe: env.zsh'* && $(<"$TEST_ROOT/out") == *'marksharc: init phase: done'* ]] || { cat "$TEST_ROOT/out"; return 3; }
    [[ $(<"$TEST_ROOT/out") == *'AFTER verbose=unset reloading=0'* ]] || { cat "$TEST_ROOT/out"; return 4; }
  }
  It 'forces an env rebuild and re-runs init with a verbose trace that does not stick'
    When run reload_case
    The status should be success
  End
  edit_case() {
    emulate -L zsh
    ms_fixture
    ms_pty -dic 'print -r -- "_ms_new_fn() { print edited-core; }" >> "$MARKSHARC_HOME/core/zsh/lib/util.zsh"; eval cs >/dev/null 2>&1; _ms_new_fn; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *edited-core* ]]
  }
  It 'picks up edits to the core library files'
    When run edit_case
    The status should be success
  End
  login_case() {
    emulate -L zsh
    ms_fixture
    ms_mod probe module.conf 'describe "probe"'
    ms_mod probe env.zsh 'path=( /marksharc-first "${path[@]}" )'
    ms_pty -dic 'path=( ${path:#/marksharc-first} /after ); eval li >/dev/null 2>&1; print -r -- "P1=$path[1] LAST=$path[-1]"; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'P1=/marksharc-first'* && $(<"$TEST_ROOT/out") == *'LAST=/after'* ]]
  }
  It 'li re-asserts the module PATH and keeps later additions last'
    When run login_case
    The status should be success
  End
  quiet_reload_case() {
    emulate -L zsh
    ms_fixture
    ms_run MARKSHARC_VERBOSE=1 -c 'print x' || return 1
    [[ $(<"$TEST_ROOT/err") == *marksharc:* ]] || return 2
    ms_run -c 'print x' || return 3
    [[ ! -s $TEST_ROOT/err ]]
  }
  It 'traces to stderr only when MARKSHARC_VERBOSE is set'
    When run quiet_reload_case
    The status should be success
  End
  redirected_case() {
    emulate -L zsh
    ms_fixture
    ms_mod probe module.conf 'describe "probe"'
    ms_mod probe init.zsh 'print -r -- init >> "$OPLOG"'
    ms_pty -dic 'cs >/dev/null 2>&1; print -r -- "S1=$MARKSHARC_SESSION A=${+aliases[cs]}"; li >/dev/null 2>&1 </dev/null; print -r -- "S2=$MARKSHARC_SESSION"; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'S1=interactive A=1'* && $(<"$TEST_ROOT/out") == *'S2=interactive'* ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(grep -c '^init$' "$OPLOG") == 3 ]] || { cat "$OPLOG"; return 3; }
  }
  It 'keeps the session class when a reload runs with redirected output'
    When run redirected_case
    The status should be success
  End
End
