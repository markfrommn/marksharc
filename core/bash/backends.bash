# Editor and completion providers are selected once per interactive process.
_ms_bash_find_bash_completion() {
    local candidate prefix
    _ms_bash_completion_file=
    if [[ ${BASH_COMPLETION_VERSINFO[0]-} ]]; then return 0; fi
    for prefix in "${HOMEBREW_PREFIX-}" /opt/homebrew /usr/local /usr; do
        [[ -n $prefix ]] || continue
        for candidate in "$prefix"/{,opt/bash-completion@2/}share/bash-completion/bash_completion; do
            if [[ -f $candidate && -r $candidate ]]; then
                _ms_bash_completion_file=$candidate
                return 0
            fi
        done
    done
    if [[ -f /etc/bash_completion && -r /etc/bash_completion ]]; then
        _ms_bash_completion_file=/etc/bash_completion
        return 0
    fi
    return 1
}

_ms_bash_find_ble() {
    local pin
    _ms_bash_ble_file=
    [[ ${_ms_bash_editor_module-} && -r $_ms_bash_editor_module/ble.pin ]] || return 1
    IFS= read -r pin < "$_ms_bash_editor_module/ble.pin" || return 1
    [[ $pin =~ ^[0-9a-f]{40}$ ]] || return 1
    _ms_bash_ble_file=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/plugins/ble.sh@$pin/out/ble.sh
    [[ -f $_ms_bash_ble_file && -r $_ms_bash_ble_file ]]
}

_ms_bash_select_backends() {
    _ms_bash_pending_editor=readline
    if [[ ${MARKSHARC_BASH_EDITOR-} != readline && ${TERM-} != dumb ]] && _ms_bash_find_ble; then
        _ms_bash_pending_editor=ble
    fi
    _ms_bash_pending_completion=native
    if [[ ${_ms_bash_bash_completion-} == 1 ]] && _ms_bash_find_bash_completion; then
        _ms_bash_pending_completion=bash-completion
    fi
    local selection=${MARKSHARC_BASH_COMPLETION_UI-}
    if [[ ${_ms_bash_carapace-disabled} != disabled && $selection != native &&
          ( $selection == carapace || ${_ms_bash_carapace-} == enabled ) ]] &&
        builtin type -P carapace >/dev/null; then
        _ms_bash_pending_completion=carapace
    fi
}

