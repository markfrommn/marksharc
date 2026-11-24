# theme module, init phase: one colour baseline for interactive shells.
#
#   LS_COLORS   vivid generate <theme.ls_colors>, cached (a hit forks nothing); used by
#               ls, eza, fd and the completion list colours (completion loads at 70).
#   MANPAGER    bat (or Debian's batcat) as the man pager, through col -bx.
#   BAT_THEME   from theme.bat_theme.
#   git         theme.delta on: include delta.gitconfig through GIT_CONFIG_COUNT, so no
#               file is edited; entries already in the environment are kept.
#   fzf         file listing with fd, else rg; layout; bat and eza previews, for fzf's own
#               key bindings and for fzf-tab.
#
# A missing tool leaves the native behaviour. Everything set here is recorded, and a reload
# removes it first, so an option switched off takes effect in the same shell.
typeset -ga _ms_theme_vars _ms_theme_zstyles
typeset -g _ms_theme_name
for _ms_theme_name in "${_ms_theme_vars[@]}"; do unset "$_ms_theme_name"; done
for _ms_theme_name in "${_ms_theme_zstyles[@]}"; do zstyle -d ${=_ms_theme_name}; done
_ms_theme_vars=() _ms_theme_zstyles=()

# Remove this module's git include when it is the newest entry; an entry added after it
# by someone else is left alone.
if [[ -n ${_ms_theme_git_index-} ]]; then
    if [[ ${GIT_CONFIG_COUNT-} == $(( _ms_theme_git_index + 1 )) && ${(P)${:-GIT_CONFIG_VALUE_$_ms_theme_git_index}-} == "${_ms_theme_git_value-}" ]]; then
        unset "GIT_CONFIG_KEY_$_ms_theme_git_index" "GIT_CONFIG_VALUE_$_ms_theme_git_index"
        if (( _ms_theme_git_index == 0 )); then unset GIT_CONFIG_COUNT; else export GIT_CONFIG_COUNT=$_ms_theme_git_index; fi
    fi
    unset _ms_theme_git_index _ms_theme_git_value
fi

_ms_theme_export() {
    export "$1=$2"
    _ms_theme_vars+=( "$1" )
}
_ms_theme_zstyle() {
    zstyle "$@"
    _ms_theme_zstyles+=( "$1 $2" )
}

if [[ ${_ms_opt_theme_ls_colors-molokai} != (off|) ]] && have_command vivid; then
    _ms_init_cached -x LS_COLORS vivid vivid generate "${_ms_opt_theme_ls_colors-molokai}" && _ms_theme_vars+=( LS_COLORS )
fi

typeset -g _ms_theme_bat=
if have_command bat; then _ms_theme_bat=bat; elif have_command batcat; then _ms_theme_bat=batcat; fi
if [[ ${_ms_opt_theme_man_pager-bat} == bat && -n $_ms_theme_bat ]] && have_command col; then
    _ms_theme_export MANPAGER "sh -c 'col -bx | $_ms_theme_bat -l man -p'"
    _ms_theme_export MANROFFOPT -c
fi
[[ -n ${_ms_opt_theme_bat_theme-} ]] && _ms_theme_export BAT_THEME "$_ms_opt_theme_bat_theme"

if [[ ${_ms_opt_theme_delta-off} == (on|1|yes|true) ]] && have_command delta; then
    typeset -g _ms_theme_git_index=${GIT_CONFIG_COUNT:-0}
    [[ $_ms_theme_git_index == <-> ]] || _ms_theme_git_index=0
    typeset -g _ms_theme_git_value=${_ms_mod_dir[theme]:-$MARKSHARC_HOME/modules/theme}/delta.gitconfig
    export "GIT_CONFIG_KEY_$_ms_theme_git_index=include.path" "GIT_CONFIG_VALUE_$_ms_theme_git_index=$_ms_theme_git_value"
    export GIT_CONFIG_COUNT=$(( _ms_theme_git_index + 1 ))
fi

if [[ ${_ms_opt_theme_fzf-on} == (on|1|yes|true) ]]; then
    if have_command fd; then
        _ms_theme_export FZF_DEFAULT_COMMAND 'fd --type f --hidden --follow --exclude .git'
    elif have_command fdfind; then
        _ms_theme_export FZF_DEFAULT_COMMAND 'fdfind --type f --hidden --follow --exclude .git'
    elif have_command rg; then
        _ms_theme_export FZF_DEFAULT_COMMAND "rg --files --hidden --glob '!.git'"
    fi
    [[ -n ${FZF_DEFAULT_COMMAND-} ]] && _ms_theme_export FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
    _ms_theme_export FZF_DEFAULT_OPTS '--height=40% --layout=reverse --border --info=inline'
    typeset -g _ms_theme_file_preview='head -n 300 {}' _ms_theme_dir_preview='ls -A {}'
    [[ -n $_ms_theme_bat ]] && _ms_theme_file_preview="$_ms_theme_bat --color=always --style=numbers --line-range=:300 {}"
    have_command eza && _ms_theme_dir_preview='eza --tree --level=2 --color=always {} | head -n 200'
    _ms_theme_export FZF_CTRL_T_OPTS "--preview '$_ms_theme_file_preview'"
    _ms_theme_export FZF_ALT_C_OPTS "--preview '$_ms_theme_dir_preview'"
    # fzf-tab reads these when it completes (it loads at 71); ${realpath} is its own.
    _ms_theme_zstyle ':fzf-tab:*' use-fzf-default-opts yes
    _ms_theme_zstyle ':fzf-tab:complete:(cd|pushd|z):*' fzf-preview "${_ms_theme_dir_preview//\{\}/\$realpath}"
    _ms_theme_zstyle ':fzf-tab:complete:(cat|bat|batcat|less|more|head|tail|vi|vim|nvim|emacs):*' fzf-preview "${_ms_theme_file_preview//\{\}/\$realpath}"
    unset _ms_theme_file_preview _ms_theme_dir_preview
fi
unfunction _ms_theme_export _ms_theme_zstyle
unset _ms_theme_name _ms_theme_bat
true
