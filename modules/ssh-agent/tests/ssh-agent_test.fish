source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

# The write-once executable is a stub that records how it was called and applies a directive.
ms_stub setup-ssh-agent 'printf "%s|%s\n" "$MARKSHARC_SESSION" "$*" >>"$TEST_ROOT/ssh-calls"
printf "setenv\tSSH_AUTH_SOCK\t%s\n" "$TEST_ROOT/dir with space/agent.sock" >>"$MARKSHARC_DIRECTIVES"
printf "setenv\tSSH_AGENT_PID\t4242\n" >>"$MARKSHARC_DIRECTIVES"'

ms_module ssh-agent >"$TEST_ROOT/out" 2>&1
@test "startup prints nothing" ! -s "$TEST_ROOT/out"
@test "setup-ssh-agent ran once in an interactive session" "$(cat "$TEST_ROOT/ssh-calls")" = "interactive|"
@test "its setenv directive reached this shell" "$SSH_AUTH_SOCK" = "$TEST_ROOT/dir with space/agent.sock"
@test "its other directive reached this shell" "$SSH_AGENT_PID" = 4242

set -e SSH_AUTH_SOCK
set -g _ms_fish_reloading 1
ms_module ssh-agent
set -e _ms_fish_reloading
@test "reload does not set up the agent again" (count <"$TEST_ROOT/ssh-calls") -eq 1
@test "reload leaves the environment alone" ! (set -q SSH_AUTH_SOCK; and echo set)

# A failing setup never breaks startup and prints nothing of its own.
ms_stub setup-ssh-agent 'exit 1'
ms_module ssh-agent >"$TEST_ROOT/out" 2>&1
set -l st $status
@test "a failing setup breaks nothing" $st -eq 0
@test "a failing setup is quiet" ! -s "$TEST_ROOT/out"

ms_cleanup
