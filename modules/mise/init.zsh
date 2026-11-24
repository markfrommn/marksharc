# mise module, init phase. Activation is interactive-only and cached; compatibility
# functions remain thin translations rather than emulating nvm or gvm.
# Standalone double-source checks load init without the env phase. Missing ownership
# means legacy fallback; the real env phase replaces this predicate before normal init.
if (( ! ${+functions[_ms_mise_owns]} )); then
    _ms_mise_owns() { return 1; }
fi
if (( ! ${+functions[_ms_mise_drop_activation_paths]} )); then
    _ms_mise_drop_activation_paths() { return 0; }
fi

_ms_mise_has_cleanup_state() {
    (( ${+MARKSHARC_MISE_ACTIVATION_PATHS} || ${+MARKSHARC_MISE_SHIMS} || ${+MARKSHARC_MISE_SETTINGS_ACTIVE} ||
       ${+_ms_mise_activated} || ${+_ms_mise_activation} || ${+_ms_mise_cnf_tracked} ||
       ${+_ms_mise_compat_nvm} || ${+_ms_mise_compat_gvm} ))
}

typeset -gaU precmd_functions chpwd_functions

_ms_mise_compat_hint() {
    local tool=$1
    print -ru2 -- "mise compatibility: unsupported ${tool} manager command; use one of:"
    print -ru2 -- "  mise shell ${tool}@VERSION"
    print -ru2 -- "  mise install ${tool}@VERSION"
    print -ru2 -- "  mise ls ${tool}"
    print -ru2 -- "  mise current ${tool}"
    print -ru2 -- "  mise use --global ${tool}@VERSION"
    return 2
}

