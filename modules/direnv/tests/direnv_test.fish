source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

ms_stub direnv 'printf "%s\n" "$*" >>"$TEST_ROOT/direnv-calls"
case "$*" in
"hook fish") echo "function _marker_direnv; echo direnv-hooked; end" ;;
*) exit 3 ;;
esac'

set -e _ms_opt_direnv_enable
ms_module direnv >"$TEST_ROOT/out" 2>&1
@test "the hook is off by default" ! -e "$TEST_ROOT/direnv-calls"
@test "off by default is quiet" ! -s "$TEST_ROOT/out"

for off in off 0 no false ''
    set -g _ms_opt_direnv_enable "$off"
    ms_module direnv
end
@test "other option values keep the hook off" ! -e "$TEST_ROOT/direnv-calls"

for on in on 1 yes true
    set -g _ms_opt_direnv_enable $on
    functions -e _marker_direnv
    ms_module direnv
    @test "enable=$on installs the hook" "$(_marker_direnv)" = direnv-hooked
end
@test "the hook ran 'direnv hook fish'" "$(sort -u "$TEST_ROOT/direnv-calls")" = "hook fish"
@test "the hook output is cached across loads" (count <"$TEST_ROOT/direnv-calls") -eq 1

set -g _ms_opt_direnv_enable on
functions -e _marker_direnv
set -g _ms_fish_reloading 1
ms_module direnv
set -e _ms_fish_reloading
@test "reload does not install the hook again" ! (functions -q _marker_direnv; and echo yes)

ms_module direnv >"$TEST_ROOT/out" 2>&1
@test "an enabled hook is quiet" ! -s "$TEST_ROOT/out"

set -l saved_path $PATH
command rm -f "$TEST_ROOT/bin/direnv"
set -gx PATH "$TEST_ROOT/bin"
ms_module direnv >"$TEST_ROOT/out" 2>&1
set -l st $status
set -gx PATH $saved_path
@test "a missing direnv breaks nothing" $st -eq 0
@test "a missing direnv prints nothing" ! -s "$TEST_ROOT/out"

ms_cleanup
