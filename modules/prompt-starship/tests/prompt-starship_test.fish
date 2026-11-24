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

# prompt-starship.config: a bundled preset name or a file; only this module's value is removed.
ms_stub starship 'exit 0'
set -e STARSHIP_CONFIG
set -g _ms_fish_reloading 1
set -g _ms_opt_prompt_starship_config rich
ms_module prompt-starship
@test "a preset name selects the bundled preset" "$STARSHIP_CONFIG" = "$MARKSHARC_ROOT/modules/prompt-starship/presets/rich.toml"
@test "STARSHIP_CONFIG is exported" (set -S STARSHIP_CONFIG | string match -q '*exported*'; and echo yes) = yes
set -g _ms_opt_prompt_starship_config nosuch
ms_module prompt-starship
@test "an unknown preset leaves STARSHIP_CONFIG unset" (set -q STARSHIP_CONFIG; and echo set; or echo unset) = unset
printf 'x = 1\n' >"$HOME/my.toml"
set -g _ms_opt_prompt_starship_config '~/my.toml'
ms_module prompt-starship
@test "a ~ path selects that file" "$STARSHIP_CONFIG" = "$HOME/my.toml"
set -g _ms_opt_prompt_starship_config ''
ms_module prompt-starship
@test "an empty option removes the value this module set" (set -q STARSHIP_CONFIG; and echo set; or echo unset) = unset
set -gx STARSHIP_CONFIG /user.toml
ms_module prompt-starship
@test "a value the module did not set is kept" "$STARSHIP_CONFIG" = /user.toml
set -e _ms_fish_reloading _ms_opt_prompt_starship_config STARSHIP_CONFIG

ms_cleanup
