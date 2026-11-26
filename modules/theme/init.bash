# Reuse the established vivid cache, which stores the generated value safely.
if [[ ${_ms_opt_theme_ls_colors-molokai} != off && -n ${_ms_opt_theme_ls_colors-molokai} ]] && type -P vivid >/dev/null; then
    _ms_theme_colors=$(command zsh -fc '
        source "$MARKSHARC_HOME/core/zsh/lib/cache.zsh"
        _ms_trace() { :; }
        _ms_init_cached -x LS_COLORS vivid vivid generate "$1" || exit
        print -rn -- "$LS_COLORS"
    ' -- "${_ms_opt_theme_ls_colors-molokai}")
    [[ -z $_ms_theme_colors ]] || _ms_bash_set_env LS_COLORS "$_ms_theme_colors"
    unset _ms_theme_colors
fi
_ms_theme_bat=
if type -P bat >/dev/null; then _ms_theme_bat=bat
elif type -P batcat >/dev/null; then _ms_theme_bat=batcat; fi
if [[ ${_ms_opt_theme_man_pager-bat} == bat && -n $_ms_theme_bat ]] && type -P col >/dev/null; then
    _ms_bash_set_env MANPAGER "sh -c 'col -bx | $_ms_theme_bat -l man -p'"
    _ms_bash_set_env MANROFFOPT -c
fi
[[ -z ${_ms_opt_theme_bat_theme-} ]] || _ms_bash_set_env BAT_THEME "$_ms_opt_theme_bat_theme"

_ms_theme_delta_cleanup() {
    # If another include was appended, all three entries must remain intact.
    if [[ $(_ms_bash_effect variable GIT_CONFIG_COUNT) != "${_ms_bash_installed[variable:GIT_CONFIG_COUNT]-}" ||
          $(_ms_bash_effect variable "GIT_CONFIG_KEY_$_ms_theme_git_index") != "${_ms_bash_installed[variable:GIT_CONFIG_KEY_$_ms_theme_git_index]-}" ||
          $(_ms_bash_effect variable "GIT_CONFIG_VALUE_$_ms_theme_git_index") != "${_ms_bash_installed[variable:GIT_CONFIG_VALUE_$_ms_theme_git_index]-}" ]]; then
        unset '_ms_bash_installed[variable:GIT_CONFIG_COUNT]' \
            "_ms_bash_installed[variable:GIT_CONFIG_KEY_$_ms_theme_git_index]" \
            "_ms_bash_installed[variable:GIT_CONFIG_VALUE_$_ms_theme_git_index]"
    fi
}
_ms_theme_delta_init() {
    local count=${GIT_CONFIG_COUNT:-0} index key value definition flags name
    local include=${BASH_SOURCE[0]%/*}/delta.gitconfig
    [[ $count =~ ^[0-9]+$ ]] || return 0
    # Remove leading zeroes before arithmetic; Bash otherwise interprets octal.
    while [[ ${#count} -gt 1 && $count == 0* ]]; do count=${count#0}; done
    # Avoid overflow and unbounded scanning of malformed environment input.
    (( ${#count} <= 5 )) || return 0
    for ((index=0; index<count; index++)); do
        key=GIT_CONFIG_KEY_$index value=GIT_CONFIG_VALUE_$index
        if [[ ${!key-} == include.path && ${!value-} == "$include" ]]; then return 0; fi
    done
    key=GIT_CONFIG_KEY_$count value=GIT_CONFIG_VALUE_$count
    # Never overwrite an entry outside the advertised range or a later user edit.
    [[ ! ${!key+x} && ! ${!value+x} ]] || return 0
    for name in GIT_CONFIG_COUNT "$key" "$value"; do
        [[ ! ${_ms_bash_replaced[variable:$name]+yes} ]] || return 0
        definition=$(_ms_bash_effect variable "$name")
        flags=${definition#declare -}; flags=${flags%% *}
        case $flags in ''|-|x) ;; *) return 0 ;; esac
    done
    _ms_theme_git_index=$count
    _ms_bash_set_env "$key" include.path
    _ms_bash_set_env "$value" "$include"
    _ms_bash_set_env GIT_CONFIG_COUNT "$((count + 1))"
    _ms_bash_register_cleanup _ms_theme_delta_cleanup
}
case ${_ms_opt_theme_delta-off} in
    on|1|yes|true)
        if type -P delta >/dev/null; then _ms_theme_delta_init; fi ;;
esac
case ${_ms_opt_theme_fzf-on} in
    on|1|yes|true)
        _ms_theme_command=
        if type -P fd >/dev/null; then _ms_theme_command='fd --type f --hidden --follow --exclude .git'
        elif type -P fdfind >/dev/null; then _ms_theme_command='fdfind --type f --hidden --follow --exclude .git'
        elif type -P rg >/dev/null; then _ms_theme_command="rg --files --hidden --glob '!.git'"; fi
        [[ -z $_ms_theme_command ]] || _ms_bash_set_env FZF_DEFAULT_COMMAND "$_ms_theme_command"
        [[ -z ${FZF_DEFAULT_COMMAND-} ]] || _ms_bash_set_env FZF_CTRL_T_COMMAND "$FZF_DEFAULT_COMMAND"
        _ms_bash_set_env FZF_DEFAULT_OPTS '--height=40% --layout=reverse --border --info=inline'
        _ms_theme_file_preview='head -n 300 {}' _ms_theme_dir_preview='ls -A {}'
        [[ -z $_ms_theme_bat ]] || _ms_theme_file_preview="$_ms_theme_bat --color=always --style=numbers --line-range=:300 {}"
        if type -P eza >/dev/null; then _ms_theme_dir_preview='eza --tree --level=2 --color=always {} | head -n 200'; fi
        _ms_bash_set_env FZF_CTRL_T_OPTS "--preview '$_ms_theme_file_preview'"
        _ms_bash_set_env FZF_ALT_C_OPTS "--preview '$_ms_theme_dir_preview'"
        if type -P fzf >/dev/null; then
            _ms_bash_load_file "${BASH_SOURCE[0]%/*}/lib/fzf.bash"
        fi
        unset _ms_theme_command _ms_theme_file_preview _ms_theme_dir_preview ;;
esac
unset _ms_theme_bat
:
