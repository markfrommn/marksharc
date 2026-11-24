# mise module, env phase. Ownership is per supported tool and requires both an
# explicit option entry and a usable mise executable. No mise command runs here.
_ms_mise_owns() {
    (( ${_ms_plan[(Ie)mise]} )) || return 1
    [[ $1 == (node|go|python|ruby) ]] || return 1
    _ms_command_available mise || return 1
    local -a tools=( ${=_ms_opt_mise_tools-} )
    (( ${tools[(Ie)$1]} ))
}

_ms_mise_track_activation_paths() {
    local array_name=$1 entry
    local -a before=( "${(@P)array_name}" ) next=()
    for entry in "${path[@]}"; do
        if (( ${_ms_mise_activation_paths[(Ie)$entry]} || ! ${before[(Ie)$entry]} )); then
            next+=( "$entry" )
        fi
    done
    typeset -ga _ms_mise_activation_paths=( "${next[@]}" )
    export MARKSHARC_MISE_ACTIVATION_PATHS=${(j.:.)_ms_mise_activation_paths}
}

typeset -ga _ms_mise_activation_paths=()

# Remove inherited entries belonging only to legacy managers whose tools mise now
# owns. Unrelated manager directories stay in their original PATH position.
_ms_mise_filter_path() {
    local entry nvm_root=${NVM_DIR:-$HOME/.nvm} gvm_root=${GVM_ROOT:-$HOME/.gvm}
    local pyenv_root=${PYENV_ROOT:-$HOME/.pyenv}
    local -a kept=() gopath_parts=() gopath_kept=()
    if (( ${_ms_mise_owned_tools[(Ie)go]} )); then
        if [[ -n ${GOPATH-} ]]; then
            gopath_parts=( ${(s.:.)GOPATH} )
            for entry in "${gopath_parts[@]}"; do
                [[ $entry == "$gvm_root"/pkgsets/* ]] || gopath_kept+=( "$entry" )
            done
            if (( $#gopath_kept )); then
                export GOPATH=${(j.:.)gopath_kept}
            else
                unset GOPATH
            fi
        fi
        [[ ${GVM_OVERLAY_PREFIX-} == "$gvm_root"/pkgsets/* ]] && unset GVM_OVERLAY_PREFIX
        [[ ${GOROOT-} == "$gvm_root"/gos/* ]] && unset GOROOT
        unset gvm_go_name gvm_pkgset_name
    fi
    for entry in "${path[@]}"; do
        if (( ${_ms_mise_owned_tools[(Ie)node]} )) && [[ $entry == "$nvm_root"/versions/node/* ]]; then
            continue
        fi
        if (( ${_ms_mise_owned_tools[(Ie)go]} )) &&
            [[ $entry == "$gvm_root"/gos/* || $entry == "$gvm_root"/pkgsets/* || $entry == "$gvm_root"/bin ]]; then
            continue
        fi
        if (( ${_ms_mise_owned_tools[(Ie)python]} )) && [[ $entry == "$pyenv_root"/shims || $entry == "$pyenv_root"/bin ]]; then
            continue
        fi
        kept+=( "$entry" )
    done
    path=( "${kept[@]}" )
}

typeset -ga _ms_mise_owned_tools=() _ms_mise_configured_tools=()
typeset -ga _ms_mise_requested_tools=( ${=_ms_opt_mise_tools-} )
typeset -g _ms_mise_tool
for _ms_mise_tool in node go python ruby; do
    (( ${_ms_mise_requested_tools[(Ie)$_ms_mise_tool]} )) || continue
    _ms_mise_configured_tools+=( "$_ms_mise_tool" )
    _ms_mise_owns "$_ms_mise_tool" && _ms_mise_owned_tools+=( "$_ms_mise_tool" )
done
unset _ms_mise_tool

if (( $#_ms_mise_owned_tools )); then
    if (( ${_ms_env_rebuild:-1} )); then
        case ${_ms_opt_mise_auto_install-off} in
            on|1|yes|true) export MISE_NOT_FOUND_AUTO_INSTALL=true ;;
            *) export MISE_NOT_FOUND_AUTO_INSTALL=false ;;
        esac
        case ${_ms_opt_mise_set_gobin-off} in
            on|1|yes|true) export MISE_GO_SET_GOBIN=true ;;
            *) export MISE_GO_SET_GOBIN=false ;;
        esac
        case ${_ms_opt_mise_version_files-on} in
            on|1|yes|true) export MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS=${(j:,:)_ms_mise_owned_tools} ;;
            *) export MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS= ;;
        esac
        typeset -g _ms_mise_exports_active=1
        _ms_mise_filter_path
        if (( ${+functions[_ms_path_add]} )); then
            typeset -g _ms_mise_shims=${MISE_SHIMS_DIR:-${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims}
            export MARKSHARC_MISE_SHIMS="$_ms_mise_shims" MARKSHARC_MISE_SETTINGS_ACTIVE=1
            _ms_path_add manager "$_ms_mise_shims"
            unset _ms_mise_shims
        fi
    fi
elif [[ -n ${_ms_mise_exports_active-} ]]; then
    unset MISE_NOT_FOUND_AUTO_INSTALL MISE_GO_SET_GOBIN MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS
    unset _ms_mise_exports_active
fi
if (( ! $#_ms_mise_owned_tools && $#_ms_mise_configured_tools )) && ! _ms_command_available mise; then
    typeset -g _ms_mise_shims=${MISE_SHIMS_DIR:-${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims}
    typeset -ga _ms_mise_fallback_path=()
    for _ms_mise_tool in "${path[@]}"; do
        [[ $_ms_mise_tool == "$_ms_mise_shims" ]] || _ms_mise_fallback_path+=( "$_ms_mise_tool" )
    done
    path=( "${_ms_mise_fallback_path[@]}" )
    unset _ms_mise_shims _ms_mise_fallback_path
fi
unset _ms_mise_configured_tools _ms_mise_requested_tools
true
