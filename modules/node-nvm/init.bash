_ms_mise_owns node && return 0
[[ -s ${NVM_DIR:-$HOME/.nvm}/nvm.sh ]] || return 0

_ms_bash_nvm_load() {
    local definition rc=0
    declare -F _ms_bash_nvm_loaded >/dev/null && return 0
    # shellcheck disable=SC2034 # Names passed to the ownership helpers.
    local -A before=() after=()
    _ms_bash_snapshot_definitions before
    unset -f nvm
    # shellcheck disable=SC1091
    source "${NVM_DIR:-$HOME/.nvm}/nvm.sh" --no-use || rc=$?
    definition=$(builtin declare -f nvm) || rc=1
    if (( rc == 0 )); then builtin eval "_ms_bash_nvm_loaded${definition#nvm}"; fi
    _ms_bash_restore_effect function nvm "${before[function:nvm]}"
    _ms_bash_snapshot_definitions after
    _ms_bash_record_definitions before after
    return "$rc"
}

_ms_bash_nvm_run() {
    _ms_bash_nvm_load || return
    _ms_bash_nvm_loaded "$@"
}

_ms_bash_nvm_auto() {
    local dir=$PWD desired active previous=$PATH
    while [[ ! -f $dir/.nvmrc ]]; do
        [[ $dir != / ]] || break
        dir=${dir%/*}
        [[ -n $dir ]] || dir=/
    done
    if [[ -f $dir/.nvmrc ]]; then
        if [[ $(builtin declare -f nvm) == *'_ms_bash_nvm_run "$@"'* ]]; then _ms_bash_nvm_load || return; fi
        desired=$(nvm version "$(<"$dir/.nvmrc")") || return
        # Startup is offline. A requested version must already be installed.
        [[ -n $desired && $desired != N/A ]] || return 0
    elif declare -F _ms_bash_nvm_loaded >/dev/null; then
        desired=$(nvm version default) || return
        [[ -n $desired && $desired != N/A ]] || return 0
    else
        return 0
    fi
    active=$(nvm version) || return
    [[ $active == "$desired" ]] || nvm use --silent "$desired" || { export PATH=$previous; return 1; }
}

if ! declare -F nvm >/dev/null; then function nvm { _ms_bash_nvm_run "$@"; }; fi
_ms_bash_nvm_prompt() { _ms_bash_nvm_auto >/dev/null 2>&1; }
_ms_bash_register_chpwd _ms_bash_nvm_prompt
