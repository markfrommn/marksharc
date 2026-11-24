Describe 'mux environment refresh'
  tmux_case() {
    emulate -L zsh
    local MARKSHARC_HOME=$MARKSHARC_ROOT
    source "$MARKSHARC_HOME/core/zsh/lib/directives.zsh"
    load_mfn mux
    [[ $(fix-tmux) == 'Not in tmux' ]] || return 1
    mkdir "$TEST_ROOT/ssh-forwarded dir"
    export SOCKET="$TEST_ROOT/ssh-forwarded dir/agent.1"
    export AUTH_PAYLOAD='literal \$HOME \$(touch '"$TEST_ROOT"'/pwned)'
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$SOCKET" || return 2
    stub_command tmux 'test "$*" = "show-environment -s -t %7" || exit 1
      if [ -e "$TEST_ROOT/detached" ]; then
          printf "unset DISPLAY;\nunset SSH_AUTH_SOCK;\n"
      else
          printf "DISPLAY=\"localhost:12.0\"; export DISPLAY;\nSSH_AUTH_SOCK=\"%s\"; export SSH_AUTH_SOCK;\n" "$SOCKET"
      fi
      printf "XAUTHORITY=\"%s\"; export XAUTHORITY;\n" "$AUTH_PAYLOAD"
      printf "OTHER=\"a\nunset DISPLAY;\"; export OTHER;\n"'
    export TMUX=/tmp/fixture,1,0 TMUX_PANE=%7 DISPLAY=localhost:10.0 SSH_AUTH_SOCK=/stale SSH_AGENT_PID=99
    fix-tmux || return 3
    [[ $DISPLAY == localhost:12.0 && $DISPLAY_ORIG == "$DISPLAY" && $SSH_AUTH_SOCK == "$SOCKET" && -z $SSH_AGENT_PID ]] || return 4
    [[ $XAUTHORITY == 'literal $HOME $(touch '* && ! -e $TEST_ROOT/pwned ]] || return 5

    source "$MARKSHARC_HOME/modules/mux/init.zsh"
    source "$MARKSHARC_HOME/modules/mux/init.zsh"
    [[ ${(j:,:)preexec_functions} == _ms_mux_refresh_client ]] || return 6
    export DISPLAY=:99
    _ms_mux_refresh_client
    [[ $DISPLAY == :99 ]] || return 8
    : > "$TEST_ROOT/detached"
    _ms_mux_refresh_client
    [[ ! -v DISPLAY && ! -v DISPLAY_ORIG && ! -v SSH_AUTH_SOCK ]] || return 7
    _ms_mux_cleanup
    [[ -z $preexec_functions && -z $precmd_functions ]]
  }
  It 'transfers selected pane client data literally, handles removals and registers a single hook'
    When run tmux_case
    The status should be success
  End

  display_case() {
    emulate -L zsh
    local MARKSHARC_HOME=$MARKSHARC_ROOT
    source "$MARKSHARC_HOME/core/zsh/lib/directives.zsh"
    load_mfn x11
    export HC_TERMINAL_ID=t1 SSH_CONNECTION='192.0.2.1 1024 192.0.2.2 22' DISPLAY=localhost:12.0
    stub_command xauth 'printf "%s\n" "$(hostname)/unix:13 MIT-MAGIC-COOKIE-1 fake" "$(hostname)/unix:14 MIT-MAGIC-COOKIE-1 fake"'
    stub_command gtimeout 'test "$1 $2 $3" = "-k 0.1 0.25" || exit 1
      if [ "$4" = xauth ]; then shift 3; exec "$@"; fi
      test "$4 $5" = "xdpyinfo -display" || exit 1
      printf "%s\n" "$6" >> "$OPLOG"
      [ "$6" = localhost:13.0 ] || { [ "$6" = localhost:14.0 ] && [ -e "$TEST_ROOT/ambiguous" ]; }'
    stub_command xdpyinfo 'exit 91'
    setup-x11-display --startup || return 1
    [[ $DISPLAY == localhost:12.0 && ! -s $OPLOG ]] || return 2
    setup-x11-display || return 3
    [[ $DISPLAY == localhost:13.0 && $DISPLAY_ORIG == "$DISPLAY" ]] || return 4
    : > "$TEST_ROOT/ambiguous"
    export DISPLAY=localhost:12.0
    setup-x11-display || return 5
    [[ ! -v DISPLAY && ! -v DISPLAY_ORIG ]]
  }
  It 'recovers an unambiguous authenticated DISPLAY with bounded probes only on demand'
    When run display_case
    The status should be success
  End

  agent_case() {
    emulate -L zsh
    local MARKSHARC_HOME=$MARKSHARC_ROOT
    source "$MARKSHARC_HOME/core/zsh/lib/directives.zsh"
    load_mfn mux
    export HC_TERMINAL_ID=t1 SSH_TTY=/dev/fixture SSH_AUTH_SOCK=/stale SSH_AGENT_PID=42
    export TMPDIR="$TEST_ROOT/temp" XDG_RUNTIME_DIR="$TEST_ROOT/runtime"
    mkdir -p "$TMPDIR/ssh-fixture" "$XDG_RUNTIME_DIR"
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$TMPDIR/ssh-fixture/agent.1" || return 1
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$XDG_RUNTIME_DIR/openssh_agent" || return 2
    stub_command uname 'echo Linux'
    stub_command gtimeout 'test "$1 $2 $3" = "-k 0.1 0.5" || exit 3; shift 3; exec "$@"'
    stub_command ssh-add 'test "$1" = -l || exit 99
      case "$SSH_AUTH_SOCK" in "$TEST_ROOT"/*) exit 1;; *) exit 2;; esac'
    refresh-env || return 3
    [[ $SSH_AUTH_SOCK == "$TMPDIR/ssh-fixture/agent.1" && ! -v SSH_AGENT_PID ]] || return 4
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$TMPDIR/ssh-fixture/agent.2" || return 5
    export SSH_AUTH_SOCK=/stale
    refresh-env || return 6
    [[ $SSH_AUTH_SOCK == "$XDG_RUNTIME_DIR/openssh_agent" ]] || return 7

    # A tmux socket path can still exist after its SSH listener is gone.
    export TMUX=/tmp/fixture,1,0 TMUX_PANE=%7
    stub_command tmux 'printf "SSH_AUTH_SOCK=\"%s\"; export SSH_AUTH_SOCK;\n" "$TMPDIR/ssh-fixture/agent.1"'
    stub_command gtimeout 'case "$SSH_AUTH_SOCK" in */agent.1) exit 124;; esac; shift 3; exec "$@"'
    refresh-env || return 8
    [[ $SSH_AUTH_SOCK == "$XDG_RUNTIME_DIR/openssh_agent" ]]
  }
  It 'reuses a live forwarded socket and prefers the OS agent when forwarding is ambiguous'
    When run agent_case
    The status should be success
  End
End
