source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

# The command line and the pager belong to the interactive reader: fake them.
set -g FAKE_LINE ''
set -g FAKE_PAGING 0
function commandline
    if contains -- --paging-mode $argv
        test "$FAKE_PAGING" = 1
        return
    end
    if test "$argv[1]" = -f
        printf '%s\n' "$argv[2..]" >>"$TEST_ROOT/commandline"
        return 0
    end
    printf '%s' "$FAKE_LINE"
end

@test "init prints nothing" -z "$(ms_module nav 2>&1)"
ms_module nav
ms_module nav
@test "Alt-Up is bound in the default mode" "$(bind -M default alt-up)" = "bind alt-up _ms_nav_up"
@test "Alt-Up is bound in the insert mode" "$(bind -M insert alt-up)" = "bind -M insert alt-up _ms_nav_up"
@test "Alt-Down is bound in the default mode" "$(bind -M default alt-down)" = "bind alt-down _ms_nav_down"
@test "Alt-Down is bound in the insert mode" "$(bind -M insert alt-down)" = "bind -M insert alt-down _ms_nav_down"
@test "Alt-Left stays with fish" -z "$(bind --user -M default alt-left 2>/dev/null | string match '*_ms_nav*')"
@test "Alt-Right stays with fish" -z "$(bind --user -M default alt-right 2>/dev/null | string match '*_ms_nav*')"
@test "only Alt-Up and Alt-Down are bound" (bind --user | string match '*_ms_nav*' | count) -eq 4

set -l tree "$TEST_ROOT/tree dir"
command mkdir -p -- "$tree/mid dir/.hidden" "$tree/mid dir/Zed" "$tree/mid dir/alpha" "$tree/mid dir/-dash" "$tree/empty"
command touch "$tree/mid dir/file"
command ln -s "$tree/empty" "$tree/mid dir/link"

# Names are compared byte by byte, so '-' sorts before '.', then upper case, then lower case.
cd "$tree/mid dir"
@test "the first child is the first in byte order, dotted names included" "$(_ms_nav_first_child)" = -dash
command rmdir "$tree/mid dir/-dash"
@test "dotted directories come before letters" "$(_ms_nav_first_child)" = .hidden
command rmdir "$tree/mid dir/.hidden"
@test "upper case sorts before lower case" "$(_ms_nav_first_child)" = Zed
command rmdir "$tree/mid dir/Zed" "$tree/mid dir/alpha"
@test "a symlink to a directory is a child, a file is not" "$(_ms_nav_first_child)" = link
command rm "$tree/mid dir/link"
_ms_nav_first_child
@test "a directory without child directories has no first child" $status -eq 1
command mkdir -p -- "$tree/mid dir/-dash" "$tree/mid dir/.hidden"

printf '' >"$TEST_ROOT/commandline"
cd "$tree/mid dir"
_ms_nav_up
@test "Alt-Up on an empty line goes to the parent" "$PWD" = "$tree"
@test "Alt-Up repaints the prompt" "$(cat "$TEST_ROOT/commandline")" = repaint
prevd
@test "Alt-Up keeps the directory history, prevd comes back" "$PWD" = "$tree/mid dir"

printf '' >"$TEST_ROOT/commandline"
_ms_nav_down
@test "Alt-Down on an empty line goes to the first child (a dash name works)" "$PWD" = "$tree/mid dir/-dash"
@test "Alt-Down repaints the prompt" "$(cat "$TEST_ROOT/commandline")" = repaint

printf '' >"$TEST_ROOT/commandline"
_ms_nav_down
@test "Alt-Down in a directory without children stays" "$PWD" = "$tree/mid dir/-dash"
@test "Alt-Down without children still repaints" "$(cat "$TEST_ROOT/commandline")" = repaint

cd "$tree/mid dir"
set FAKE_LINE 'git sta'
printf '' >"$TEST_ROOT/commandline"
_ms_nav_up
@test "Alt-Up with text on the line keeps fish's default action" "$(cat "$TEST_ROOT/commandline")" = history-token-search-backward
@test "Alt-Up with text on the line does not change directory" "$PWD" = "$tree/mid dir"
printf '' >"$TEST_ROOT/commandline"
_ms_nav_down
@test "Alt-Down with text on the line keeps fish's default action" "$(cat "$TEST_ROOT/commandline")" = history-token-search-forward
@test "Alt-Down with text on the line does not change directory" "$PWD" = "$tree/mid dir"

set FAKE_LINE ''
set FAKE_PAGING 1
printf '' >"$TEST_ROOT/commandline"
_ms_nav_up
@test "Alt-Up with the pager open keeps fish's default action" "$(cat "$TEST_ROOT/commandline")" = history-token-search-backward
@test "Alt-Up with the pager open does not change directory" "$PWD" = "$tree/mid dir"
set FAKE_PAGING 0

set -g _ms_fish_reloading 1
@test "init is quiet on reload" -z "$(ms_module nav 2>&1)"
set -e _ms_fish_reloading
@test "binding twice leaves one binding" (count (bind -M default alt-up)) -eq 1

ms_cleanup
