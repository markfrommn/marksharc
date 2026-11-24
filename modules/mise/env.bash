# Native Bash mise ownership, safe exports and legacy PATH filtering.
_ms_mise_owns() {
    [[ ${_ms_bash_mise_module_enabled-0} == 1 ]] || return 1
    case ${1-} in node|go|python|ruby) ;; *) return 1 ;; esac
    _ms_command_available mise || return 1
    local tool
    for tool in ${_ms_opt_mise_tools-}; do
        [[ $tool == "$1" ]] && return 0
    done
    return 1
}

_ms_bash_mise_filter_path() {
    local entry oldifs=$IFS
    local nvm_root=${NVM_DIR:-$HOME/.nvm} gvm_root=${GVM_ROOT:-$HOME/.gvm}
    local pyenv_root=${PYENV_ROOT:-$HOME/.pyenv}
    local -a inherited=() kept=() gopath_parts=() gopath_kept=()
    local part
    if [[ " ${_ms_mise_owned_tools[*]} " == *' go '* ]]; then
        if [[ -n ${GOPATH-} ]]; then
            IFS=: read -r -a gopath_parts <<< "$GOPATH"
            for part in "${gopath_parts[@]}"; do
                [[ $part == "$gvm_root"/pkgsets/* ]] || gopath_kept+=("$part")
            done
            if (( ${#gopath_kept[@]} )); then
                IFS=:
                GOPATH="${gopath_kept[*]}"
                IFS=$oldifs
                export GOPATH
            else
                unset GOPATH
            fi
        fi
        [[ ${GVM_OVERLAY_PREFIX-} == "$gvm_root"/pkgsets/* ]] && unset GVM_OVERLAY_PREFIX
        [[ ${GOROOT-} == "$gvm_root"/gos/* ]] && unset GOROOT
        unset gvm_go_name gvm_pkgset_name
    fi
    IFS=: read -r -a inherited <<< "$PATH"
    IFS=$oldifs
    for entry in "${inherited[@]}"; do
        if [[ " ${_ms_mise_owned_tools[*]} " == *' node '* && $entry == "$nvm_root"/versions/node/* ]]; then
            continue
        fi
        if [[ " ${_ms_mise_owned_tools[*]} " == *' go '* ]] &&
            [[ $entry == "$gvm_root"/gos/* || $entry == "$gvm_root"/pkgsets/* || $entry == "$gvm_root"/bin ]]; then
            continue
        fi
        if [[ " ${_ms_mise_owned_tools[*]} " == *' python '* ]] &&
            [[ $entry == "$pyenv_root"/shims || $entry == "$pyenv_root"/bin ]]; then
            continue
        fi
        kept+=("$entry")
    done
    IFS=:
    PATH="${kept[*]}"
    IFS=$oldifs
    export PATH
}

_ms_mise_owned_tools=()
_ms_mise_configured=0
for _ms_mise_tool in node go python ruby; do
    [[ " ${_ms_opt_mise_tools-} " == *" $_ms_mise_tool "* ]] || continue
    _ms_mise_configured=1
    if _ms_mise_owns "$_ms_mise_tool"; then _ms_mise_owned_tools+=("$_ms_mise_tool"); fi
done
unset _ms_mise_tool
_ms_mise_shims=${MISE_SHIMS_DIR:-${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims}

if (( ${#_ms_mise_owned_tools[@]} )); then
    case ${_ms_opt_mise_auto_install-off} in
        on|1|yes|true) export MISE_NOT_FOUND_AUTO_INSTALL=true ;;
        *) export MISE_NOT_FOUND_AUTO_INSTALL=false ;;
    esac
    case ${_ms_opt_mise_set_gobin-off} in
        on|1|yes|true) export MISE_GO_SET_GOBIN=true ;;
        *) export MISE_GO_SET_GOBIN=false ;;
    esac
    case ${_ms_opt_mise_version_files-on} in
        on|1|yes|true)
            _ms_mise_oldifs=$IFS
            IFS=,
            MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS="${_ms_mise_owned_tools[*]}"
            IFS=$_ms_mise_oldifs
            unset _ms_mise_oldifs
            export MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS
            ;;
        *) export MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS= ;;
    esac
    _ms_mise_exports_active=1
    export MARKSHARC_MISE_SHIMS="$_ms_mise_shims" MARKSHARC_MISE_SETTINGS_ACTIVE=1
    _ms_bash_mise_filter_path
    _ms_bash_add manager "$_ms_mise_shims"
elif [[ -n ${_ms_mise_exports_active-} ]]; then
    unset MISE_NOT_FOUND_AUTO_INSTALL MISE_GO_SET_GOBIN MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS
    unset _ms_mise_exports_active
fi
if (( ! ${#_ms_mise_owned_tools[@]} && _ms_mise_configured )) && ! _ms_command_available mise; then
    _ms_mise_oldifs=$IFS
    _ms_mise_inherited=() _ms_mise_kept=()
    IFS=: read -r -a _ms_mise_inherited <<< "$PATH"
    IFS=$_ms_mise_oldifs
    for _ms_mise_tool in "${_ms_mise_inherited[@]}"; do
        [[ $_ms_mise_tool == "$_ms_mise_shims" ]] || _ms_mise_kept+=("$_ms_mise_tool")
    done
    IFS=:
    PATH="${_ms_mise_kept[*]}"
    IFS=$_ms_mise_oldifs
    export PATH
    unset _ms_mise_oldifs _ms_mise_inherited _ms_mise_kept _ms_mise_tool
fi
unset _ms_mise_shims _ms_mise_configured
true
