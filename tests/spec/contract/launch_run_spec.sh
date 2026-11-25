Describe 'launch run after init'
  launch_fixture() {
    config="$XDG_CONFIG_HOME/marksharc"
    fixture="$config/modules/launch-fixture"
    mkdir -p "$fixture" "$config/local" "$XDG_CONFIG_HOME/fish/conf.d"
    printf '%s\n' 'module launch' 'module launch-fixture' > "$config/config.conf"
    printf '%s\n' 'describe "Launch test fixture"' 'order 99' > "$fixture/module.conf"
    printf '%s\n' 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' > "$HOME/.zshenv"
    printf '%s\n' 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"' > "$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish"
    cat > "$fixture/init.zsh" <<'EOF'
export FIXTURE_SHELL_PID=$$
launch-fixture-run() { launch-fixture-record "$@"; }
_launch_fixture_prompt() { : > "$FIXTURE_PROMPT"; }
autoload -Uz add-zsh-hook
add-zsh-hook precmd _launch_fixture_prompt
EOF
    cat > "$fixture/init.fish" <<'EOF'
set -gx FIXTURE_SHELL_PID $fish_pid
function launch-fixture-run
    launch-fixture-record $argv
end
function fish_prompt
    true > "$FIXTURE_PROMPT"
    printf '> '
end
EOF
    printf '%s\n' 'export FIXTURE_READY=zsh' > "$config/local/post.zsh"
    printf '%s\n' 'set -gx FIXTURE_READY fish' > "$config/local/post.fish"
    stub_command launch-fixture-record '
      [ -n "$FIXTURE_READY" ] && [ ! -e "$FIXTURE_PROMPT" ] || exit 90
      [ -z "${LAUNCH_RUN+x}${LAUNCH_RUN_EXEC+x}" ] || exit 91
      if [ "$FIXTURE_EXEC" = 1 ]; then
        [ "$$" = "$FIXTURE_SHELL_PID" ] || exit 92
      fi
      printf "%s\0" "$FIXTURE_READY" "$@" >> "$FIXTURE_LOG"
      exit "$FIXTURE_EXEC"
    '
    # Fish requires a controlling TTY for interactive job control. The shared
    # PTY helper gives its new session a slave descriptor without assigning it.
    tty_fixture='
import fcntl
import os
import sys
import termios

fcntl.ioctl(0, termios.TIOCSCTTY, 0)
os.execv(sys.argv[1], sys.argv[1:])
'
  }

  launch_env() {
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 \
      FIXTURE_LOG="$TEST_ROOT/run" FIXTURE_PROMPT="$TEST_ROOT/prompt" "$@"
  }

  launch_interactive_case() {
    shell=$1
    executable=$(command -v "$shell") || return 1
    launch_fixture
    run=$(printf '%s\t%s\t%s\t%s\t%s\t' launch-fixture-run --flag '' \
      'space; $HOME "quote" \literal %250A' 'tab%09line%0A%0A')
    typed=$(printf '%s\n' 'marksharc reload && echo resumed > "$FIXTURE_LOG.resume"' 'exit'; printf .)
    typed=${typed%.}
    launch_env LAUNCH_RUN="$run" LAUNCH_RUN_EXEC='' FIXTURE_EXEC=0 PTY_INPUT="$typed" \
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "$PYTHON" -c "$tty_fixture" "$executable" -il \
      > "$TEST_ROOT/terminal" 2>&1 || { cat "$TEST_ROOT/terminal"; return 2; }
    line=$(printf 'tab\tline\n\n.')
    printf '%s\0' "$shell" --flag '' 'space; $HOME "quote" \literal %0A' \
      "${line%.}" '' > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$TEST_ROOT/run" || { cat "$TEST_ROOT/terminal"; return 3; }
    grep -qx resumed "$TEST_ROOT/run.resume"
  }

  launch_exec_case() {
    shell=$1
    executable=$(command -v "$shell") || return 1
    launch_fixture
    run=$(printf 'launch-fixture-record\t%%25\t')
    typed=$(printf 'exit 88\n.')
    typed=${typed%.}
    launch_env LAUNCH_RUN="$run" LAUNCH_RUN_EXEC=1 FIXTURE_EXEC=1 PTY_INPUT="$typed" \
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "$PYTHON" -c "$tty_fixture" "$executable" -il \
      > "$TEST_ROOT/terminal" 2>&1
    [ "$?" -eq 1 ] || { cat "$TEST_ROOT/terminal"; return 2; }
    [ ! -e "$TEST_ROOT/prompt" ] || return 3
    printf '%s\0' "$shell" '%' '' > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$TEST_ROOT/run"
  }

  launch_skips_case() {
    shell=$1
    executable=$(command -v "$shell") || return 1
    launch_fixture
    run=launch-fixture-run
    launch_env LAUNCH_RUN="$run" LAUNCH_RUN_EXEC=1 FIXTURE_EXEC=1 \
      "$executable" -c 'echo "$MARKSHARC_SESSION:$LAUNCH_RUN:$LAUNCH_RUN_EXEC"' < /dev/null \
      > "$TEST_ROOT/batch" 2>&1 || return 2
    grep -qx 'batch:launch-fixture-run:1' "$TEST_ROOT/batch" || { cat "$TEST_ROOT/batch"; return 3; }
    typed=$(printf '%s\n' 'echo "$MARKSHARC_SESSION:$LAUNCH_RUN:$LAUNCH_RUN_EXEC" > "$FIXTURE_LOG.class"' 'exit'; printf .)
    typed=${typed%.}
    launch_env LAUNCH_RUN="$run" LAUNCH_RUN_EXEC=1 FIXTURE_EXEC=1 AI_AGENT=fixture PTY_INPUT="$typed" \
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "$PYTHON" -c "$tty_fixture" "$executable" -il \
      > "$TEST_ROOT/agent" 2>&1 || { cat "$TEST_ROOT/agent"; return 4; }
    grep -qx 'agent:launch-fixture-run:1' "$TEST_ROOT/run.class" || { cat "$TEST_ROOT/agent"; return 5; }
    [ ! -e "$TEST_ROOT/run" ]
  }

  Context 'each native shell'
    Parameters:value zsh fish
    It 'runs a shell function once after init and preserves every argument across reload'
      When run launch_interactive_case "$1"
      The status should be success
    End
    It 'executes the program in the shell process with the launch variables erased'
      When run launch_exec_case "$1"
      The status should be success
    End
    It 'leaves the launch variables alone in batch and agent sessions'
      When run launch_skips_case "$1"
      The status should be success
    End
  End
End
