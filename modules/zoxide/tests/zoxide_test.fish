source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

# A fake zoxide whose init defines a marker function; calls are logged.
ms_stub zoxide 'printf "%s\n" "$*" >>"$TEST_ROOT/zoxide-calls"
case "$*" in
"init fish") echo "function _marker_zoxide; echo zoxide-loaded; end" ;;
*) exit 3 ;;
esac'

# A tool in a directory with spaces.
command mkdir -p "$TEST_ROOT/tool dir"
command mv "$TEST_ROOT/bin/zoxide" "$TEST_ROOT/tool dir/zoxide"
set -gx PATH "$TEST_ROOT/tool dir" $PATH

ms_module zoxide >"$TEST_ROOT/out" 2>&1
@test "startup prints nothing" ! -s "$TEST_ROOT/out"
@test "the cached init was sourced" "$(_marker_zoxide)" = zoxide-loaded
@test "init ran 'zoxide init fish'" "$(cat "$TEST_ROOT/zoxide-calls")" = "init fish"
@test "the init cache lives under the XDG cache" (count "$XDG_CACHE_HOME"/marksharc/fixture/init/zoxide__*.fish) -eq 1

functions -e _marker_zoxide
ms_module zoxide
@test "a second load is an init-cache hit" (count <"$TEST_ROOT/zoxide-calls") -eq 1

functions -e _marker_zoxide
set -g _ms_fish_reloading 1
ms_module zoxide
set -e _ms_fish_reloading
@test "reload does not source the init again" ! (functions -q _marker_zoxide; and echo yes)

set -l saved_path $PATH
set -gx PATH "$TEST_ROOT/bin"
ms_module zoxide >"$TEST_ROOT/out" 2>&1
set -l st $status
set -gx PATH $saved_path
@test "a missing zoxide breaks nothing" $st -eq 0
@test "a missing zoxide prints nothing" ! -s "$TEST_ROOT/out"

ms_cleanup
