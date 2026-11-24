source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

set -l initdir "$XDG_CACHE_HOME/marksharc/fixture/init"
ms_stub demo 'printf "%s\n" "$*" >>"$TEST_ROOT/demo-calls"
printf "set -g DEMO_LOADED %s\n" "$*"'

_ms_fish_init_cached demo demo init fish
@test "a miss runs the tool and sources its output" "$DEMO_LOADED" = "init fish"
@test "a miss writes one cache file" (count $initdir/*.fish) -eq 1
set -e DEMO_LOADED
_ms_fish_init_cached demo demo init fish
@test "a hit sources the cached output" "$DEMO_LOADED" = "init fish"
@test "a hit runs nothing" (count <"$TEST_ROOT/demo-calls") -eq 1

command touch -t 200101010000 "$TEST_ROOT/bin/demo"
_ms_fish_init_cached demo demo init fish
@test "a changed binary mtime is a miss" (count <"$TEST_ROOT/demo-calls") -eq 2

_ms_fish_init_cached -k "$HOME/some root" demo demo init fish
@test "an extra key gets its own cache entry" (count $initdir/*.fish) -eq 2

ms_stub quiet 'exit 0'
_ms_fish_init_cached quiet quiet init fish
@test "empty output succeeds" $status -eq 0
@test "empty output is never cached" (count $initdir/quiet__*.fish) -eq 0

ms_stub broken 'echo "set -g BROKEN yes"; exit 3'
_ms_fish_init_cached broken broken init fish
@test "a failing tool returns its status" $status -eq 3
@test "a failing tool's output is not applied" "$BROKEN" = ""
@test "a failing tool caches nothing" (count $initdir/broken__*.fish) -eq 0

_ms_fish_init_cached absent marksharc-no-such-tool init fish
@test "a missing tool returns 1" $status -eq 1

command mkdir -p "$TEST_ROOT/only path"
ms_stub pathy 'printf "set -g SEEN_DIR \"%s\"\n" "$PATH"'
_ms_fish_init_cached -P "$TEST_ROOT/only path" pathy pathy shellenv
@test "-P runs the tool under the given PATH" "$SEEN_DIR" = "$TEST_ROOT/only path"
@test "-P leaves the caller's PATH alone" "$PATH[1]" = "$TEST_ROOT/bin"

ms_stub spaced 'printf "set -g SPACED %s\n" "\"$1\""'
_ms_fish_init_cached spaced spaced 'a b'
@test "arguments with spaces reach the tool" "$SPACED" = "a b"

ms_stub colours 'printf "%s\n" "$*" >>"$TEST_ROOT/colours-calls"
printf "%s\n" "di=01;34:*.tar=01;31 \$(touch x)'"'"'q"'
set -e LS_COLORS
_ms_fish_init_cached -x LS_COLORS colours colours generate
@test "-x sets the output as an exported value" "$LS_COLORS" = "di=01;34:*.tar=01;31 \$(touch x)'q"
@test "-x exports it" (set -S LS_COLORS | string match -q '*exported*'; and echo yes) = yes
set -e LS_COLORS
_ms_fish_init_cached -x LS_COLORS colours colours generate
@test "a -x hit succeeds" $status -eq 0
@test "a -x hit sets the value without running the tool" "$LS_COLORS|"(count <"$TEST_ROOT/colours-calls") = "di=01;34:*.tar=01;31 \$(touch x)'q|1"
_ms_fish_init_cached -x 'a b' colours colours generate
@test "-x refuses a bad name" $status -eq 2

ms_cleanup
