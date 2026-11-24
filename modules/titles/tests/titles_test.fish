source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
set -gx TERM xterm
set -e TERM_PROGRAM
set -e chdir_set_title_skip
# git must not read the real configuration of the machine running the unit.
set -gx GIT_CONFIG_GLOBAL /dev/null
set -gx GIT_CONFIG_NOSYSTEM 1
ms_module titles

set -l esc (printf '\033')
set -l bel (printf '\007')

# set-title: literal output, no expansion.
@test "xterm: combined, window and tab titles" "$(set-title 'two words $HOME %n' window combined | string collect -N)" = "$esc]0;combined$bel$esc]2;window$bel$esc]1;two words \$HOME %n$bel"
@test "xterm: the tab title alone" "$(set-title tab | string collect -N)" = "$esc]1;tab$bel"
set -gx TERM tmux-256color
@test "tmux: tab title as a screen title, control characters dropped" "$(set-title 'literal %n'(printf '\a\e\n') | string collect -N)" = "$esc"'kliteral %n'"$esc\\"
@test "tmux: window and combined titles" "$(set-title tab window combined | string collect -N)" = "$esc]0;combined$esc\\$esc]2;window$esc\\"$esc"ktab$esc\\"
set -gx TERM dumb
@test "an unknown terminal gets no title" -z "$(set-title tab | string collect -N)"
set -gx TERM_PROGRAM iTerm.app
@test "iTerm sets the tab title whatever TERM says" "$(set-title tab | string collect -N)" = "$esc]1;tab$bel"
set -e TERM_PROGRAM
set -gx TERM xterm
set -gx INSIDE_EMACS 29.1,comint
@test "a non-vterm emacs gets no title" -z "$(set-title tab | string collect -N)"
set -gx INSIDE_EMACS vterm
@test "emacs vterm gets the title" "$(set-title tab | string collect -N)" = "$esc]1;tab$bel"
set -e INSIDE_EMACS

# chdir-set-title reads $SHLVL, which fish does not let a script change, so each call runs in
# a fresh fish with SHLVL set in its environment. Stubs record what herdr, wezterm and cwf get.
set -gx hostname_short (string split -m 1 . -- "$hostname")[1]
ms_stub herdr 'printf "%s\n" "$*" >>"$TEST_ROOT/herdr"'
ms_stub wezterm 'printf "%s\n" "$*" >>"$TEST_ROOT/wezterm"'
ms_stub cwf 'if [ "$1 $2" = "session name" ] && [ -n "$CWF_NAME" ]; then echo "$CWF_NAME"; else exit 1; fi'
function title_shell --argument-names level
    env SHLVL=$level (status fish-path) --no-config -c 'set -p fish_function_path "$MARKSHARC_HOME/modules/titles/functions/fish"; chdir-set-title' | string collect -N
end
function tab_of
    # The tab title out of the OSC 1 sequence set-title wrote.
    string replace -r '^\e\]1;(.*)\a$' '$1' -- "$argv[1]"
end
function title_all --argument-names level
    title_shell $level
    cat "$TEST_ROOT/wezterm"
end
function reset_titles
    printf '' >"$TEST_ROOT/herdr"
    printf '' >"$TEST_ROOT/wezterm"
end
reset_titles

command mkdir -p -- "$TEST_ROOT/plain dir/one/two/three/four"
cd "$HOME"
@test "the home directory is shown as ~" "$(tab_of (title_shell 1))" = '~'
cd "$TEST_ROOT/plain dir/one/two/three/four"
@test "outside a repository the tab title is the full path" "$(tab_of (title_shell 1))" = "$PWD"

command mkdir -p -- "$HOME/work/proj dir/sub dir"
cd "$HOME/work/proj dir"
command git init -q -b main . >/dev/null 2>&1
@test "inside a repository the tab title is the branch" "$(tab_of (title_shell 1))" = main
command git -c user.name=t -c user.email=t@example.invalid commit -q --allow-empty -m first
command git checkout -q --detach
@test "a detached HEAD is labelled detached-<sha>" (string match -r -q '^detached-[0-9a-f]+$' -- "$(tab_of (title_shell 1))"; echo $status) -eq 0
command git checkout -q main
set -gx CWF_NAME "session one"
@test "a cwf session name wins over the branch" "$(tab_of (title_shell 1))" = "session one"
set -e CWF_NAME

