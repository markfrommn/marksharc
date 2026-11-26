# Native directory history; ordinary cd/pushd/popd are observed at the prompt.
declare -ga _ms_nav_past=("$PWD") _ms_nav_future=()
declare -gA _ms_nav_before=() _ms_nav_after=()
declare -gA _ms_nav_replaced

_ms_nav_push() {
    local -n stack=$1
    local value=$2 limit=${DIRHISTORY_SIZE:-50}
    [[ $limit =~ ^[0-9]+$ ]] || limit=50
    while [[ ${#limit} -gt 1 && $limit == 0* ]]; do limit=${limit#0}; done
    if (( ${#limit} > 9 )); then limit=999999999; else limit=$((10#$limit)); fi
    (( limit > 0 )) || limit=1
    if (( ${#stack[@]} == 0 )) || [[ ${stack[${#stack[@]}-1]} != "$value" ]]; then stack+=("$value"); fi
    while (( ${#stack[@]} > limit )); do stack=("${stack[@]:1}"); done
}
chpwd_dirhistory() {
    [[ ${_ms_nav_past[${#_ms_nav_past[@]}-1]-} != "$PWD" ]] || return 0
    _ms_nav_push _ms_nav_past "$PWD"
    _ms_nav_future=()
}
_ms_nav_observe() {
    [[ ${_ms_nav_past[${#_ms_nav_past[@]}-1]-} == "$PWD" ]] || chpwd_dirhistory
}
dirhistory_back() {
    _ms_nav_observe
    local count=${#_ms_nav_past[@]} current target
    (( count > 1 )) || return 0
    current=${_ms_nav_past[count-1]} target=${_ms_nav_past[count-2]}
    CDPATH='' builtin cd -- "$target" || return 1
    unset '_ms_nav_past[count-1]'
    _ms_nav_push _ms_nav_future "$current"
}
dirhistory_forward() {
    _ms_nav_observe
    local count=${#_ms_nav_future[@]} target
    (( count )) || return 0
    target=${_ms_nav_future[count-1]}
    CDPATH='' builtin cd -- "$target" || return 1
    unset '_ms_nav_future[count-1]'
    _ms_nav_push _ms_nav_past "$PWD"
}
dirhistory_up() { CDPATH='' builtin cd -- .. || return; }
_dirhistory_first_child() {
    local path
    for path in ./.[!.]*/ ./..?*/ ./*/; do
        [[ -d $path && $path != ./../ && $path != ././ ]] || continue
        REPLY=${path%/}
        return 0
    done
    return 1
}
dirhistory_down() { local REPLY; _dirhistory_first_child || return; CDPATH='' builtin cd -- "$REPLY" || return; }
switch-to-dir() {
    if [[ $1 == -- ]]; then
        [[ -d $2 ]] || return 1
        CDPATH='' builtin pushd -- "$2" >/dev/null || return
    else
        builtin pushd "$1" >/dev/null || return
    fi
}
insert-cycledleft() { switch-to-dir +1; }
insert-cycledright() { switch-to-dir -0; }
insert-cycledup() { switch-to-dir -- ..; }
insert-cycleddown() { local REPLY; _dirhistory_first_child && switch-to-dir -- "$REPLY"; }

_ms_nav_widget() {
    "$1" || return
    if [[ ${_ms_bash_prompt_owned-} ]]; then
        _ms_bash_prompt_capture 0 0
        # The core prompt capture constructs the replay command.
        # shellcheck disable=SC2154
        eval "$_ms_bash_prompt_replay"
    else
        _ms_bash_prompt_dispatch 0 0
    fi
    # bind -x returns to Readline, which redraws the current edit buffer.
    printf '\r\033[2K%s' "${PS1@P}"
}
_ms_nav_keymap() {
    local -n result=$1
    shift
    local map kind line key pattern='^"(([^"\\]|\\.)*)"(:|[[:blank:]])'
    for map in emacs vi-insert vi-command; do
        for kind; do
            while IFS= read -r line; do
                case $line in
                    '"\e[3'*|'"\e[1;'*|'"\e\e['*|'"\eO3'*|'"\eb"'*|'"\ef"'*) ;;
                    *) continue ;;
                esac
                [[ $line =~ $pattern ]] || continue
                key=$map:${BASH_REMATCH[1]}
                # shellcheck disable=SC2004,SC2034 # Writes to the caller's map.
                result[$key]=$kind:$line
            done < <(bind -m "$map" "-$kind" 2>/dev/null)
        done
    done
}
_ms_nav_restore_key() {
    local map=${1%%:*} key=${1#*:} definition=$2
    bind -m "$map" -r "$key" 2>/dev/null || :
    case ${definition%%:*} in
        p|s) bind -m "$map" "${definition#*:}" ;;
        X) bind -m "$map" -x "${definition#*:}" ;;
    esac
}
_ms_nav_cleanup() {
    local key
    local -A current=()
    # Bash 4.4 can still list a former bind -x command after a Readline
    # function or macro takes over the sequence.
    _ms_nav_keymap current X p s
    for key in "${!_ms_nav_after[@]}"; do
        if [[ ${current[$key]-} == "${_ms_nav_after[$key]}" ]]; then
            _ms_nav_restore_key "$key" "${_ms_nav_before[$key]-}"
        else
            _ms_nav_replaced[$key]=1
        fi
    done
    _ms_nav_before=() _ms_nav_after=()
    unset _ms_nav_past _ms_nav_future
}
_ms_nav_bind() {
    local map direction key fn
    local -A before=() after=()
    _ms_nav_keymap before X p s
    for map in emacs vi-insert vi-command; do
        for direction in D C A B; do
            case $direction in D) fn=dirhistory_back ;; C) fn=dirhistory_forward ;; A) fn=dirhistory_up ;; B) fn=dirhistory_down ;; esac
            for key in "\\e[3$direction" "\\e[1;3$direction" "\\e\\e[$direction" "\\eO3$direction"; do
                bind -m "$map" -x "\"$key\":_ms_nav_widget $fn"
            done
            case $direction in D) fn=insert-cycledleft ;; C) fn=insert-cycledright ;; A) fn=insert-cycledup ;; B) fn=insert-cycleddown ;; esac
            bind -m "$map" -x "\"\\e[1;6$direction\":_ms_nav_widget $fn"
        done
        case ${TERM_PROGRAM-} in
            Apple_Terminal|ghostty|iTerm.app)
                bind -m "$map" -x '"\eb":_ms_nav_widget dirhistory_back'
                bind -m "$map" -x '"\ef":_ms_nav_widget dirhistory_forward'
                ;;
        esac
    done
    _ms_nav_keymap after X
    for key in "${!after[@]}"; do
        [[ ${before[$key]-} != "${after[$key]}" ]] || continue
        if [[ ${_ms_nav_replaced[$key]+yes} ]]; then
            _ms_nav_restore_key "$key" "${before[$key]-}"
        else
            _ms_nav_before[$key]=${before[$key]-}
            _ms_nav_after[$key]=${after[$key]}
        fi
    done
}
_ms_bash_register_chpwd chpwd_dirhistory
_ms_nav_bind
_ms_bash_register_cleanup _ms_nav_cleanup
