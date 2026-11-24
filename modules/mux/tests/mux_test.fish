source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
ms_module mux

@test "fix-tmux is autoloaded" (functions -q fix-tmux; echo $status) -eq 0

set -e TMUX
@test "outside tmux it says so" "$(fix-tmux)" = "Not in tmux"
fix-tmux >/dev/null
@test "outside tmux it succeeds" $status -eq 0

# tmux show-environment output: NAME=value and -NAME lines, values are data.
ms_stub tmux 'if [ "$1" = show-environment ]; then
    printf "%s\n" "FIXED_BY_TMUX=two words" "SSH_AUTH_SOCK=/tmp/ssh dir/agent.1" \
        "TRICKY=a=b \$HOME \$(touch $TEST_ROOT/pwned); echo hi" "EMPTY=" "-GONE" "-never_set" \
        "X_PATH=$TEST_ROOT/x dir:$TEST_ROOT/y" "PWD=/nonsense" "1BAD=x" "not a line"
fi'
set -gx TMUX /tmp/fixture,1,0
set -gx GONE old
set -gx SSH_AUTH_SOCK /old/agent
set -l before_pwd "$PWD"
fix-tmux
@test "a NAME=value line sets the variable" "$FIXED_BY_TMUX" = "two words"
@test "the variable is exported" "$(env | string match -r '^FIXED_BY_TMUX=.*')" = "FIXED_BY_TMUX=two words"
@test "a stale SSH_AUTH_SOCK is replaced (spaces kept)" "$SSH_AUTH_SOCK" = "/tmp/ssh dir/agent.1"
@test "values are data, never evaluated" "$TRICKY" = 'a=b $HOME $(touch '"$TEST_ROOT"'/pwned); echo hi'
@test "nothing was executed" ! -e "$TEST_ROOT/pwned"
@test "an empty value is an empty variable" (set -q EMPTY; echo $status) -eq 0 -a -z "$EMPTY"
@test "a -NAME line erases the variable" (set -q GONE; echo $status) -eq 1
@test "a path variable becomes a list" (count $X_PATH) -eq 2
@test "the path entries keep their spaces" "$X_PATH[1]" = "$TEST_ROOT/x dir"
@test "PWD is not touched" "$PWD" = "$before_pwd"
@test "a bad name is ignored" (set -q 1BAD; echo $status) -eq 1
@test "an unparsable line is ignored" (count (set -n | string match 'not*')) -eq 0

@test "fix-tmux prints nothing inside tmux" -z "$(fix-tmux 2>&1)"

# PATH itself is imported as a list too.
set -l saved_path $PATH
ms_stub tmux 'printf "%s\n" "PATH=/imported/one:/imported/two dir"'
fix-tmux
set -l imported $PATH
set -gx PATH $saved_path
@test "PATH from tmux becomes the fish PATH list" "$imported[1]|$imported[2]" = "/imported/one|/imported/two dir"
@test "init needs no module init file" ! -e "$MARKSHARC_ROOT/modules/mux/init.fish"

ms_cleanup
