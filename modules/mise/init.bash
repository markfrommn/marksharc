_ms_bash_mise_module_enabled=1
_ms_bash_mise_active=0

_ms_bash_mise_track_paths() {
    local entry IFS=:
    local -a current owned=()
    read -r -a current <<< "$PATH"
    for entry in "${current[@]}"; do
        if [[ :${MARKSHARC_MISE_ACTIVATION_PATHS-}: == *":$entry:"* || :$1: != *":$entry:"* ]]; then
            owned+=("$entry")
        fi
    done
    export MARKSHARC_MISE_ACTIVATION_PATHS="${owned[*]}"
}

_ms_bash_mise_hook() {
    [[ $_ms_bash_mise_active == 1 ]] || return 0
    local before=$PATH code
    code=$(command mise hook-env --quiet --shell bash "$@" 2>/dev/null) || return
    builtin eval "$code" || return
    # Reassert the configured tier order and keep explicit activations ahead of it.
    _ms_bash_finish
    _ms_bash_mise_track_paths "$before"
}

_ms_bash_mise_prompt() { _ms_bash_mise_hook; }

_ms_bash_mise_deactivate() {
    [[ $_ms_bash_mise_active == 1 ]] || return 0
    local code status=0 path_before=$PATH name
    local PROMPT_COMMAND='' _mise_cmd_not_found_handle=${_mise_cmd_not_found_handle-}
    # shellcheck disable=SC2034 # Consumed by mise's generated deactivation.
    local -a chpwd_functions=()
    local -A functions=()
    for name in mise _mise_hook command_not_found_handle _command_not_found_handle; do
        functions[$name]=$(_ms_bash_effect function "$name")
    done
    if code=$(command mise deactivate "$@"); then
        builtin eval "$code" || status=$?
    else
        status=$?
    fi
    for name in "${!functions[@]}"; do
        _ms_bash_restore_effect function "$name" "${functions[$name]}"
    done
    if [[ ${_ms_bash_installed[function:command_not_found_handle]+yes} &&
          ${functions[command_not_found_handle]} == "${_ms_bash_installed[function:command_not_found_handle]}" ]]; then
        # shellcheck disable=SC2154 # The interactive runtime declares the registry.
        _ms_bash_restore_effect function command_not_found_handle "${_ms_bash_previous[function:command_not_found_handle]}"
        unset '_ms_bash_installed[function:command_not_found_handle]' '_ms_bash_previous[function:command_not_found_handle]'
    fi
    # Upstream may reset PATH to its initial value, discarding other activations.
    export PATH=$path_before
    _ms_bash_mise_drop_activation_paths
    unset MISE_SHELL MISE_NODE_VERSION MISE_GO_VERSION MISE_PYTHON_VERSION MISE_RUBY_VERSION \
        __MISE_ORIG_PATH __MISE_EXE __MISE_FLAGS __MISE_HOOK_ENABLED \
        __MISE_BASH_CHPWD_RAN __MISE_SESSION __MISE_DIFF _mise_cmd_not_found
    _ms_bash_mise_active=0
    if ! _ms_mise_owns go; then _ms_bash_gvm_sync_goroot; fi
    return "$status"
}

_ms_bash_mise_cleanup() { _ms_bash_mise_deactivate >/dev/null 2>&1; }

_ms_bash_mise_run() {
    local verb=${1-} arg code
    if [[ $_ms_bash_mise_active != 1 ]]; then command mise "$@"; return; fi
    for arg in "$@"; do
        case $arg in -h|--help) command mise "$@"; return ;; esac
    done
    case $verb in
        deactivate)
            shift
            _ms_bash_mise_deactivate "$@" ;;
        shell|sh)
            # Use the provider's shell protocol and propagate errors before
            # applying any output.
            code=$(MISE_SHELL=bash command mise "$@") || return
            builtin eval "$code" || return
            _ms_bash_mise_hook --force ;;
        use|unuse)
            command mise "$@" || return
            _ms_bash_mise_hook --force ;;
        *) command mise "$@" ;;
    esac
}

_ms_bash_mise_compat() {
    local tool=$1 verb=${2-} version=${3-}
    shift
    [[ $tool != go ]] || version=${version#go}
    case $verb in
        use|install)
            if (( $# >= 2 )); then
                shift 2
                [[ $verb != use ]] || verb=shell
                mise "$verb" "$tool@$version" "$@"
                return
            fi ;;
        ls|list|current)
            shift
            [[ $verb != list ]] || verb='ls'
            mise "$verb" "$tool" "$@"
            return ;;
        alias)
            if (( $# >= 3 )) && [[ $2 == default ]]; then
                version=$3
                [[ $tool != go ]] || version=${version#go}
                shift 3
                mise use --global "$tool@$version" "$@"
                return
            fi ;;
    esac
    printf 'mise compatibility: use mise shell %s@VERSION, mise install %s@VERSION, or mise ls %s\n' "$tool" "$tool" "$tool" >&2
    return 2
}

_ms_bash_mise_init() {
    local tool mode=${_ms_opt_mise_hook-chpwd} before=$PATH
    local PROMPT_COMMAND=''
    for tool in node go python ruby; do
        _ms_mise_owns "$tool" && break
    done
    _ms_mise_owns "$tool" || return 0
    case $mode in
        off) ;;
        *)
            if _ms_bash_init_cached -k "${_ms_opt_mise_auto_install-off}|$PATH" mise \
                mise activate bash --no-hook-env >/dev/null 2>&1 && [[ ${MISE_SHELL-} == bash ]]; then
                _ms_bash_mise_active=1
                _ms_bash_register_cleanup _ms_bash_mise_cleanup
                case $mode in
                    prompt) _ms_bash_register_prompt _ms_bash_mise_prompt ;;
                    *) _ms_bash_register_chpwd _ms_bash_mise_hook ;;
                esac
            fi
            # Activation can emit a PATH prelude including the environment it
            # ran in. The Bash env builder already placed shims in their tier.
            export PATH=$before ;;
    esac
    if [[ $_ms_bash_mise_active == 1 ]]; then function mise { _ms_bash_mise_run "$@"; }; fi
    case ${_ms_opt_mise_compat-on} in
        on|1|yes|true)
            if _ms_mise_owns node && ! declare -F nvm >/dev/null; then function nvm { _ms_bash_mise_compat node "$@"; }; fi
            if _ms_mise_owns go && ! declare -F gvm >/dev/null; then function gvm { _ms_bash_mise_compat go "$@"; }; fi ;;
    esac
}
_ms_bash_mise_init
