_ms_mise_owns go && return 0
[[ -r ${GVM_ROOT:-$HOME/.gvm}/scripts/gvm ]] || return 0

_ms_bash_gvm_load() {
    local definition rc=0 name
    declare -F _ms_bash_gvm_loaded >/dev/null && return 0
    # shellcheck disable=SC2034 # Names passed to the ownership helpers.
    local -A before=() after=()
    _ms_bash_snapshot_definitions before
    unset -f gvm
    _ms_bash_gvm_source || rc=$?
    definition=$(builtin declare -f gvm) || rc=1
    if (( rc == 0 )); then builtin eval "_ms_bash_gvm_loaded${definition#gvm}"; fi
    for name in gvm cd pushd popd; do
        _ms_bash_restore_effect function "$name" "${before[function:$name]-}"
    done
    _ms_bash_snapshot_definitions after
    _ms_bash_record_definitions before after
    return "$rc"
}

_ms_bash_gvm_source() {
    # The provider sources its default activation on load. Keep the PATH,
    # Go/pkgset selection, and directory state the env phase already chose.
    local PATH=$PATH OLDPWD=${OLDPWD-} GOROOT=${GOROOT-} GOPATH=${GOPATH-} GOBIN=${GOBIN-}
    local gvm_go_name=${gvm_go_name-} gvm_pkgset_name=${gvm_pkgset_name-}
    local GVM_OVERLAY_PREFIX=${GVM_OVERLAY_PREFIX-} LD_LIBRARY_PATH=${LD_LIBRARY_PATH-}
    local DYLD_LIBRARY_PATH=${DYLD_LIBRARY_PATH-} PKG_CONFIG_PATH=${PKG_CONFIG_PATH-}
    # shellcheck disable=SC1091
    source "$GVM_ROOT/scripts/gvm" >/dev/null 2>&1
}

_ms_bash_gvm_run() {
    local status=0
    _ms_bash_gvm_load || return
    _ms_bash_gvm_loaded "$@" || status=$?
    _ms_bash_gvm_sync_goroot
    return "$status"
}

_ms_bash_gvm_auto() {
    local dir=$PWD line version=''
    while [[ ! -f $dir/go.mod ]]; do
        [[ $dir != / ]] || return 0
        dir=${dir%/*}
        [[ -n $dir ]] || dir=/
    done
    while IFS= read -r line || [[ -n $line ]]; do
        if [[ $line =~ ^go[[:blank:]]+([0-9]+\.[0-9]+(\.[0-9]+)?)([[:blank:]]|$) ]]; then
            version=go${BASH_REMATCH[1]}
            break
        fi
    done < "$dir/go.mod"
    if [[ -n $version && $version != "${gvm_go_name-}" && -x $GVM_ROOT/gos/$version/bin/go ]]; then
        gvm use "$version" >/dev/null 2>&1
    fi
}

_ms_bash_set_env GVM_ROOT "${GVM_ROOT:-$HOME/.gvm}"
_ms_bash_gvm_sync_goroot
if ! declare -F gvm >/dev/null; then
    if [[ ${GOROOT-} == "$GVM_ROOT"/gos/* &&
          ( ${gvm_go_name-} != "${GOROOT##*/}" || -z ${GOPATH-} ) ]]; then
        _ms_bash_set_env gvm_go_name "${GOROOT##*/}"
        _ms_bash_set_env gvm_pkgset_name global
        _ms_bash_set_env GOPATH "$GVM_ROOT/pkgsets/${GOROOT##*/}/global"
        _ms_bash_set_env GVM_OVERLAY_PREFIX "$GOPATH/overlay"
    fi
    function gvm { _ms_bash_gvm_run "$@"; }
fi
_ms_bash_register_chpwd _ms_bash_gvm_auto
