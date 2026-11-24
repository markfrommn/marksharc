source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

function marker_runs
    set -q _cnf_marker; and echo $_cnf_marker; or echo 0
end
function make_prefix --argument-names prefix
    command mkdir -p -- "$prefix/bin" "$prefix/Library/Homebrew/command-not-found"
    printf '#!/bin/sh\nprintf "%%s\\n" "$*" >>"$OPLOG"\n' >"$prefix/bin/brew"
    command chmod +x "$prefix/bin/brew"
    printf 'set -g _cnf_marker (math (string join "" -- "0" $_cnf_marker) + 1)\nset -g _cnf_source "%s"\n' "$prefix" >"$prefix/Library/Homebrew/command-not-found/handler.fish"
end

set -e _cnf_marker
@test "without brew init is quiet" -z "$(ms_module command-not-found 2>&1)"
ms_module command-not-found
@test "without brew no handler is sourced" (marker_runs) -eq 0

# brew is a symlink into a prefix whose path has a space (the Intel layout).
set -l prefix "$TEST_ROOT/brew prefix/Homebrew"
make_prefix "$prefix"
command ln -sf "$prefix/bin/brew" "$TEST_ROOT/bin/brew"
@test "init with brew is quiet" -z "$(ms_module command-not-found 2>&1)"
set -e _cnf_marker
ms_module command-not-found
@test "Homebrew's handler.fish is sourced from the resolved prefix" "$_cnf_source" = "$prefix"
@test "the handler is sourced once per init" (marker_runs) -eq 1
@test "brew itself is never run" ! -s "$OPLOG"
ms_module command-not-found
@test "init again sources it again (idempotent definitions)" (marker_runs) -eq 2

# A brew without the handler file leaves fish's own handler alone.
set -e _cnf_marker
set -e _cnf_source
command rm "$prefix/Library/Homebrew/command-not-found/handler.fish"
@test "a missing handler.fish is quiet" -z "$(ms_module command-not-found 2>&1)"
ms_module command-not-found
@test "a missing handler.fish sources nothing" (marker_runs) -eq 0
@test "fish's native handler stays defined" (functions -q fish_command_not_found; echo $status) -eq 0

# brew as a plain executable (the Apple Silicon layout, prefix is the repository).
command rm "$TEST_ROOT/bin/brew"
set -l direct "$TEST_ROOT/opt homebrew"
make_prefix "$direct"
command ln -sf "$direct/bin/brew" "$TEST_ROOT/bin/brew"
ms_module command-not-found
@test "a brew in the prefix itself works" "$_cnf_source" = "$direct"

ms_cleanup
