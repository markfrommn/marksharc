Describe 'core session classes and silent startup'
  session_case() {
    emulate -L zsh
    local expect=$1; shift
    ms_fixture
    ms_run "$@" || return 1
    [[ $(<"$TEST_ROOT/out") == "$expect" && ! -s $TEST_ROOT/err ]] || { print -r -- "OUT=$(<$TEST_ROOT/out) ERR=$(<$TEST_ROOT/err)"; return 2; }
  }
  It 'classifies a plain non-tty zsh -c as a silent batch session'
    When run session_case batch -c 'print -r -- $MARKSHARC_SESSION'
    The status should be success
  End
  It 'classifies a non-tty zsh -ic as a silent batch session'
    When run session_case batch -ic 'print -r -- $MARKSHARC_SESSION'
    The status should be success
  End
  Describe markers
    Parameters:value CLAUDECODE=1 AI_AGENT=claude CODEX_SESSION_ID=abc CODEX_SANDBOX=seatbelt OPENCODE=1 GEMINI_CLI=1 CURSOR_AGENT=1 COPILOT_CLI=1 KILO_CLI_MODE=x VSCODE_INJECTION=1 VSCODE_NONCE=n
    It "treats $1 as an agent session for -c, -ic, -lc and -lic without output"
      markers_case() {
        emulate -L zsh
        local marker=$1 flags
        ms_fixture
        for flags in -c -ic -lc -lic; do
          ms_run $marker $flags 'print -r -- $MARKSHARC_SESSION' || return 1
          [[ $(<"$TEST_ROOT/out") == agent && ! -s $TEST_ROOT/err ]] || { print -r -- "flags=$flags OUT=$(<$TEST_ROOT/out) ERR=$(<$TEST_ROOT/err)"; return 2; }
        done
      }
      When run markers_case "$1"
      The status should be success
    End
  End
  It 'ignores empty and zero marker values'
    zero_case() {
      emulate -L zsh
      ms_fixture
      ms_run CLAUDECODE=0 AI_AGENT= -c 'print -r -- $MARKSHARC_SESSION' || return 1
      [[ $(<"$TEST_ROOT/out") == batch ]]
    }
    When run zero_case
    The status should be success
  End
  It 'lets the agent module option override the marker list'
    override_case() {
      emulate -L zsh
      ms_fixture
      ms_run _ms_opt_agent_markers='MY_AGENT OTHER_AGENT' OTHER_AGENT=1 CLAUDECODE=1 -c 'print -r -- $MARKSHARC_SESSION' || return 1
      [[ $(<"$TEST_ROOT/out") == agent ]] || return 2
      ms_run _ms_opt_agent_markers='MY_AGENT' CLAUDECODE=1 -c 'print -r -- $MARKSHARC_SESSION' || return 3
      [[ $(<"$TEST_ROOT/out") == batch ]]
    }
    When run override_case
    The status should be success
  End
  It 'does not export the session class'
    export_case() {
      emulate -L zsh
      ms_fixture
      ms_run -c 'print -r -- ${(t)MARKSHARC_SESSION}' || return 1
      [[ $(<"$TEST_ROOT/out") == scalar* && $(<"$TEST_ROOT/out") != *export* ]]
    }
    When run export_case
    The status should be success
  End
  It 'gives a PTY session the interactive class and the init phase'
    pty_case() {
      emulate -L zsh
      ms_fixture
      ms_pty -dic 'print -r -- "S=$MARKSHARC_SESSION CS=${+aliases[cs]} LI=${+aliases[li]}"; exit' || return 1
      [[ $(<"$TEST_ROOT/out") == *"S=interactive CS=1 LI=1"* ]]
    }
    When run pty_case
    The status should be success
  End
  It 'keeps a PTY session with an agent marker silent and without the init phase'
    pty_agent_case() {
      emulate -L zsh
      ms_fixture
      ms_pty CLAUDECODE=1 -dic 'print -r -- "S=$MARKSHARC_SESSION CS=${+aliases[cs]}"; exit' || return 1
      [[ $(<"$TEST_ROOT/out") == "S=agent CS=0" ]]
    }
    When run pty_agent_case
    The status should be success
  End
  It 'keeps a PTY login session silent under an agent marker'
    pty_login_agent_case() {
      emulate -L zsh
      ms_fixture
      ms_pty CODEX_SESSION_ID=x -lic 'print -r -- "S=$MARKSHARC_SESSION"; exit' || return 1
      [[ $(<"$TEST_ROOT/out") == *"S=agent"* && $(<"$TEST_ROOT/out") != *marksharc* ]] && [[ $(wc -l < "$TEST_ROOT/out") -le 2 ]]
    }
    When run pty_login_agent_case
    The status should be success
  End
  # The shipped ~/.zshenv stub (identity across platforms, missing-core fallback)
  # arrives with the P2.4 installer; its two examples move with it.
End
