Describe 'Bash sync notification and greeting'
  Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
  Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"

  startup_fixture() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config with spaces"
    mkdir -p "$MARKSHARC_CONFIG"
    printf '%s\n' 'module greeting' 'module ssh-agent off' > "$MARKSHARC_CONFIG/config.conf"
    cat > "$HOME/.bashrc" <<'EOF'
PS1='ready> '
source "$MARKSHARC_HOME/core/bash/bashrc.bash"
EOF
    stub_command fortune 'printf "fixture fortune\n"'
    stub_command nohup 'printf "%s\n" "$*" >> "$TEST_ROOT/notify"'
  }

  startup_terminal() {
    PTY_INPUT='if [[ $MARKSHARC_SESSION == interactive ]]; then marksharc reload || exit 7; fi
exit 0
' "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty \
      "${MARKSHARC_TEST_BASH:-bash}" --noprofile -i > "$TEST_ROOT/terminal" 2>&1 ||
      { cat "$TEST_ROOT/terminal"; return 1; }
  }

  notify_fixture() {
    startup_fixture
    "$MARKSHARC_HOME/bin/marksharc" render >/dev/null || return 1
    sync_dir="$XDG_CACHE_HOME/marksharc/$(hostname -s)/sync"
    mkdir -p "$sync_dir"
    printf '%s\n' 'fixture-generation' > "$sync_dir/generation"
    printf '%s\n' 'behind|fixture-generation' > "$sync_dir/status"
    date +%s > "$sync_dir/checked"
  }

  notice_case() {
    notify_fixture || return 1
    MARKSHARC_NOTIFY=1 startup_terminal || return 2
    [ "$(grep -c '^marksharc: updates available (run marksharc sync)' "$TEST_ROOT/terminal")" = 1 ] &&
      [ ! -e "$TEST_ROOT/notify" ] || { cat "$TEST_ROOT/terminal"; return 3; }
  }

  detached_case() {
    notify_fixture || return 1
    printf '%s\n' 'set sync.check_hours 0' >> "$MARKSHARC_CONFIG/config.conf"
    printf '%s\n' 'behind|stale-generation' > "$sync_dir/status"
    "$MARKSHARC_HOME/bin/marksharc" render >/dev/null || return 1
    MARKSHARC_NOTIFY=1 startup_terminal || return 2
    # Allow the detached stub to be scheduled before inspecting its log.
    for attempt in 1 2 3 4 5 6 7 8 9 10; do
      [ -s "$TEST_ROOT/notify" ] && break
      sleep 0.1
    done
    printf '%s\n' "zsh -f $MARKSHARC_HOME/core/cli/notify --check" > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$TEST_ROOT/notify" &&
      ! grep -Eq '^marksharc: updates available|^\[[0-9]' "$TEST_ROOT/terminal"
  }

  quiet_case() {
    notify_fixture || return 1
    printf '%s\n' 'set sync.check_hours 0' >> "$MARKSHARC_CONFIG/config.conf"
    if [ "$1" = opted-out ]; then
      MARKSHARC_NOTIFY=0 startup_terminal || return 2
    else
      printf '%s\n' 'set greeting.fortune on' >> "$MARKSHARC_CONFIG/config.conf"
      MARKSHARC_NOTIFY=1 AI_AGENT=fixture startup_terminal || return 3
      MARKSHARC_NOTIFY=1 "${MARKSHARC_TEST_BASH:-bash}" --noprofile -ic \
        '. "$HOME/.bashrc"' </dev/null >> "$TEST_ROOT/terminal" 2>&1 || return 4
    fi
    [ ! -e "$TEST_ROOT/notify" ] &&
      ! grep -Eq '^marksharc: updates available|^fixture fortune' "$TEST_ROOT/terminal"
  }

  greeting_case() {
    startup_fixture
    MARKSHARC_NOTIFY=0 startup_terminal || return 1
    ! grep -q '^fixture fortune' "$TEST_ROOT/terminal" || return 2
    printf '%s\n' 'set greeting.fortune on' >> "$MARKSHARC_CONFIG/config.conf"
    "$MARKSHARC_HOME/bin/marksharc" render >/dev/null || return 2
    MARKSHARC_NOTIFY=0 startup_terminal || return 3
    [ "$(grep -c '^fixture fortune' "$TEST_ROOT/terminal")" = 1 ] ||
      { cat "$TEST_ROOT/terminal"; return 4; }
  }

  It 'displays a matching cached notice once with no fetch during the throttle window'
    When run notice_case
    The status should be success
  End

  It 'starts one detached check after the configured interval and hides a stale notice'
    When run detached_case
    The status should be success
  End

  It 'suppresses notice and fetch when opted out'
    When run quiet_case opted-out
    The status should be success
  End

  It 'suppresses notice, fetch, and fortune in agent and no-TTY sessions'
    When run quiet_case ineligible
    The status should be success
  End

  It 'prints an opt-in fortune once per eligible shell'
    When run greeting_case
    The status should be success
  End
End
