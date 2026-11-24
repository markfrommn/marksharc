source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
ms_module mux

@test "fix-tmux still reports when outside tmux" "$(fix-tmux)" = 'Not in tmux'

set -gx AUTH_PAYLOAD 'literal \$HOME \$(touch '"$TEST_ROOT"'/pwned)'
ms_stub tmux 'test "$*" = "show-environment -s -t %7" || exit 1
if [ -e "$TEST_ROOT/no-display" ]; then
    printf "unset DISPLAY;\n"
else
    printf "DISPLAY=\"localhost:12.0\"; export DISPLAY;\n"
fi
printf "XAUTHORITY=\"%s\"; export XAUTHORITY;\n" "$AUTH_PAYLOAD"
printf "unset SSH_AUTH_SOCK;\n"'
set -gx TMUX /tmp/fixture,1,0
set -gx TMUX_PANE %7
set -gx DISPLAY localhost:10.0
set -gx SSH_AUTH_SOCK /missing
set -gx SSH_AGENT_PID 99
ms_module mux
@test "init imports the client display" "$DISPLAY|$DISPLAY_ORIG" = 'localhost:12.0|localhost:12.0'
@test "values remain literal" "$XAUTHORITY" = 'literal $HOME $(touch '"$TEST_ROOT"'/pwned)'
@test "no shell code ran" ! -e "$TEST_ROOT/pwned"
@test "the disconnected agent and its PID are cleared" -z "$SSH_AUTH_SOCK$SSH_AGENT_PID"

set -gx DISPLAY :99
emit fish_preexec 'ssh example.invalid'
@test "an unchanged attach preserves an explicit shell override" "$DISPLAY" = :99
command touch "$TEST_ROOT/no-display"
emit fish_preexec 'ssh example.invalid'
@test "the reattached shell sees a removed display before the next command" -z "$DISPLAY$DISPLAY_ORIG"
@test "manual refresh is quiet" -z "$(refresh-env client 2>&1)"

ms_cleanup
