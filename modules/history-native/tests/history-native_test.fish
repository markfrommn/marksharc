source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

# Fish's own history is the store; the module only adds h, and only without atuin.
set -l saved_path $PATH
set -gx PATH "$TEST_ROOT/bin"
ms_module history-native >"$TEST_ROOT/out" 2>&1
set -gx PATH $saved_path
@test "startup prints nothing" ! -s "$TEST_ROOT/out"
@test "h is defined without atuin" (functions -q h; and echo yes) = yes

for n in 1 2 3
    builtin history append "echo native $n"
end
set -l last (h)
@test "h lists entries" (count $last) -ge 3
@test "h lists oldest first" "$last[-3..-1]" = "echo native 1 echo native 2 echo native 3"

for n in (seq 4 40)
    builtin history append "echo native $n"
end
@test "h is limited to 35 entries" (count (h)) -eq 35
@test "h ends with the newest entry" (h)[-1] = "echo native 40"

# With atuin on PATH the history-atuin module owns h: this module defines nothing.
functions -e h
ms_stub atuin 'exit 99'
ms_module history-native
@test "with atuin present h is left to history-atuin" ! (functions -q h; and echo yes)
@test "history-native never runs atuin" ! -s "$OPLOG"

ms_cleanup