_ms_bash_completion_list() {
    local value=${1//,/ } IFS=$' \t\n'
    local -a words
    read -r -a words <<< "$value"
    if (( ${#words[@]} == 1 )) && [[ ${words[0],,} == off || ${words[0],,} == none ]]; then
        words=()
    fi
    local IFS=,
    REPLY=${words[*]}
}

_ms_bash_load_carapace() {
    local REPLY prior definition status=0
    local prior_bridges=${CARAPACE_BRIDGES-} prior_excludes=${CARAPACE_EXCLUDES-}
    local had_bridges=${CARAPACE_BRIDGES+x} had_excludes=${CARAPACE_EXCLUDES+x}
    # A provider's broad registration must not take over an already installed
    # specialized completion. Modules register their own completions later.
    prior=$(builtin complete -p)
    _ms_bash_completion_list "$1"
    if [[ $REPLY ]]; then export CARAPACE_BRIDGES=$REPLY; else unset CARAPACE_BRIDGES; fi
    _ms_bash_completion_list "$2"
    if [[ $REPLY ]]; then export CARAPACE_EXCLUDES=$REPLY; else unset CARAPACE_EXCLUDES; fi
    _ms_bash_init_cached -k "${CARAPACE_BRIDGES-}|${CARAPACE_EXCLUDES-}" carapace carapace _carapace bash \
        >/dev/null 2>&1 || status=$?
    while IFS= read -r definition; do
        [[ $definition == 'complete '* ]] || continue
        builtin eval "builtin $definition"
    done <<< "$prior"
    if (( status == 0 )) && declare -F _carapace_completer >/dev/null; then
        export MARKSHARC_BASH_CARAPACE_ACTIVE=1
        return 0
    fi
    if [[ $had_bridges ]]; then export CARAPACE_BRIDGES=$prior_bridges; else unset CARAPACE_BRIDGES; fi
    if [[ $had_excludes ]]; then export CARAPACE_EXCLUDES=$prior_excludes; else unset CARAPACE_EXCLUDES; fi
    return 1
}

_ms_bash_init_backends() {
    _ms_bash_editor_module=$1
    _ms_bash_bash_completion=$2
    _ms_bash_carapace=$3
    _ms_bash_select_backends
    if [[ ${_ms_bash_active_editor-} ]]; then
        if [[ $_ms_bash_active_editor != "$_ms_bash_pending_editor" ||
              $_ms_bash_active_completion != "$_ms_bash_pending_completion" ||
              ( $_ms_bash_active_completion == carapace &&
                ( $_ms_bash_active_bridges != "$4" || $_ms_bash_active_excludes != "$5" ) ) ]]; then
            completion-ui status
            printf '%s\n' "completion-ui: run 'exec bash -l' to apply pending settings"
        fi
        return 0
    fi
    _ms_bash_active_editor=readline
    if declare -F blehook >/dev/null; then
        _ms_bash_active_editor=ble
    elif [[ $_ms_bash_pending_editor == ble ]]; then
        # shellcheck disable=SC1090
        if source "$_ms_bash_ble_file" --attach=none &&
           declare -F blehook ble-attach >/dev/null; then
            _ms_bash_active_editor=ble
            _ms_bash_ble_attach_pending=1
        fi
    fi
    _ms_bash_active_completion=native
    if [[ ${MARKSHARC_BASH_CARAPACE_ACTIVE-} ]]; then
        unset CARAPACE_BRIDGES CARAPACE_EXCLUDES MARKSHARC_BASH_CARAPACE_ACTIVE
    fi
    if [[ $_ms_bash_bash_completion == 1 ]] && _ms_bash_find_bash_completion; then
        if [[ ! $_ms_bash_completion_file ]] || _ms_bash_source_completion; then
            _ms_bash_active_completion=bash-completion
        fi
    fi
    if [[ $_ms_bash_pending_completion == carapace ]] && _ms_bash_load_carapace "$4" "$5"; then
        _ms_bash_active_completion=carapace
        _ms_bash_active_bridges=$4 _ms_bash_active_excludes=$5
    fi
    # Providers survive reload. Avoid serializing the editor and completion
    # libraries' definitions for every init and every reload.
    local function_name
    while IFS= read -r function_name; do
        if [[ ! ${_ms_bash_defs_before[function:$function_name]+yes} ]]; then
            # shellcheck disable=SC2004 # Associative keys are function names.
            _ms_bash_process_functions[$function_name]=1
        fi
    done < <(compgen -A function)
}

_ms_bash_source_completion() {
    # Upstream helpers depend on their own global state.
    # shellcheck disable=SC1090
    source "$_ms_bash_completion_file" >/dev/null 2>&1
}

_ms_bash_binding_dump() {
    # Before deferred attach, ble.sh's bind listings come from Readline.
    # Skip the editor's parser when reading those same definitions.
    if [[ ${_ms_bash_ble_attach_pending-} ]]; then
        builtin bind "$@"
    else
        bind "$@"
    fi
}

_ms_bash_load_generated_completion() {
    local artifact=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/$MARKSHARC_HOST/completions-bash/$1.bash
    if _ms_bash_artifact_matches "$artifact" "$MARKSHARC_ENV"; then
        # shellcheck source=/dev/null
        source "$artifact"
    fi
}

completion-ui() {
    local action=${1-status}
    if (( $# > 1 )); then action=usage; fi
    case $action in
        status)
            _ms_bash_select_backends
            printf 'completion-ui: active=%s/%s pending=%s/%s\n' \
                "$_ms_bash_active_editor" "$_ms_bash_active_completion" \
                "$_ms_bash_pending_editor" "$_ms_bash_pending_completion"
            return 0 ;;
        ble)
            if ! _ms_bash_find_ble; then
                printf '%s\n' 'completion-ui: enable line-editor-ble and run marksharc install ble.sh' >&2
                return 1
            fi
            export MARKSHARC_BASH_EDITOR=ble ;;
        readline) export MARKSHARC_BASH_EDITOR=readline ;;
        native) export MARKSHARC_BASH_COMPLETION_UI=native ;;
        carapace)
            if [[ $_ms_bash_carapace == disabled ]] || ! builtin type -P carapace >/dev/null; then
                printf '%s\n' 'completion-ui: Carapace must be installed and its module enabled' >&2
                return 1
            fi
            export MARKSHARC_BASH_COMPLETION_UI=carapace ;;
        reset) unset MARKSHARC_BASH_EDITOR MARKSHARC_BASH_COMPLETION_UI ;;
        *)
            printf '%s\n' 'Usage: completion-ui [status | ble | readline | native | carapace | reset]' >&2
            return 2 ;;
    esac
    completion-ui status
    printf '%s\n' "completion-ui: run 'exec bash -l' to apply"
}
