# Native interactive Bash lifecycle. bashrc.bash has already checked version,
# TTYs, session class and the rendered environment.
# shellcheck source=core/bash/cache.bash
source "$MARKSHARC_HOME/core/bash/cache.bash"
# shellcheck source=core/bash/directives.bash
source "$MARKSHARC_HOME/core/bash/directives.bash"
# shellcheck source=core/bash/hooks.bash
source "$MARKSHARC_HOME/core/bash/hooks.bash"
# shellcheck source=core/bash/backends.bash
source "$MARKSHARC_HOME/core/bash/backends.bash"
# shellcheck source=core/bash/complete.bash
source "$MARKSHARC_HOME/core/bash/complete.bash"

declare -ga _ms_bash_cleanup_order=()
declare -gA _ms_bash_cleanup_definitions=()

_ms_bash_alias() {
    [[ ! ${_ms_bash_replaced[alias:$1]+yes} ]] || return 0
    # The renderer passes the literal alias body as an argument.
    # shellcheck disable=SC2139
    builtin alias -- "$1=$2"
}

_ms_bash_require() {
    builtin type -P -- "$2" >/dev/null 2>&1 && return 0
    if [[ $_ms_bash_verbose == 1 ]]; then
        printf 'module %s: skipped (requires command %s)\n' "$1" "$2" >&2
    fi
    return 1
}

_ms_bash_load_file() {
    [[ -f $1 && -r $1 ]] || return 0
    # Native module/overlay code owns its output, including opt-in messages.
    # shellcheck disable=SC1090
    if ! source "$1" && [[ $_ms_bash_verbose == 1 ]]; then
        printf 'Bash init: %s returned failure\n' "$1" >&2
    fi
    return 0
}

_ms_bash_load_module() {
    local _ms_file
    for _ms_file in "$2"/functions/bash/*.bash; do
        _ms_bash_load_file "$_ms_file"
    done
    if [[ $_ms_bash_verbose == 1 && -r $2/init.bash ]]; then
        local TIMEFORMAT='    %3R seconds'
        printf 'module %s: init.bash\n' "$1" >&2
        time _ms_bash_load_file "$2/init.bash"
    else
        _ms_bash_load_file "$2/init.bash"
    fi
    for _ms_file in "$2"/completions/bash/*.bash; do
        [[ -f $_ms_file ]] && _ms_bash_completion_files+=("$_ms_file")
    done
    return 0
}

_ms_bash_load_completions() {
    local _ms_file _ms_name _ms_before _ms_rendered_dir
    _ms_rendered_dir=${_ms_bash_cache_dir:-$(_ms_bash_cache_path)}/completions/bash
    for _ms_file in "$_ms_rendered_dir"/*.bash; do
        [[ -f $_ms_file ]] && _ms_bash_completion_files+=("$_ms_file")
    done
    for _ms_file in "${_ms_bash_completion_files[@]}"; do
        _ms_name=${_ms_file##*/}
        _ms_name=${_ms_name%.bash}
        if _ms_bash_carapace_owns_command "$_ms_name"; then
            continue
        fi
        _ms_before=$(_ms_bash_effect complete "$_ms_name")
        _ms_bash_load_file "$_ms_file"
        _ms_bash_record_effect complete "$_ms_name" "$_ms_before" "$(_ms_bash_effect complete "$_ms_name")"
    done
}

