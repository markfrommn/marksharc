Describe 'launch-session'
  launch_session() { "$MARKSHARC_ROOT/modules/launch/bin/launch-session" "$@"; }
  no_python() { [[ -z $PYTHON ]]; }

  stub_tmux() {
    stub_command tmux 'case "$*" in
      *display-message*) printf "\0443:/dev/pts/incorrect\n" ;;
      *list-sessions*) printf "%s\n" "${TMUX_ROWS:-}" ;;
      *new-session*|*new-window*)
        printf "%s\n" "${AI_AGENT-unset}" "${CUSTOM_AGENT-unset}" > "$TEST_ROOT/mux-agent-markers"
        printf "%s\0" "$@" >> "$OPLOG"
        printf "\0443:@4.%%5\n" ;;
    esac'
  }

  stub_herdr() {
    stub_command herdr 'case "$*" in
      "session list --json") printf "%s\n" "{\"sessions\":[{\"name\":\"tui\",\"running\":true}]}" ;;
      "workspace list") exit 0 ;;
      "machine list --json") printf "%s\n" "[{\"enabled\":true,\"label\":\"build\",\"target\":\"build\"}]" ;;
      *create*)
        printf "%s\0" "$@" >> "$OPLOG"
        printf "%s\n" "{\"result\":{\"root_pane\":{\"pane_id\":\"w1:p1\"}}}" ;;
    esac'
  }

  stub_hc() {
    stub_command hc 'case "$*" in
      "machine ls --json")
        if [ "${HC_SESSION:-}" = "${EMPTY_CORE:-none}" ]; then
          printf "%s\n" "{\"machines\":[]}"
        else
          printf "%s\n" "{\"machines\":[{\"name\":\"peer\",\"target\":\"dev@build\",\"host\":\"build\"}]}"
        fi ;;
      *run*)
        printf "%s\0" "$@" >> "$OPLOG"
        case "$*" in
          *"--on peer"*) printf "%s\n" "{\"address\":\"peer/t21\"}" ;;
          *) printf "%s\n" "{\"address\":\"t21\"}" ;;
        esac ;;
    esac'
  }

  start_core_fixture() {
    local instance=$1 dir="$XDG_STATE_HOME/herdr-core/$1"
    mkdir -p "$dir"
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$TEST_ROOT/$instance.sock" || return
    printf '%s\n' "$TEST_ROOT/$instance.sock" > "$dir/core.lock"
  }

  It 'shows both forms in help'
    When run launch_session --help
    The status should be success
    The line 1 of output should include '[[host:]dir'
    The output should include '--command'
  End

  Context 'usage errors'
    Parameters:matrix
      --host --pwd --command --mux --place --env --name --mux-id
    End
    It 'requires an argument to every value option'
      When run launch_session "$1"
      The status should equal 2
      The stderr should include "$1"
    End
  End

  validation_case() {
    local err=$TEST_ROOT/err out=$TEST_ROOT/out
    stub_tmux
    launch_session --pwd "$HOME" . > "$out" 2> "$err"
    [[ $? == 2 && ! -s $out ]] || return 1
    launch_session . --pwd "$HOME" > "$out" 2> "$err"
    [[ $? == 2 && ! -s $out ]] || return 2
    launch_session --env LAUNCH_RUN=bad > "$out" 2> "$err"
    [[ $? == 2 && ! -s $out ]] || return 3
    launch_session --env 'A-B=value' > "$out" 2> "$err"
    [[ $? == 2 && ! -s $out ]] || return 4
    launch_session --host build --pwd relative > "$out" 2> "$err"
    [[ $? == 2 && ! -s $OPLOG ]]
  }
  It 'validates conflicts and invalid values before creation'
    When run validation_case
    The status should be success
  End

  forms_case() {
    stub_tmux
    export MARKSHARC_HOST=dev TMUX_ROWS='$3:work' DISPLAY=localhost:12.0 XAUTHORITY="$HOME/path with space"
    export SSH_AUTH_SOCK="$HOME/forwarded" AI_AGENT=1
    local data='space; $ "quote"'
    local preview expected
    expected="'tmux' 'new-window' '-t' '\$3:' '-c' '$HOME' '-n' '${HOME:t}'"
    expected+=" '-e' 'LAUNCH_PARENT_PID=$$' '-e' 'LAUNCH_PARENT_HOST=dev'"
    expected+=" '-e' 'LAUNCH_PARENT_SSH_AUTH_SOCK=$SSH_AUTH_SOCK' '-e' 'LAUNCH_PARENT_DISPLAY=$DISPLAY'"
    expected+=" '-e' 'LAUNCH_RUN=' '-e' 'LAUNCH_RUN_EXEC=' '-e' 'LAUNCH_WORKTREE='"
    expected+=" '-e' 'DISPLAY=$DISPLAY' '-e' 'XAUTHORITY=$XAUTHORITY' '-e' 'SSH_AUTH_SOCK=$SSH_AUTH_SOCK'"
    expected+=" '-e' 'DATA=$data' '-P' '-F' '#{session_id}:#{window_id}.#{pane_id}'"
    expected+=" '--' '/bin/echo' 'argument' '--quiet'"
    preview=$(launch_session --mux tmux --place tab --dry-run --env "DATA=$data" 'local:~' /bin/echo argument --quiet) || return 1
    # ShellSpec may add an intermediate process when capturing output.
    preview=${preview//LAUNCH_PARENT_PID=<->/LAUNCH_PARENT_PID=$$}
    [[ $preview == "$expected" ]] || { print -r -- "$preview"; return 2; }
    preview=$(launch_session --host localhost --pwd "$HOME" --mux tmux --place tab --dry-run \
      --env "DATA=$data" --command /bin/echo -- argument --quiet) || return 3
    preview=${preview//LAUNCH_PARENT_PID=<->/LAUNCH_PARENT_PID=$$}
    [[ $preview == "$expected" && ! -s $OPLOG ]] || return 4
    [[ $(launch_session --mux tmux --place tab --pwd "$HOME" -- /bin/echo argument) == $'tmux\t$3\t\t$3:@4.%5' ]] || return 5
    [[ -z $(launch_session --mux tmux --place tab --quiet -- /bin/echo argument) ]]
  }
  It 'preserves full argv in both forms and returns a TSV result for headless callers'
    When run forms_case
    The status should be success
  End

  selection_case() {
    stub_tmux
    stub_herdr
    export HERDR_ENV=1 HERDR_PANE_ID=w1:p1 HERDR_SESSION=tui
    export TMUX=/tmp/nested,42,0 TMUX_PANE=%5 TMUX_ROWS=$'$3:work\n$4:other'
    [[ $(launch_session --place tab) == $'tmux\t$3\t\t$3:@4.%5' ]] || return 1
    unset TMUX TMUX_PANE
    [[ $(launch_session) == $'herdr\ttui\t\tw1:p1' ]] || return 2
    unset HERDR_ENV HERDR_PANE_ID HERDR_SESSION
    launch_session --mux tmux > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 3 && ! -s $TEST_ROOT/out && $(<"$TEST_ROOT/err") == *--mux-id* ]] || return 3
    [[ $(launch_session --mux tmux --mux-id work --place tab) == $'tmux\t$3\t\t$3:@4.%5' ]] || return 4
    launch_session --host remote > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 3 && ! -s $TEST_ROOT/out && $(<"$TEST_ROOT/err") == *--host* ]] || return 5
    [[ $(launch_session --host build --pwd /work) == $'herdr\ttui\tbuild\tw1:p1' ]] || return 6
    launch_session --mux tmux --host build --pwd /work > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 1 && ! -s $TEST_ROOT/out && $(<"$TEST_ROOT/err") == *'remote'* ]]
  }
  It 'resolves nesting, instance ambiguity, explicit names, and remote capability'
    When run selection_case
    The status should be success
  End

  preference_case() {
    stub_tmux
    stub_herdr
    stub_hc
    mkdir -p "$XDG_CONFIG_HOME/marksharc/hosts"
    export MARKSHARC_HOST=dev TMUX_ROWS='$3:work'
    printf '%s\n' 'set launch.prefer herdr tmux hc' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    printf '%s\n' 'set launch.prefer tmux herdr hc' 'set launch.place hidden' 'set launch.focus off' \
      > "$XDG_CONFIG_HOME/marksharc/hosts/dev.conf"
    local actual
    actual=$(launch_session --dry-run)
    [[ $actual == "'tmux' 'new-window' '-t' '\$3:' '-d'"* ]] || return 1
    unset TMUX_ROWS
    [[ $(launch_session --dry-run) == "'herdr' '--session' 'tui' 'workspace' 'create'"*"'--no-focus'" ]] || return 2
    stub_command herdr 'exit 1'
    [[ $(launch_session --dry-run --mux tmux --mux-id 'my session') == "'tmux' 'new-session' '-d' '-s' 'my session'"* ]] || return 3
    printf '%s\n' 'set launch.prefer herdr hc tmux' > "$XDG_CONFIG_HOME/marksharc/hosts/dev.conf"
    actual=$(launch_session --dry-run --place hidden)
    [[ $actual == "'env' 'HC_SOCKET=' 'HC_SESSION=default' 'hc' 'run'"* && ! -s $OPLOG ]] || return 4
    printf '%s\n' 'set agent.markers CUSTOM_AGENT' >> "$XDG_CONFIG_HOME/marksharc/hosts/dev.conf"
    AI_AGENT=1 CUSTOM_AGENT=1 launch_session --mux tmux --quiet 2> "$TEST_ROOT/err" || return 7
    [[ $(<"$TEST_ROOT/mux-agent-markers") == $'unset\nunset' ]] || return 8
    stub_command tmux 'case "$*" in *list-sessions*) printf "\0443:work\n";; *) exit 7;; esac'
    launch_session --mux tmux --place tab > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 1 && ! -s $TEST_ROOT/out ]] || return 5
    mkdir "$TEST_ROOT/empty-path"
    PATH="$TEST_ROOT/empty-path" launch_session > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 1 && ! -s $TEST_ROOT/out && $(<"$TEST_ROOT/err") == *'no usable multiplexer'* ]]
  }
  It 'applies config, prefers a running kind, autostarts in configured order, and reports failure'
    When run preference_case
    The status should be success
  End

  remote_case() {
    stub_herdr
    stub_tmux
    stub_hc
    start_core_fixture one || return 1
    start_core_fixture two || return 1
    export MARKSHARC_HOST=localbox EMPTY_CORE=one DISPLAY=localhost:11.0 XAUTHORITY=secret SSH_AUTH_SOCK=forwarded
    export TMUX=/tmp/nested,42,0 TMUX_PANE=%5
    local actual
    actual=$(launch_session --mux herdr-core --no-focus --place hidden --dry-run \
      --in-shell 'build:~/some directory' echo $'first\tline\n%' '') || return 2
    [[ $actual == "'env' 'HC_SOCKET=' 'HC_SESSION=two' 'hc' 'run' '--bg' '--no-parent' '--no-notify' '--on' 'peer'"* ]] || return 3
    [[ $actual == *"'LAUNCH_PARENT_SSH_AUTH_SOCK=forwarded'"*"'LAUNCH_PARENT_DISPLAY=localhost:11.0'"* ]] || return 4
    [[ $actual == *"LAUNCH_RUN=echo\\tfirst%09line%0A%25\\t"* && $actual == *"'LAUNCH_RUN_EXEC='"* ]] || return 5
    [[ $actual != *"'DISPLAY="* && $actual != *"'XAUTHORITY="* && $actual != *"'SSH_AUTH_SOCK="* ]] || return 6
    [[ $actual == *"'some directory'"* && ! -s $OPLOG ]] || return 7
    actual=$(launch_session --mux herdr --host build --pwd /work --dry-run -- echo $'first\tline\n%' '') || return 8
    [[ $actual == *"'herdr' '--machine' 'build' 'workspace' 'create' '--cwd' '/work'"* ]] || return 9
    [[ $actual == *"LAUNCH_RUN=echo\\tfirst%09line%0A%25\\t"* && $actual == *"'LAUNCH_RUN_EXEC=1'"* ]] || return 10
    [[ $(launch_session --place workspace --no-focus 'build:~/some directory') == $'hc\ttwo\tpeer\tpeer/t21' ]] || return 11
    launch_session --mux hc --mux-id one --host build > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 1 && ! -s $TEST_ROOT/out && $(<"$TEST_ROOT/err") == *'hc machine add'* ]]
  }
  It 'uses each Core inventory separately and carries encoded commands through the remote adapters'
    Skip if 'python3 is unavailable' no_python
    When run remote_case
    The status should be success
  End

  pty_selection_case() {
    stub_tmux
    stub_herdr
    local cli=$MARKSHARC_ROOT/modules/launch/bin/launch-session actual
    export HERDR_ENV=1 HERDR_PANE_ID=w1:p1 HERDR_SESSION=tui
    export TMUX=/tmp/nested,42,0 TMUX_PANE=%5 TMUX_ROWS='$3:work'
    actual=$("$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "$cli") || return 1
    [[ $actual == $'herdr\ttui\t\tw1:p1' ]] || return 2
    stub_hc
    start_core_fixture one || return 3
    start_core_fixture two || return 3
    unset HERDR_ENV HERDR_PANE_ID HERDR_SESSION
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'set launch.prefer hc tmux' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    stub_command gum 'case "$*" in
      "choose --header Host") tee "$TEST_ROOT/host-menu" | head -n 1 ;;
      *) head -n 1 ;;
    esac'
    actual=$("$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "$cli" --host remote --no-focus) || return 4
    [[ $actual == $'hc\tone\tpeer\tpeer/t21' ]] || return 5
    [[ $(<"$TEST_ROOT/host-menu") == 'peer (dev@build) [hc]' ]]
  }
  It 'ignores a live but foreign tmux pane and uses the picker for host and instance on a terminal'
    Skip if 'python3 is unavailable' no_python
    When run pty_selection_case
    The status should be success
  End
End
