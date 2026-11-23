# -*- mode: shell-script; sh-shell: zsh -*-
#
# Run the env-phase finalizers (spec 6.7: the path module builds PATH here, after every
# module has contributed its tiers). Sourced at top level by zshenv.zsh. A failing
# finalizer must not take the shell down: it runs inside an always block, and
# non-interactive shells discard its stderr unless the trace is on.
if (( ${_ms_env_rebuild:-1} && $+functions[_ms_path_add] )); then
    _ms_path_add user "${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST}/bin"
    for _ms_bin_module in "${_ms_plan[@]}"; do
        _ms_module_requires_command "$_ms_bin_module" || continue
        _ms_path_add user "${_ms_mod_dir[$_ms_bin_module]}/bin"
    done
    unset _ms_bin_module
fi
for _ms_fin in "${_ms_env_finalizers[@]}"; do
    (( $+functions[$_ms_fin] )) || continue
    _ms_trace "finalizer: $_ms_fin"
    if [[ $MARKSHARC_SESSION == interactive ]] || (( _ms_verbose )); then
        { "$_ms_fin" } always { TRY_BLOCK_ERROR=0 }
    else
        { "$_ms_fin" 2>/dev/null } always { TRY_BLOCK_ERROR=0 }
    fi
done
unset _ms_fin
