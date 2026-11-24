source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
ms_stub fortune 'printf "%s\n" "a fortune for you"; printf x >>"$TEST_ROOT/fortune-runs"'
function runs
    test -e "$TEST_ROOT/fortune-runs"; and string length -- (cat "$TEST_ROOT/fortune-runs"); or echo 0
end

@test "the greeting is off by default" -z "$(ms_module greeting 2>&1)"
@test "fortune did not run by default" (runs) -eq 0

for value in off 0 no false ''
    set -g _ms_opt_greeting_fortune "$value"
    @test "fortune stays off for '$value'" -z "$(ms_module greeting 2>&1)"
end
@test "fortune did not run for any off value" (runs) -eq 0

for value in on 1 yes true
    set -g _ms_opt_greeting_fortune "$value"
    @test "fortune runs once for '$value'" "$(ms_module greeting 2>&1)" = "a fortune for you"
end
@test "fortune ran once per enabled value" (runs) -eq 4

set -g _ms_opt_greeting_fortune on
set -g _ms_fish_reloading 1
@test "fortune never runs on reload" -z "$(ms_module greeting 2>&1)"
set -e _ms_fish_reloading
@test "reload did not run fortune" (runs) -eq 4

ms_stub fortune 'exit 3'
ms_module greeting
@test "a failing fortune does not fail init" $status -eq 0

ms_cleanup
