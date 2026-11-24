source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
# Only stubs count as installed: the fixture PATH holds no Homebrew directories.
for name in LS_COLORS MANPAGER MANROFFOPT BAT_THEME GIT_CONFIG_COUNT GIT_CONFIG_KEY_0 GIT_CONFIG_VALUE_0 FZF_DEFAULT_COMMAND FZF_DEFAULT_OPTS FZF_CTRL_T_COMMAND FZF_CTRL_T_OPTS FZF_ALT_C_OPTS
    set -e $name
end
for tool in vivid bat batcat fd fdfind rg eza delta
    if command -q $tool
        echo "# skipped: $tool is installed system-wide" >&2
    end
end

ms_module theme
@test "no vivid leaves LS_COLORS alone" (set -q LS_COLORS; and echo set; or echo unset) = unset
@test "no delta adds no git include" (set -q GIT_CONFIG_COUNT; and echo set; or echo unset) = unset
@test "fzf layout defaults are set" "$FZF_DEFAULT_OPTS" = "--height=40% --layout=reverse --border --info=inline"

ms_stub vivid 'echo "vivid $*" >>"$OPLOG"; echo "di=01;34:ln=01;36"'
ms_stub bat 'exit 0'
ms_stub col 'exit 0'
ms_stub fd 'exit 0'
ms_stub eza 'exit 0'
ms_stub delta 'exit 0'
set -gx GIT_CONFIG_COUNT 1
set -gx GIT_CONFIG_KEY_0 core.editor
set -gx GIT_CONFIG_VALUE_0 vi
set -g _ms_opt_theme_delta on
set -g _ms_opt_theme_bat_theme Nord
ms_module theme
@test "vivid output becomes LS_COLORS" "$LS_COLORS" = "di=01;34:ln=01;36"
@test "LS_COLORS is exported" (set -S LS_COLORS | string match -q '*exported*'; and echo yes) = yes
@test "bat pages man pages" "$MANPAGER" = "sh -c 'col -bx | bat -l man -p'"
@test "BAT_THEME from the option" "$BAT_THEME" = Nord
@test "the delta include is appended" "$GIT_CONFIG_COUNT $GIT_CONFIG_KEY_1 $GIT_CONFIG_VALUE_1" = "2 include.path $MARKSHARC_ROOT/modules/theme/delta.gitconfig"
@test "fd lists files for fzf" "$FZF_DEFAULT_COMMAND" = "fd --type f --hidden --follow --exclude .git"
@test "bat previews files" "$FZF_CTRL_T_OPTS" = "--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
@test "eza previews directories in fzf.fish" "$fzf_preview_dir_cmd" = "eza --all --color=always"

printf '' >"$OPLOG"
set -g _ms_fish_reloading 1
ms_module theme
@test "a reload takes LS_COLORS from the cache" "$LS_COLORS" = "di=01;34:ln=01;36"
@test "and does not run vivid" -z "$(cat "$OPLOG")"
@test "a second source keeps one include" "$GIT_CONFIG_COUNT" = 2

set -g _ms_opt_theme_delta off
set -g _ms_opt_theme_ls_colors off
set -g _ms_opt_theme_man_pager off
set -g _ms_opt_theme_fzf off
ms_module theme
@test "switching delta off removes only its include" "$GIT_CONFIG_COUNT $GIT_CONFIG_KEY_0=$GIT_CONFIG_VALUE_0" = "1 core.editor=vi"
@test "and its variables" (set -q GIT_CONFIG_KEY_1; and echo set; or echo unset) = unset
@test "switching ls_colors off removes LS_COLORS" (set -q LS_COLORS; and echo set; or echo unset) = unset
@test "switching man_pager off removes MANPAGER" (set -q MANPAGER; and echo set; or echo unset) = unset
@test "switching fzf off removes the fzf defaults" (set -q FZF_DEFAULT_OPTS; and echo set; or echo unset) = unset
set -e _ms_fish_reloading

ms_cleanup
