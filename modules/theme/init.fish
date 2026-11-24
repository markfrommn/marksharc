# theme module, init phase: one colour baseline for interactive shells, as in zsh.
#
#   LS_COLORS   vivid generate <theme.ls_colors>, cached (a hit forks nothing).
#   MANPAGER    bat (or Debian's batcat) as the man pager, through col -bx.
#   BAT_THEME   from theme.bat_theme.
#   git         theme.delta on: include delta.gitconfig through GIT_CONFIG_COUNT.
#   fzf         file listing with fd, else rg; layout; bat and eza previews, and the
#               fzf.fish preview commands.
#
# A missing tool leaves the native behaviour. Everything set here is recorded, and a reload
# removes it first, so an option switched off takes effect in the same shell.
for _ms_name in $_ms_fish_theme_vars
    set -e $_ms_name
end
set -g _ms_fish_theme_vars

# Remove this module's git include when it is the newest entry.
if set -q _ms_fish_theme_git_index
    set -l value_var GIT_CONFIG_VALUE_$_ms_fish_theme_git_index
    if test "$GIT_CONFIG_COUNT" = (math $_ms_fish_theme_git_index + 1); and set -q $value_var; and test "$$value_var" = "$_ms_fish_theme_git_value"
        set -e GIT_CONFIG_KEY_$_ms_fish_theme_git_index $value_var
        if test $_ms_fish_theme_git_index -eq 0
            set -e GIT_CONFIG_COUNT
        else
            set -gx GIT_CONFIG_COUNT $_ms_fish_theme_git_index
        end
    end
    set -e _ms_fish_theme_git_index _ms_fish_theme_git_value
end

function _ms_fish_theme_export --argument-names name value
    set -gx $name $value
    contains -- $name $_ms_fish_theme_vars; or set -ga _ms_fish_theme_vars $name
end

set -l ls_colors molokai
set -q _ms_opt_theme_ls_colors; and set ls_colors "$_ms_opt_theme_ls_colors"
if not contains -- "$ls_colors" off ''; and _ms_fish_command_available vivid
    _ms_fish_init_cached -x LS_COLORS vivid vivid generate "$ls_colors"; and set -ga _ms_fish_theme_vars LS_COLORS
end

set -l bat
if _ms_fish_command_available bat
    set bat bat
else if _ms_fish_command_available batcat
    set bat batcat
end
set -l man_pager bat
set -q _ms_opt_theme_man_pager; and set man_pager "$_ms_opt_theme_man_pager"
if test "$man_pager" = bat; and test -n "$bat"; and _ms_fish_command_available col
    _ms_fish_theme_export MANPAGER "sh -c 'col -bx | $bat -l man -p'"
    _ms_fish_theme_export MANROFFOPT -c
end
test -n "$_ms_opt_theme_bat_theme"; and _ms_fish_theme_export BAT_THEME "$_ms_opt_theme_bat_theme"

if contains -- "$_ms_opt_theme_delta" on 1 yes true; and _ms_fish_command_available delta
    set -g _ms_fish_theme_git_index 0
    string match -qr '^[0-9]+$' -- "$GIT_CONFIG_COUNT"; and set _ms_fish_theme_git_index $GIT_CONFIG_COUNT
    set -g _ms_fish_theme_git_value "$MARKSHARC_HOME/modules/theme/delta.gitconfig"
    set -gx GIT_CONFIG_KEY_$_ms_fish_theme_git_index include.path
    set -gx GIT_CONFIG_VALUE_$_ms_fish_theme_git_index "$_ms_fish_theme_git_value"
    set -gx GIT_CONFIG_COUNT (math $_ms_fish_theme_git_index + 1)
end

if contains -- "$_ms_opt_theme_fzf" on 1 yes true ''
    if _ms_fish_command_available fd
        _ms_fish_theme_export FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
    else if _ms_fish_command_available fdfind
        _ms_fish_theme_export FZF_DEFAULT_COMMAND 'fdfind --type f --hidden --follow --exclude .git'
    else if _ms_fish_command_available rg
        _ms_fish_theme_export FZF_DEFAULT_COMMAND "rg --files --hidden --glob '!.git'"
    end
    set -q FZF_DEFAULT_COMMAND; and _ms_fish_theme_export FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    _ms_fish_theme_export FZF_DEFAULT_OPTS '--height=40% --layout=reverse --border --info=inline'
    set -l file_preview 'head -n 300 {}'
    set -l dir_preview 'ls -A {}'
    test -n "$bat"; and set file_preview "$bat --color=always --style=numbers --line-range=:300 {}"
    _ms_fish_command_available eza; and set dir_preview 'eza --tree --level=2 --color=always {} | head -n 200'
    _ms_fish_theme_export FZF_CTRL_T_OPTS "--preview '$file_preview'"
    _ms_fish_theme_export FZF_ALT_C_OPTS "--preview '$dir_preview'"
    # fzf.fish previews: it appends the path to these commands.
    if _ms_fish_command_available eza
        set -g fzf_preview_dir_cmd eza --all --color=always
        contains -- fzf_preview_dir_cmd $_ms_fish_theme_vars; or set -ga _ms_fish_theme_vars fzf_preview_dir_cmd
    end
end
functions -e _ms_fish_theme_export
set -e _ms_name
true
