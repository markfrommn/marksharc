# File and directory widgets. The history chord stays with the current editor
# or Atuin; fzf's generic Bash setup would also bind Ctrl-R.
declare -gA _ms_fzf_before=() _ms_fzf_installed=()
declare -gA _ms_fzf_replaced

_ms_fzf_file_widget() {
    local file quoted inserted=
    local -a files=()
    # shellcheck disable=SC2312 # An empty result means the user canceled.
    mapfile -d '' -t files < <(
        FZF_DEFAULT_COMMAND=${FZF_CTRL_T_COMMAND-${FZF_DEFAULT_COMMAND-}} \
            FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS-} ${FZF_CTRL_T_OPTS-}" \
            command fzf --walker=file,dir,follow,hidden --walker-skip=.git --multi --print0 </dev/tty
    )
    for file in "${files[@]}"; do
        printf -v quoted '%q' "$file"
        inserted+="$quoted "
    done
    [[ $inserted ]] || return 0
    READLINE_LINE=${READLINE_LINE:0:READLINE_POINT}$inserted${READLINE_LINE:READLINE_POINT}
    (( READLINE_POINT += ${#inserted} ))
}

_ms_fzf_directory_widget() {
    local directory
    IFS= read -r -d '' directory < <(
        FZF_DEFAULT_COMMAND=${FZF_ALT_C_COMMAND-} \
            FZF_DEFAULT_OPTS="${FZF_DEFAULT_OPTS-} ${FZF_ALT_C_OPTS-}" \
            command fzf --walker=dir,follow,hidden --walker-skip=.git --no-multi --print0 </dev/tty
    ) || return 0
    CDPATH='' builtin cd -- "$directory" && _ms_bash_widget_redraw
}

_ms_fzf_capture_keys() {
    local -n result=$1
    local map=$2 kind line
    shift 2
    for kind; do
        while IFS= read -r line; do
            # The captured definitions are consumed through the caller's array.
            # shellcheck disable=SC2034
            case $line in
                '"\C-t":'*|'"\C-t" '*) result["$map:C-t"]=$kind:$line ;;
                '"\ec":'*|'"\ec" '*) result["$map:ec"]=$kind:$line ;;
            esac
        done < <(_ms_bash_binding_dump -m "$map" "-$kind" 2>/dev/null)
    done
}

_ms_fzf_restore_key() {
    local map=${1%%:*} key=${1#*:} old=$2
    bind -m "$map" -r "\\$key" 2>/dev/null || :
    case ${old%%:*} in
        p|s) bind -m "$map" "${old#*:}" ;;
        X) bind -m "$map" -x "${old#*:}" ;;
    esac
}

_ms_fzf_cleanup() {
    local map key
    local -A current=()
    for map in emacs vi-insert vi-command; do _ms_fzf_capture_keys current "$map" X p s; done
    for key in "${!_ms_fzf_installed[@]}"; do
        if [[ ${current[$key]-} == "${_ms_fzf_installed[$key]}" ]]; then
            _ms_fzf_restore_key "$key" "${_ms_fzf_before[$key]-}"
        else
            _ms_fzf_replaced[$key]=1
        fi
    done
}

_ms_fzf_bind_keys() {
    local map key widget
    local -A after=()
    for map in emacs vi-insert vi-command; do
        _ms_fzf_capture_keys _ms_fzf_before "$map" X p s
        for key in C-t ec; do
            [[ ! ${_ms_fzf_replaced[$map:$key]+yes} ]] || continue
            case $key in
                C-t) widget=_ms_fzf_file_widget ;;
                ec) widget=_ms_fzf_directory_widget ;;
            esac
            bind -m "$map" -x "\"\\$key\":$widget"
        done
        _ms_fzf_capture_keys after "$map" X
    done
    for key in "${!after[@]}"; do
        if [[ ${after[$key]} != "${_ms_fzf_before[$key]-}" ]]; then
            _ms_fzf_installed[$key]=${after[$key]}
        fi
    done
    _ms_bash_register_cleanup _ms_fzf_cleanup
}

_ms_fzf_bind_keys