_ms_bash_register_cleanup() {
    local _ms_body
    [[ $1 =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || return 1
    _ms_body=$(builtin declare -f -- "$1") || return 1
    if [[ ! ${_ms_bash_cleanup_definitions[$1]+yes} ]]; then
        _ms_bash_cleanup_order+=("$1")
    fi
    _ms_bash_cleanup_definitions[$1]=$_ms_body
}

_ms_bash_run_cleanups() {
    local _ms_i _ms_function
    for ((_ms_i=${#_ms_bash_cleanup_order[@]}-1; _ms_i>=0; _ms_i--)); do
        _ms_function=${_ms_bash_cleanup_order[_ms_i]}
        if [[ $(builtin declare -f -- "$_ms_function") == "${_ms_bash_cleanup_definitions[$_ms_function]}" ]]; then
            "$_ms_function" || :
        fi
    done
    _ms_bash_cleanup_order=() _ms_bash_cleanup_definitions=()
}

_ms_bash_notify() {
    [[ ${MARKSHARC_NOTIFY:-1} != 0 && ${_ms_bash_reloading-} != 1 ]] || return 0
    local sync_dir=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/$MARKSHARC_HOST/sync
    local notice='' generation='' last=0 hours=$1 now
    [[ ! -r $sync_dir/status ]] || notice=$(<"$sync_dir/status")
    [[ ! -r $sync_dir/generation ]] || generation=$(<"$sync_dir/generation")
    if [[ $notice == "behind${generation:+|$generation}" ]]; then
        printf '%s\n' 'marksharc: updates available (run marksharc sync)'
    fi
    [[ ! -r $sync_dir/checked ]] || IFS= read -r last < "$sync_dir/checked"
    [[ $last =~ ^[0-9]{1,12}$ ]] || last=0
    [[ $hours =~ ^[0-9]{1,9}$ ]] || hours=12
    printf -v now '%(%s)T' -1
    if [[ -x $MARKSHARC_HOME/core/cli/notify ]] &&
        (( now < 10#$last || now - 10#$last >= 10#$hours * 3600 )); then
        # Launch from a subshell so Bash does not create an interactive job.
        ( command nohup zsh -f "$MARKSHARC_HOME/core/cli/notify" --check </dev/null >/dev/null 2>&1 & )
    fi
}

_ms_bash_activate() {
    local _ms_bash_loading_init=1 _ms_bash_cache_dir=$1
    local -a _ms_bash_completion_files=()
    local -A _ms_bash_defs_before=() _ms_bash_defs_after=()
    unset _ms_bash_history_backend
    _ms_bash_snapshot_definitions _ms_bash_defs_before
    _ms_bash_load_file "$1/init.bash"
    _ms_bash_snapshot_definitions _ms_bash_defs_after
    _ms_bash_record_definitions _ms_bash_defs_before _ms_bash_defs_after
    _ms_bash_hooks_install
    if [[ ${_ms_bash_ble_attach_pending-} ]]; then
        unset _ms_bash_ble_attach_pending
        ble-attach
    fi
    return 0
}

_ms_bash_interactive_start() {
    local _ms_bash_verbose=${MARKSHARC_VERBOSE:-0}
    _ms_bash_interactive_pid=$BASHPID
    _ms_bash_activate "$1"
}

_ms_bash_reload() {
    local _ms_bash_verbose=${MARKSHARC_VERBOSE:-0} _ms_cache _ms_arg
    for _ms_arg in "$@"; do
        case $_ms_arg in
            --verbose|-v) _ms_bash_verbose=1 ;;
            *) printf 'marksharc reload: unknown option: %s\n' "$_ms_arg" >&2; return 2 ;;
        esac
    done
    _ms_cache=$(_ms_bash_cache_path)
    if ! command "$MARKSHARC_HOME/bin/marksharc" render ||
       ! _ms_bash_context_valid "$_ms_cache" init ||
       ! BASH_ENV='' "$BASH" --noprofile --norc -n "$_ms_cache/env.bash" ||
       ! BASH_ENV='' "$BASH" --noprofile --norc -n "$_ms_cache/init.bash"; then
        printf 'marksharc reload: could not render Bash startup files\n' >&2
        return 1
    fi
    _ms_bash_hooks_reset
    _ms_bash_run_cleanups
    _ms_bash_reset_effects
    _ms_bash_reset_path
    local _ms_bash_reloading=1
    _ms_bash_apply_env "$_ms_cache"
    _ms_bash_activate "$_ms_cache"
    if [[ $_ms_bash_verbose == 1 ]]; then printf 'Bash PATH: %s\n' "$PATH" >&2; fi
    return 0
}

function marksharc {
    if [[ ${1-} == reload ]]; then
        shift
        _ms_bash_reload "$@"
    elif [[ ${1-} == doctor ]]; then
        _ms_bash_select_backends
        MARKSHARC_BASH_VERSION=$BASH_VERSION MARKSHARC_BASH_HISTORY=${_ms_bash_history_backend-} \
            MARKSHARC_BASH_BACKENDS=$_ms_bash_active_editor/$_ms_bash_active_completion \
            MARKSHARC_BASH_PENDING=$_ms_bash_pending_editor/$_ms_bash_pending_completion \
            command "$MARKSHARC_HOME/bin/marksharc" "$@"
    else
        command "$MARKSHARC_HOME/bin/marksharc" "$@"
    fi
}

function cs { _ms_bash_reload --verbose; }
function li { _ms_bash_reload --verbose; }
