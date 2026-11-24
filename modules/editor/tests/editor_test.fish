source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
# Only the stub bin is searched while the module runs, so a host emacs never changes the
# result; the full PATH is back for the helpers.
function init_editor
    set -l saved $PATH
    set -gx PATH "$TEST_ROOT/bin"
    ms_module editor
    set -l result $status
    set -gx PATH $saved
    return $result
end

init_editor >"$TEST_ROOT/out" 2>&1
@test "startup is quiet" ! -s "$TEST_ROOT/out"
@test "without emacs or an option EDITOR is vi" "$EDITOR" = vi
@test "EDITOR is exported" "$(set -qx EDITOR; and echo yes)" = yes

ms_stub emacs 'exit 0'
init_editor
@test "with emacs installed EDITOR is emacs -nw" "$EDITOR" = "emacs -nw"

set -g _ms_opt_editor_command 'code --wait'
init_editor
@test "the option wins over emacs and keeps its arguments" "$EDITOR" = "code --wait"
@test "the option value stays one word" (count $EDITOR) -eq 1

set -g _ms_opt_editor_command '/opt/my editors/ed'
init_editor
@test "an option with a space in its path is kept whole" "$EDITOR" = "/opt/my editors/ed"

set -g _ms_opt_editor_command ''
set -g _ms_fish_reloading 1
init_editor >"$TEST_ROOT/out" 2>&1
set -e _ms_fish_reloading
@test "an empty option falls back to emacs on reload" "$EDITOR" = "emacs -nw"
@test "a reload is quiet" ! -s "$TEST_ROOT/out"

command rm -f "$TEST_ROOT/bin/emacs"
set -e _ms_opt_editor_command
init_editor
@test "an unset option and no emacs returns to vi" "$EDITOR" = vi

ms_cleanup
