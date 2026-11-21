# -*- mode: shell-script; sh-shell: zsh -*-
#
# Run one phase's module files. Sourced at top level by zshenv.zsh and zshrc.zsh
# (never from a function: a bare `typeset` in a module would turn function-local)
# with _ms_phase (env|init) and _ms_plan set. A broken module must not take the
# shell down:
#  - the file is sourced inside an `always` block, so recoverable errors (aborted
#    expansions, syntax errors) only skip the rest of that file;
#  - non-interactive shells exit on a fatal expansion such as ${x:?}, which no
#    block can catch, so _ms_module_guard first proves the file survives in a
#    subshell (cached by file stat) and a failing file is skipped;
#  - agent and batch shells silence the module's own stderr; interactive shells
#    show it. MARKSHARC_VERBOSE reports every skip.
for _ms_cur in "${_ms_plan[@]}"; do
    [[ -r ${_ms_mod_dir[$_ms_cur]}/$_ms_phase.zsh ]] || continue
    if [[ $_ms_phase == env ]] && ! _ms_module_requires_command "$_ms_cur"; then continue; fi
    _ms_module_begin "$_ms_phase" "$_ms_cur" || continue
    _ms_file=${_ms_mod_dir[$_ms_cur]}/$_ms_phase.zsh
    if [[ $MARKSHARC_SESSION != interactive ]] && ! _ms_module_guard "$_ms_phase" "$_ms_cur" "$_ms_file"; then
        _ms_trace "module $_ms_cur: $_ms_phase.zsh skipped (failed validation)"
        continue
    fi
    _ms_rc=0
    if [[ $MARKSHARC_SESSION == interactive ]] || (( _ms_verbose )); then
        { source "$_ms_file"; _ms_rc=$? } always { TRY_BLOCK_ERROR=0 }
    else
        { source "$_ms_file" 2>/dev/null; _ms_rc=$? } always { TRY_BLOCK_ERROR=0 }
    fi
    (( _ms_rc == 0 )) || _ms_trace "module $_ms_cur: $_ms_phase.zsh returned $_ms_rc"
    _ms_module_end "$_ms_phase" "$_ms_cur"
done
unset _ms_cur _ms_file _ms_rc