# herdr gets repository, directory and branch; wezterm gets the tab title.
cd "$HOME/work/proj dir/sub dir"
command git remote add origin 'https://example.invalid/team/the repo.git'
set -gx HERDR_TAB_ID tab1
set -gx HERDR_WORKSPACE_ID ws1
set -gx HERDR_PANE_ID pane1
set -gx WEZTERM_PANE 7
reset_titles
set -l out (title_shell 1)
set -l herdr_log (cat "$TEST_ROOT/herdr")
@test "herdr is told the repository as workspace" "$herdr_log[3]" = "workspace rename ws1 the repo"
@test "herdr is told the branch as tab" "$herdr_log[4]" = "tab rename tab1 main"
@test "herdr is told the sub directory as pane (spaces kept)" "$herdr_log[5]" = "pane rename pane1 sub dir/"
@test "herdr gets topname and subname metadata" "$herdr_log[1]|$herdr_log[2]" = "workspace report-metadata ws1 --source fish-chdir --token topname=the repo-rm|workspace report-metadata ws1 --source fish-chdir --token subname=proj dir/sub dir"
set -l others (cat "$TEST_ROOT/wezterm")
@test "herdr is preferred over wezterm and set-title" (count $others) -eq 0 -a -z "$out"
cd "$TEST_ROOT/plain dir/one/two/three/four"
set -e WEZTERM_PANE
reset_titles
title_shell 1 >/dev/null
set herdr_log (cat "$TEST_ROOT/herdr")
@test "outside a repository herdr gets the last two directories as workspace" "$herdr_log[3]" = "workspace rename ws1 three/four"
@test "outside a repository herdr gets the two above as sub name" "$herdr_log[2]" = "workspace report-metadata ws1 --source fish-chdir --token subname=one/two"
@test "outside a repository the pane is the full path" "$herdr_log[5]" = "pane rename pane1 $PWD"
cd /
reset_titles
title_shell 1 >/dev/null
set herdr_log (cat "$TEST_ROOT/herdr")
@test "a short path puts the host name on the sub line" "$herdr_log[2]" = "workspace report-metadata ws1 --source fish-chdir --token subname=$hostname_short"
if test -d /sys/class/net
    cd /sys/class/net
    reset_titles
    title_shell 1 >/dev/null
    set herdr_log (cat "$TEST_ROOT/herdr")
    @test "a path with three slashes splits one directory above two" "$herdr_log[2]|$herdr_log[3]" = "workspace report-metadata ws1 --source fish-chdir --token subname=sys|workspace rename ws1 class/net"
end
set -e HERDR_TAB_ID
set -gx WEZTERM_PANE 7
cd "$HOME/work/proj dir/sub dir"
reset_titles
set out (title_shell 1)
@test "wezterm gets the tab title" "$(cat "$TEST_ROOT/wezterm")" = "cli set-tab-title main"
@test "wezterm is preferred over set-title" -z "$out"

# Skip rules.
cd "$TEST_ROOT"
set -gx HC_TERMINAL_ID core1
reset_titles
@test "a herdr core terminal is skipped" -z "$(title_all 1)"
set -e HC_TERMINAL_ID
@test "a nested shell (SHLVL 2) is skipped" -z "$(title_all 2)"
set -gx chdir_set_title_skip yes
@test "chdir_set_title_skip suppresses the title" -z "$(title_all 1)"
set -e chdir_set_title_skip
@test "the title is set again without a skip" -n "$(title_all 1)"

# A missing herdr or wezterm is not an error and prints nothing.
command rm "$TEST_ROOT/bin/herdr" "$TEST_ROOT/bin/wezterm"
set -gx HERDR_TAB_ID tab1
@test "a missing herdr is quiet" -z "$(title_shell 1 2>&1)"
set -e HERDR_TAB_ID
@test "a missing wezterm is quiet" -z "$(title_shell 1 2>&1)"
set -e WEZTERM_PANE

# The hook and fish_title. Replace the title function with a counter first.
function chdir-set-title
    echo hook >>"$TEST_ROOT/hook"
end
printf '' >"$TEST_ROOT/hook"
@test "startup sets no title, as in zsh" -z "$(ms_module titles; cat "$TEST_ROOT/hook")"
ms_module titles
printf '' >"$TEST_ROOT/hook"
cd "$HOME"
@test "a directory change runs the title function" "$(cat "$TEST_ROOT/hook")" = hook
ms_module titles
printf '' >"$TEST_ROOT/hook"
cd "$TEST_ROOT"
@test "initialising twice leaves a single hook" (count (cat "$TEST_ROOT/hook")) -eq 1
set -g _ms_fish_reloading 1
printf '' >"$TEST_ROOT/hook"
ms_module titles
@test "reload sets no title either" -z "$(cat "$TEST_ROOT/hook")"
set -e _ms_fish_reloading
@test "fish_title prints nothing" -z "$(fish_title | string collect -N)"
@test "init prints nothing" -z "$(ms_module titles 2>&1)"

ms_cleanup