# Reload starts by unwrapping the previous activation and removing only compatibility
# functions this module defined. The restored activation function is either replaced
# below or removed when activation is no longer wanted.
_ms_mise_cleanup() {
    _ms_mise_has_cleanup_state || return 0
    typeset -gaU precmd_functions chpwd_functions
    precmd_functions=( ${precmd_functions:#_mise_hook_precmd} )
    chpwd_functions=( ${chpwd_functions:#_mise_hook_chpwd} )
    _ms_mise_drop_activation_paths
    if [[ ${_ms_mise_cnf_tracked-} == 1 && ${functions[command_not_found_handler]-} == "${_ms_mise_cnf_definition-}" ]]; then
        if (( ${+functions[_command_not_found_handler]} )); then
            functions[command_not_found_handler]=$functions[_command_not_found_handler]
        else
            unfunction command_not_found_handler 2>/dev/null
        fi
    fi
    unset _ms_mise_cnf_tracked _ms_mise_cnf_definition
    unfunction _command_not_found_handler _mise_hook_env_state 2>/dev/null
    unset MISE_SHELL MISE_NODE_VERSION MISE_GO_VERSION MISE_PYTHON_VERSION MISE_RUBY_VERSION
    unset __MISE_ORIG_PATH __MISE_ZSH_PRECMD_RUN __MISE_ZSH_CHPWD_RAN __MISE_ZSH_ACTIVATE_PATH __MISE_ZSH_ACTIVATE_ENV __MISE_SESSION __MISE_DIFF _mise_cmd_not_found
    unfunction _mise_hook _mise_hook_precmd _mise_hook_chpwd _ms_mise_hook 2>/dev/null
    if (( ${+functions[_ms_mise_activated]} )); then
        if [[ ${1-} == deactivate ]]; then
            unfunction mise 2>/dev/null
        else
            functions[mise]=$functions[_ms_mise_activated]
        fi
        unfunction _ms_mise_activated
    fi
    if [[ ${_ms_mise_compat_nvm-} == 1 ]]; then
        [[ ${functions[nvm]-} != "${_ms_mise_compat_nvm_definition-}" ]] || unfunction nvm 2>/dev/null
        unset _ms_mise_compat_nvm _ms_mise_compat_nvm_definition
    fi
    if [[ ${_ms_mise_compat_gvm-} == 1 ]]; then
        [[ ${functions[gvm]-} != "${_ms_mise_compat_gvm_definition-}" ]] || unfunction gvm 2>/dev/null
        unset _ms_mise_compat_gvm _ms_mise_compat_gvm_definition
    fi
    if (( ! ${_ms_plan[(Ie)mise]} )); then
        unfunction mise 2>/dev/null
        unset MISE_NOT_FOUND_AUTO_INSTALL MISE_GO_SET_GOBIN MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS
    fi
}
typeset -gaU _ms_init_cleanups
_ms_init_cleanups+=( _ms_mise_cleanup )

typeset -g _ms_mise_active=0 _ms_mise_tool
for _ms_mise_tool in node go python ruby; do
    if _ms_mise_owns "$_ms_mise_tool"; then _ms_mise_active=1; fi
done

if _ms_mise_owns node; then
    chpwd_functions=( ${chpwd_functions:#load-nvmrc} )
    if [[ ${_ms_nvm_first_use_stub-} == 1 ]]; then
        unfunction nvm 2>/dev/null
        unset _ms_nvm_first_use_stub _ms_nvm_loaded
    fi
    if [[ ${_ms_opt_mise_compat-on} == (on|1|yes|true) ]] && (( ! ${+functions[nvm]} )); then
        nvm() {
            local verb=${1-} version
            case $verb in
                use)
                    (( $# >= 2 )) || { _ms_mise_compat_hint node; return 2; }
                    version=$2
                    shift 2
                    mise shell "node@$version" "$@"
                    ;;
                install)
                    (( $# >= 2 )) || { _ms_mise_compat_hint node; return 2; }
                    version=$2
                    shift 2
                    mise install "node@$version" "$@"
                    ;;
                ls)
                    shift
                    mise ls node "$@"
                    ;;
                current)
                    shift
                    mise current node "$@"
                    ;;
                alias)
                    if (( $# >= 3 )) && [[ $2 == default ]]; then
                        version=$3
                        shift 3
                        mise use --global "node@$version" "$@"
                    else
                        _ms_mise_compat_hint node
                        return 2
                    fi
                    ;;
                *)
                    _ms_mise_compat_hint node
                    return 2
                    ;;
            esac
        }
        typeset -g _ms_mise_compat_nvm=1 _ms_mise_compat_nvm_definition=$functions[nvm]
    fi
fi

if _ms_mise_owns go; then
    chpwd_functions=( ${chpwd_functions:#_gvm_auto_use} )
    if [[ ${_ms_gvm_first_use_stub-} == 1 ]]; then
        unfunction gvm 2>/dev/null
        unset _ms_gvm_first_use_stub _ms_gvm_loaded
    fi
    if [[ ${_ms_opt_mise_compat-on} == (on|1|yes|true) ]] && (( ! ${+functions[gvm]} )); then
        gvm() {
            local verb=${1-} version
            case $verb in
                use)
                    (( $# >= 2 )) || { _ms_mise_compat_hint go; return 2; }
                    version=${2#go}
                    shift 2
                    mise shell "go@$version" "$@"
                    ;;
                install)
                    (( $# >= 2 )) || { _ms_mise_compat_hint go; return 2; }
                    version=${2#go}
                    shift 2
                    mise install "go@$version" "$@"
                    ;;
                ls|list)
                    shift
                    mise ls go "$@"
                    ;;
                current)
                    shift
                    mise current go "$@"
                    ;;
                alias)
                    if (( $# >= 3 )) && [[ $2 == default ]]; then
                        version=${3#go}
                        shift 3
                        mise use --global "go@$version" "$@"
                    else
                        _ms_mise_compat_hint go
                        return 2
                    fi
                    ;;
                *)
                    _ms_mise_compat_hint go
                    return 2
                    ;;
            esac
        }
        typeset -g _ms_mise_compat_gvm=1 _ms_mise_compat_gvm_definition=$functions[gvm]
    fi
fi
unset _ms_mise_tool

typeset -g _ms_mise_now_active=0
if (( _ms_mise_active )) && [[ ${_ms_opt_mise_hook-chpwd} != off ]]; then
    (( ${+commands[mise]} )) || rehash
    typeset -g _ms_mise_executable=${commands[mise]-}
    typeset -ga _ms_mise_before_activation=( "${path[@]}" )
    if _ms_init_cached -k "${_ms_opt_mise_auto_install-off}|${PATH}" mise "$_ms_mise_executable" activate zsh; then
        # With not-found auto-install disabled, upstream activation removes its shim
        # directory. Reapply the tier builder so manager shims survive initial activation.
        (( ${+functions[_ms_path_build]} )) && _ms_path_build
        _ms_mise_track_activation_paths _ms_mise_before_activation
        typeset -g _ms_mise_cnf_tracked=1 _ms_mise_cnf_definition=${functions[command_not_found_handler]-}
        if (( ${+functions[_mise_hook]} )); then
            functions[_ms_mise_hook]=$functions[_mise_hook]
            _mise_hook() {
                local -a before=( "${path[@]}" )
                _ms_mise_hook "$@"
                local result=$?
                (( ${+functions[_ms_path_build]} )) && _ms_path_build
                _ms_mise_track_activation_paths before
                return $result
            }
        fi
        if (( ${+functions[mise]} )); then
            functions[_ms_mise_activated]=$functions[mise]
            mise() {
                _ms_mise_activated "$@"
                local result=$? verb=${1-}
                if (( result == 0 )) && [[ $verb == deactivate ]]; then
                    _ms_mise_cleanup deactivate
                elif (( result == 0 )) && [[ $verb == (shell|sh|use|unuse) ]] && (( ${+functions[_mise_hook]} )); then
                    _mise_hook
                fi
                return $result
            }
            typeset -g _ms_mise_activation=1 _ms_mise_now_active=1
        fi
    fi
fi

if (( _ms_mise_now_active )); then
    if [[ ${_ms_opt_mise_hook-chpwd} == chpwd ]]; then
        precmd_functions=( ${precmd_functions:#_mise_hook_precmd} )
    fi
else
    if _ms_mise_has_cleanup_state; then
        precmd_functions=( ${precmd_functions:#_mise_hook_precmd} )
        chpwd_functions=( ${chpwd_functions:#_mise_hook_chpwd} )
        _ms_mise_drop_activation_paths
        if [[ ${_ms_mise_cnf_tracked-} == 1 && ${functions[command_not_found_handler]-} == "${_ms_mise_cnf_definition-}" ]]; then
            if (( ${+functions[_command_not_found_handler]} )); then
                functions[command_not_found_handler]=$functions[_command_not_found_handler]
            else
                unfunction command_not_found_handler 2>/dev/null
            fi
        fi
        unset _ms_mise_cnf_tracked _ms_mise_cnf_definition
        unfunction _command_not_found_handler _mise_hook_env_state 2>/dev/null
        unset MISE_SHELL MISE_NODE_VERSION MISE_GO_VERSION MISE_PYTHON_VERSION MISE_RUBY_VERSION
        unset __MISE_ORIG_PATH __MISE_ZSH_PRECMD_RUN __MISE_ZSH_CHPWD_RAN __MISE_ZSH_ACTIVATE_PATH __MISE_ZSH_ACTIVATE_ENV __MISE_SESSION __MISE_DIFF _mise_cmd_not_found
        unfunction _mise_hook _mise_hook_precmd _mise_hook_chpwd _ms_mise_hook 2>/dev/null
        if [[ ${_ms_mise_activation-} == 1 ]]; then
            unfunction mise 2>/dev/null
            unset _ms_mise_activation
        fi
    fi
fi
unset _ms_mise_active _ms_mise_now_active _ms_mise_executable _ms_mise_before_activation
true
