source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

# A fake starship whose init defines a marker function; calls are logged.
ms_stub starship 'printf "%s\n" "$*" >>"$TEST_ROOT/starship-calls"
case "$*" in
"init fish") echo "function _marker_prompt_starship; echo starship-loaded; end" ;;
*) exit 3 ;;
esac'

ms_module prompt-starship >"$TEST_ROOT/out" 2>&1
@test "startup prints nothing" ! -s "$TEST_ROOT/out"
@test "the cached init was sourced" "$(_marker_prompt_starship)" = starship-loaded
@test "init ran 'starship init fish'" "$(cat "$TEST_ROOT/starship-calls")" = "init fish"

functions -e _marker_prompt_starship
ms_module prompt-starship
@test "a second load is an init-cache hit" (count <"$TEST_ROOT/starship-calls") -eq 1
@test "the cache hit still sources the init" "$(_marker_prompt_starship)" = starship-loaded

functions -e _marker_prompt_starship
set -g _ms_fish_reloading 1
ms_module prompt-starship
set -e _ms_fish_reloading
@test "reload does not source the init again" ! (functions -q _marker_prompt_starship; and echo yes)

ms_stub starship 'exit 1'
command touch -t 200101010000 "$TEST_ROOT/bin/starship"
ms_module prompt-starship >"$TEST_ROOT/out" 2>&1
set -l st $status
@test "a failing init breaks nothing" $st -eq 0
@test "a failing init prints nothing" ! -s "$TEST_ROOT/out"

command rm -f "$TEST_ROOT/bin/starship"
set -l saved_path $PATH
set -gx PATH "$TEST_ROOT/bin"
ms_module prompt-starship >"$TEST_ROOT/out" 2>&1
set -l st $status
set -gx PATH $saved_path
@test "a missing starship breaks nothing" $st -eq 0
@test "a missing starship prints nothing" ! -s "$TEST_ROOT/out"

ms_cleanup
