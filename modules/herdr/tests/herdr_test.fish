source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

ms_stub herdr 'printf "%s\n" "$*" >>"$TEST_ROOT/herdr-calls"
case "$*" in
"completion fish") echo "complete -c herdr -a pane -d marker" ;;
*) exit 3 ;;
esac'

ms_module herdr >"$TEST_ROOT/out" 2>&1
@test "startup prints nothing" ! -s "$TEST_ROOT/out"
@test "the cached completion was sourced" (complete -C 'herdr ' | string match -q 'pane*'; and echo yes) = yes
@test "init ran 'herdr completion fish'" "$(cat "$TEST_ROOT/herdr-calls")" = "completion fish"

complete -e -c herdr
ms_module herdr
@test "a second load is an init-cache hit" (count <"$TEST_ROOT/herdr-calls") -eq 1
@test "the cache hit still defines the completion" (complete -C 'herdr ' | string match -q 'pane*'; and echo yes) = yes

complete -e -c herdr
set -g _ms_fish_reloading 1
ms_module herdr
set -e _ms_fish_reloading
@test "reload does not source the completion again" -z "$(complete -C 'herdr ' | string match 'pane*')"

# A herdr that cannot print its completion leaves nothing and says nothing.
ms_stub herdr 'exit 1'
command touch -t 200101010000 "$TEST_ROOT/bin/herdr"
ms_module herdr >"$TEST_ROOT/out" 2>&1
set -l st $status
@test "a failing herdr breaks nothing" $st -eq 0
@test "a failing herdr prints nothing" ! -s "$TEST_ROOT/out"
@test "a failing herdr defines no completion" -z "$(complete -C 'herdr ' | string match 'pane*')"

set -l saved_path $PATH
command rm -f "$TEST_ROOT/bin/herdr"
set -gx PATH "$TEST_ROOT/bin"
ms_module herdr >"$TEST_ROOT/out" 2>&1
set st $status
set -gx PATH $saved_path
@test "a missing herdr breaks nothing" $st -eq 0
@test "a missing herdr prints nothing" ! -s "$TEST_ROOT/out"

ms_cleanup
