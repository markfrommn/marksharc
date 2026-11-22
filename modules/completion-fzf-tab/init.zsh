# completion-fzf-tab module, init phase (spec 6.8): load the pinned plugins named by this
# module's zsh.plugins registry from the XDG cache. Startup never touches the network;
# zsh-plugin-update clones. Loads once per shell, after native completion exists.
if have_command ag; then
    export FZF_DEFAULT_COMMAND='ag --hidden -g ""'
fi

typeset -g _ms_registry=${_ms_mod_dir[completion-fzf-tab]:-$MARKSHARC_HOME/modules/completion-fzf-tab}/zsh.plugins
if (( ! ${_ms_reloading:-0} )) && [[ -r $_ms_registry ]]; then
    typeset -g _ms_pline _ms_pkind
    typeset -ga _ms_pwords
    integer -g _ms_pi
    while IFS= read -r _ms_pline || [[ -n $_ms_pline ]]; do
        _ms_pline=${_ms_pline#"${_ms_pline%%[![:space:]]*}"}
        [[ -z ${_ms_pline//[[:space:]]/} || ${_ms_pline[1]} == \# ]] && continue
        _ms_pwords=( "${(Z:C:)_ms_pline}" ) 2>/dev/null || continue
        _zsh-plugin-valid-quoting "${(j: :)_ms_pwords}" || continue
        _ms_pwords=( "${(Q)_ms_pwords[@]}" )
        [[ ${_ms_pwords[1]:-} == plugin && -n ${_ms_pwords[2]:-} && -n ${_ms_pwords[4]:-} ]] || continue
        _ms_pkind=source
        for (( _ms_pi=5; _ms_pi < $#_ms_pwords; _ms_pi++ )); do
            if [[ ${_ms_pwords[_ms_pi]} == kind ]]; then
                _ms_pkind=${_ms_pwords[_ms_pi+1]}
                break
            fi
        done
        zsh-plugin-load "${_ms_pwords[2]}" "${_ms_pwords[4]}" "$_ms_pkind"
    done < "$_ms_registry"
    unset _ms_pline _ms_pkind _ms_pwords _ms_pi
fi
unset _ms_registry
true
