_ms_bash_zoxide_add() {
    [[ -o history && ${_ms_bash_zoxide_last-} != "$PWD" ]] || return 0
    _ms_bash_zoxide_last=$PWD
    command zoxide add -- "$(__zoxide_pwd)" 2>/dev/null
}

_ms_bash_zoxide_init() {
    local name dir=${_ZO_DATA_DIR-} context before
    local -A completions=()
    printf -v context '%q ' "$dir" "${_ZO_ECHO-}" "${_ZO_RESOLVE_SYMLINKS-}" "${_ZO_FZF_OPTS-}"
    for name in z zi; do completions[$name]=$(_ms_bash_effect complete "$name"); done
    _ms_bash_init_cached -k "$context" zoxide zoxide init bash --hook none >/dev/null 2>&1 || return
    for name in z zi; do
        before=${completions[$name]}
        _ms_bash_record_effect complete "$name" "$before" "$(_ms_bash_effect complete "$name")"
    done
    if declare -F __zoxide_pwd >/dev/null; then
        _ms_bash_register_chpwd _ms_bash_zoxide_add
    elif declare -F z >/dev/null; then
        # Providers without a PWD helper use Bash's logical PWD.
        __zoxide_pwd() { printf '%s\n' "$PWD"; }
        _ms_bash_register_chpwd _ms_bash_zoxide_add
    fi
}
_ms_bash_zoxide_init
