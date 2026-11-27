# completion-carapace module, init phase (spec 6.9): opt-in Carapace completion
# for interactive zsh shells. Mutually exclusive with completion-fzf-tab unless
# completion-carapace.allow_fzf_tab is on or MARKSHARC_COMPLETION_UI=both.
# Switching completion UIs takes effect in a fresh shell (exec zsh -l).

_ms_carapace_join_list() {
    emulate -L zsh
    local raw=${1-} norm
    local -a parts=()
    norm=${raw//,/ }
    parts=( ${=norm} )
    if (( $#parts == 0 )) || [[ ${(L)parts[1]} == (off|none) && $#parts == 1 ]]; then
        REPLY=
        return 0
    fi
    REPLY=${(j:,:)parts}
}

_ms_carapace_cleanup() {
    local v
    for v in "${_ms_carapace_vars[@]}"; do
        unset "$v"
    done
    typeset -ga _ms_carapace_vars=()
    if [[ -n ${MARKSHARC_CARAPACE_ACTIVE-} ]]; then
        unset CARAPACE_BRIDGES CARAPACE_EXCLUDES MARKSHARC_CARAPACE_ACTIVE
    fi
}

_ms_carapace_manifest_fingerprint() {
    emulate -L zsh
    local cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}
    local manifest=$cache/carapace-specs-manifest
    local render_id= cmd link target
    local -a cmds=()
    if [[ -r $cache/render-id ]]; then
        IFS= read -r render_id < "$cache/render-id" || render_id=
    fi
    if [[ -r $manifest ]]; then
        while IFS=$'\t' read -r cmd link target || [[ -n $cmd ]]; do
            [[ -n $cmd ]] && cmds+=( "$cmd" )
        done < "$manifest"
    fi
    (( $#cmds )) && cmds=( ${(ou)cmds} )
    REPLY="${(j:,:)cmds}@${render_id}"
}

typeset -ga _ms_carapace_vars
typeset -gaU _ms_init_cleanups
_ms_carapace_cleanup
_ms_init_cleanups+=( _ms_carapace_cleanup )

if (( $+functions[_ms_completion_carapace_active] )) && _ms_completion_carapace_active; then
    typeset -g _ms_carapace_bridges= _ms_carapace_excludes= _ms_carapace_specs_fp=
    _ms_carapace_join_list "${_ms_opt_completion_carapace_bridges-zsh,fish,bash}"
    _ms_carapace_bridges=$REPLY
    _ms_carapace_join_list "${_ms_opt_completion_carapace_excludes-}"
    _ms_carapace_excludes=$REPLY
    _ms_carapace_manifest_fingerprint
    _ms_carapace_specs_fp=$REPLY

    if [[ -n $_ms_carapace_bridges ]]; then
        export CARAPACE_BRIDGES="$_ms_carapace_bridges"
        _ms_carapace_vars+=( CARAPACE_BRIDGES )
    else
        unset CARAPACE_BRIDGES
    fi
    if [[ -n $_ms_carapace_excludes ]]; then
        export CARAPACE_EXCLUDES="$_ms_carapace_excludes"
        _ms_carapace_vars+=( CARAPACE_EXCLUDES )
    else
        unset CARAPACE_EXCLUDES
    fi
    export MARKSHARC_CARAPACE_ACTIVE=1
    _ms_carapace_vars+=( MARKSHARC_CARAPACE_ACTIVE )

    if (( ! ${_ms_reloading:-0} )); then
        if _ms_init_cached -k "${CARAPACE_BRIDGES-}|${CARAPACE_EXCLUDES-}|${_ms_carapace_specs_fp-}" carapace carapace _carapace zsh; then
            typeset -gi _ms_completion_ui_carapace=1
        fi
    fi
    unset _ms_carapace_bridges _ms_carapace_excludes _ms_carapace_specs_fp
else
    _ms_trace "module completion-carapace: inactive (opt-in off or overridden by MARKSHARC_COMPLETION_UI)"
fi
unfunction _ms_carapace_join_list _ms_carapace_manifest_fingerprint 2>/dev/null
true
