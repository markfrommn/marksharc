# The stub's safe fallback (spec 11, "a dev checkout as MARKSHARC_HOME can break every new
# shell"): when the core cannot load, the shell still starts with a minimal PATH and one
# error line on stderr; stdout stays clean. The stub is the one install.sh writes.
Describe 'stub fallback when the core fails to load'
  fb_setup() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/templates" "$MS_HOME/templates"
    PATH="$PATH:${REAL_GIT:h}" sh "$MARKSHARC_ROOT/install.sh" --home "$MS_HOME" > "$TEST_ROOT/install.out" 2>&1 || { cat "$TEST_ROOT/install.out"; return 1; }
    want_path="$MS_HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
  }
  # one_line_case: the run in $TEST_ROOT/out and err printed the minimal PATH and one marksharc line.
  expect_fallback() {
    [[ $(<"$TEST_ROOT/out") == "$want_path" ]] || { print -r -- "stdout: $(<"$TEST_ROOT/out")"; return 1; }
    [[ $(grep -c '^marksharc: could not load ' "$TEST_ROOT/err") == 1 ]] || { cat "$TEST_ROOT/err"; return 2; }
    [[ $(grep -c . "$TEST_ROOT/err") == 1 ]] || { cat "$TEST_ROOT/err"; return 3; }
  }

  missing_case() {
    emulate -L zsh
    fb_setup || return 1
    rm "$MS_HOME/core/zsh/zshenv.zsh"
    ms_run -c 'print -r -- "$PATH"' || return 2
    expect_fallback || return 3
    # in a login shell and in an agent session as well
    ms_run -dlc 'print -r -- "$PATH"' || return 4
    expect_fallback || return 5
    ms_run CLAUDECODE=1 -c 'print -r -- "$PATH"' || return 6
    expect_fallback || return 7
    ms_run MARKSHARC_VERBOSE=1 -c 'print -r -- "$PATH"' || return 8
    expect_fallback
  }
  It 'sets a minimal PATH and prints one stderr line when the core file is missing'
    When run missing_case
    The status should be success
  End

  unreadable_case() {
    emulate -L zsh
    (( EUID != 0 )) || return 0
    fb_setup || return 1
    chmod 000 "$MS_HOME/core/zsh/zshenv.zsh"
    ms_run -c 'print -r -- "$PATH"' || return 2
    chmod 644 "$MS_HOME/core/zsh/zshenv.zsh"
    expect_fallback
  }
  It 'does the same when the core file is unreadable'
    When run unreadable_case
    The status should be success
  End

  failing_case() {
    emulate -L zsh
    fb_setup || return 1
    # The core returns failure after changing PATH: the fallback replaces it.
    print -r -- 'PATH=/changed-by-core; export PATH; return 3' > "$MS_HOME/core/zsh/zshenv.zsh"
    ms_run -c 'print -r -- "$PATH"' || return 2
    expect_fallback || return 3
    # A syntax error: zsh may add its own diagnostic, but the stub's line is there once.
    print -r -- 'x=(' > "$MS_HOME/core/zsh/zshenv.zsh"
    ms_run -c 'print -r -- "$PATH"' || return 4
    [[ $(<"$TEST_ROOT/out") == "$want_path" && $(grep -c '^marksharc: could not load ' "$TEST_ROOT/err") == 1 ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 5; }
  }
  It 'does the same when the core fails or cannot be parsed'
    When run failing_case
    The status should be success
  End

  healthy_case() {
    emulate -L zsh
    fb_setup || return 1
    ms_run -c 'print -r -- "$MARKSHARC_SESSION"' || return 2
    [[ $(<"$TEST_ROOT/out") == batch && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/err"; return 3; }
  }
  It 'stays silent when the core loads'
    When run healthy_case
    The status should be success
  End

  interactive_case() {
    emulate -L zsh
    fb_setup || return 1
    rm "$MS_HOME/core/zsh/zshenv.zsh"
    ms_pty -dic 'print -r -- "PATH=$PATH"; exit' || return 2
    [[ $(grep -c 'marksharc: could not load ' "$TEST_ROOT/out") == 1 ]] || { cat "$TEST_ROOT/out"; return 3; }
    [[ $(<"$TEST_ROOT/out") == *"PATH=$want_path"* ]] || { cat "$TEST_ROOT/out"; return 4; }
  }
  It 'does the same in an interactive shell on a terminal'
    When run interactive_case
    The status should be success
  End
End
