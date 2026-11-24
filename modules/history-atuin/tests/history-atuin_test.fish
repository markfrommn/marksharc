source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

# A fake atuin: init prints a marker, uuid a fixed id, list echoes the session it was given.
ms_stub atuin 'printf "%s\n" "$*" >>"$TEST_ROOT/atuin-calls"
case "$1" in
init) echo "set -g _atuin_init_ran yes" ;;
uuid) echo fresh-uuid ;;
history)
    printf "SESSION=%s\n" "$ATUIN_SESSION"
    printf "t1  one\nt2  two words\nt3  three\n" ;;
esac'

ms_module history-atuin >"$TEST_ROOT/out" 2>&1
@test "startup prints nothing" ! -s "$TEST_ROOT/out"
@test "the cached atuin init was sourced" "$_atuin_init_ran" = yes
@test "init ran 'atuin init fish'" "$(cat "$TEST_ROOT/atuin-calls")" = "init fish"
@test "history and h are defined" (functions -q history h; and echo yes) = yes
@test "fish's own history function is kept, not the module's" (functions _ms_fish_history_native | string match -v -r '^\s*#' | string match -q '*atuin*'; and echo ours; or echo fish) = fish

set -e _atuin_init_ran
ms_module history-atuin
@test "a second load is an init-cache hit" "$(cat "$TEST_ROOT/atuin-calls")" = "init fish"
@test "the cache hit still sources the init" "$_atuin_init_ran" = yes

set -e _atuin_init_ran
set -g _ms_fish_reloading 1
ms_module history-atuin
set -e _ms_fish_reloading
@test "reload does not run the init again" ! (set -q _atuin_init_ran; and echo set)

set -e ATUIN_SESSION
set -l all (history)
@test "history lists every entry, oldest first" (count $all) -eq 4
@test "history lists '<time>  <command>' lines" "$all[3]" = "t2  two words"
@test "history without ATUIN_SESSION passes a fresh session id" "$all[1]" = SESSION=fresh-uuid
set -gx ATUIN_SESSION mine
@test "history keeps the shell's ATUIN_SESSION" (history)[1] = SESSION=mine
@test "history does not export a session it generated" "$ATUIN_SESSION" = mine
set -e ATUIN_SESSION
history >/dev/null
@test "history leaves ATUIN_SESSION unset" ! (set -q ATUIN_SESSION; and echo set)

set -l last (history -2)
@test "history -N shows the last N lines" (count $last) -eq 2
@test "history -N keeps the newest lines" "$last[2]" = "t3  three"
@test "history -1 is one line" (count (history -1)) -eq 1
@test "h shows the last 35 lines (here: all of them)" (count (h)) -eq 4

builtin history clear-session 2>/dev/null
builtin history append "echo fish-native-entry"
set -l native (history search -- fish-native-entry)
@test "other arguments go to fish's own history" "$native" = "echo fish-native-entry"
@test "-N followed by more arguments goes to fish" (count (history search --max 1 -- fish-native-entry)) -eq 1

set -l before (count <"$TEST_ROOT/atuin-calls")
set -l saved $PATH
command rm -f "$TEST_ROOT/bin/atuin"
set -gx PATH "$TEST_ROOT/bin"
set native (history search -- fish-native-entry)
set -gx PATH $saved
@test "without atuin the fish history answers" "$native" = "echo fish-native-entry"
@test "without atuin nothing ran" (count <"$TEST_ROOT/atuin-calls") -eq $before

# Forms the atuin listing does not take reach fish's own history function (its clear asks first).
@test "fish's own history function is kept" (functions -q _ms_fish_history_native; and echo yes) = yes
functions -c _ms_fish_history_native _ms_saved_native
function _ms_fish_history_native
    echo "native $argv"
end
@test "history clear goes to fish's own history function" "$(history clear)" = "native clear"
@test "history delete goes to fish's own history function" "$(history delete --prefix foo)" = "native delete --prefix foo"
functions -e _ms_fish_history_native
functions -c _ms_saved_native _ms_fish_history_native

ms_cleanup
