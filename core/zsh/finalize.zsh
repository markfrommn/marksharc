# -*- mode: shell-script; sh-shell: zsh -*-
#
# Run the env-phase finalizers (spec 6.7: the path module builds PATH here, after every
# module has contributed its tiers). Sourced at top level by zshenv.zsh. A failing
# finalizer must not take the shell down: it runs inside an always block, and
# non-interactive shells discard its stderr unless the trace is on.
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
