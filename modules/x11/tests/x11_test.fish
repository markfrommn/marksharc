source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
# Any probe or delay would be logged.
for tool in sleep ping w tty
    ms_stub $tool 'printf "%s\n" "'$tool' $*" >>"$OPLOG"'
end
ms_module x11

set -gx DISPLAY :7
set -e DISPLAY_ORIG
setup-x11-display
@test "an inherited DISPLAY is kept" "$DISPLAY" = :7
@test "an inherited DISPLAY is remembered as DISPLAY_ORIG" "$DISPLAY_ORIG" = :7
@test "DISPLAY_ORIG is exported" "$(env | string match -r '^DISPLAY_ORIG=.*')" = DISPLAY_ORIG=:7
@test "DISPLAY stays exported" "$(env | string match -r '^DISPLAY=.*')" = DISPLAY=:7

set -gx DISPLAY 'host with space:10.0'
setup-x11-display
@test "a DISPLAY with spaces is remembered whole" "$DISPLAY_ORIG" = 'host with space:10.0'

set -gx DISPLAY ''
set -gx DISPLAY_ORIG stale
setup-x11-display
@test "an empty DISPLAY is dropped" (set -q DISPLAY; echo $status) -eq 1
@test "an empty DISPLAY drops the stale DISPLAY_ORIG" (set -q DISPLAY_ORIG; echo $status) -eq 1

set -e DISPLAY
set -gx DISPLAY_ORIG stale
setup-x11-display
@test "an unset DISPLAY stays unset" (set -q DISPLAY; echo $status) -eq 1
@test "an unset DISPLAY drops the stale DISPLAY_ORIG" (set -q DISPLAY_ORIG; echo $status) -eq 1
setup-x11-display
@test "the function succeeds" $status -eq 0
@test "nothing was probed or slept" ! -s "$OPLOG"

# Startup is quiet; only the verbose trace says anything, on stderr.
set -gx DISPLAY :9
@test "init prints nothing" -z "$(ms_module x11 2>&1)"
@test "init sets DISPLAY_ORIG" "$DISPLAY_ORIG" = :9
set -g _ms_fish_verbose 1
@test "the verbose trace goes to stderr" "$(ms_module x11 2>&1 >/dev/null)" = "marksharc: x11: DISPLAY already set to :9"
@test "the verbose trace stays off stdout" -z "$(ms_module x11 2>/dev/null)"
set -g _ms_fish_verbose 0
set -gx DISPLAY ''
@test "clearing an empty DISPLAY is silent too" -z "$(ms_module x11 2>&1)"
@test "nothing was probed or slept during init" ! -s "$OPLOG"

set -gx LAUNCH_PARENT_HOST (/bin/zsh -f -c 'print -r -- "${HOST%%.*}"')
set -gx LAUNCH_PARENT_DISPLAY :10
set -gx DISPLAY :9
setup-x11-display --startup
@test "startup uses the same-host launch parent display" "$DISPLAY" = :10
@test "the parent display becomes DISPLAY_ORIG" "$DISPLAY_ORIG" = :10
set -gx LAUNCH_PARENT_HOST elsewhere
set -gx DISPLAY :9
setup-x11-display --startup
@test "startup ignores the other-host launch parent display" "$DISPLAY" = :9

ms_cleanup
