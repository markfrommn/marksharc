source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
# The function only; the module's init.fish would look at the real brew locations.
set -gp fish_function_path "$MARKSHARC_ROOT/modules/brew/functions/fish"

# A fake brew at a temporary path (the fixture's forbidden brew stub is never used).
set -g FAKE "$TEST_ROOT/prefix with space"
command mkdir -p "$FAKE/bin" "$FAKE/sbin"
set -g FAKEBREW "$FAKE/bin/brew"
printf '%s\n' '#!/bin/sh' \
    'echo "brew $* PATH=$PATH" >>"$OPLOG"' \
    'if [ "$1" = shellenv ]; then' \
    '  echo "set --global --export HOMEBREW_PREFIX \"'"$FAKE"'\";"' \
    '  echo "fish_add_path --global --move --path \"'"$FAKE"'/bin\" \"'"$FAKE"'/sbin\";"' \
    fi >"$FAKEBREW"
command chmod +x "$FAKEBREW"

set -g keep /opt/keep-one /opt/keep-two
set -gx PATH "$TEST_ROOT/bin" $keep /usr/bin /bin
set -l before $PATH
setup-homebrew "$FAKEBREW" >"$TEST_ROOT/out" 2>&1
@test "activation is quiet" ! -s "$TEST_ROOT/out"
@test "shellenv variables are applied" "$HOMEBREW_PREFIX" = "$FAKE"
@test "the new brew directories go in front" (string join '|' -- $PATH[1..2]) = "$FAKE/bin|$FAKE/sbin"
@test "the existing PATH order is kept behind them" (string join '|' -- $PATH[3..]) = (string join '|' -- $before)
@test "shellenv ran under the fixed minimal PATH" (count (string match -- '*PATH=/usr/bin:/bin:/usr/sbin:/sbin' <"$OPLOG")) -eq 1

# Brew directories already present keep their place; only absent ones move to the front.
set -gx PATH "$TEST_ROOT/bin" $keep "$FAKE/sbin" /usr/bin /bin
set before $PATH
setup-homebrew "$FAKEBREW"
@test "a directory already on PATH keeps its position" (string join '|' -- $PATH) = (string join '|' -- "$FAKE/bin" $before)

# Second run reads the cache and does not run brew shellenv again.
printf '' >"$OPLOG"
set -e HOMEBREW_PREFIX
setup-homebrew "$FAKEBREW"
@test "a cache hit applies the same variables" "$HOMEBREW_PREFIX" = "$FAKE"
@test "a cache hit does not run brew" ! -s "$OPLOG"

# A missing candidate is skipped; the first existing one wins.
set -e HOMEBREW_PREFIX
set -gx PATH "$TEST_ROOT/bin" /usr/bin /bin
setup-homebrew "$TEST_ROOT/none/brew" "$FAKEBREW"
@test "a missing candidate is skipped" "$HOMEBREW_PREFIX" = "$FAKE"
@test "a directory is never a candidate" (setup-homebrew "$FAKE/bin"; echo $status) = 0

# No brew at all: success and nothing changes.
set -e HOMEBREW_PREFIX
set -l path_before $PATH
setup-homebrew "$TEST_ROOT/none/brew"
@test "no brew is not an error" $status -eq 0
@test "no brew changes nothing" (string join '|' -- $PATH) = (string join '|' -- $path_before)
@test "no brew sets nothing" -z "$HOMEBREW_PREFIX"

# A failing brew reports its status and PATH keeps its order.
ms_stub failbrew 'exit 3'
setup-homebrew "$TEST_ROOT/bin/failbrew"
@test "a failing brew returns its status" $status -eq 3
@test "a failing brew leaves PATH alone" (string join '|' -- $PATH) = (string join '|' -- $path_before)

# Reload: the shell's brew environment is left alone.
printf '' >"$OPLOG"
set -e HOMEBREW_PREFIX
set -g _ms_fish_reloading 1
setup-homebrew "$FAKEBREW"
set -e _ms_fish_reloading
@test "a reload does not activate brew again" -z "$HOMEBREW_PREFIX"
@test "a reload does not run brew" ! -s "$OPLOG"

# init.fish: the fixed candidates only; on a host that has one of them the real brew would
# run, so only check the quiet no-brew case.
if not test -e /usr/local/bin/brew -o -e /opt/homebrew/bin/brew -o -e /home/linuxbrew/.linuxbrew/bin/brew
    set path_before $PATH
    ms_module brew >"$TEST_ROOT/out" 2>&1
    @test "init without brew is quiet" ! -s "$TEST_ROOT/out"
    @test "init without brew changes nothing" (string join '|' -- $PATH) = (string join '|' -- $path_before)
end

ms_cleanup
