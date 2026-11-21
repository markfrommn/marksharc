# -*- mode: shell-script; sh-shell: zsh -*-
#
# MarkSharc env phase (spec 6.6): every shell, every mode. Host facts, exports,
# PATH, umask. No output, no forks beyond cached files.
#
# Sourced at top level by the stub, the generated ZDOTDIR .zshenv and reload.zsh,
# never from inside a function: module env.zsh files may use bare `typeset`,
# which would otherwise turn function-local.

if [[ -z ${MARKSHARC_HOME-} ]]; then
    MARKSHARC_HOME=${${(%):-%N}:A:h:h:h}
    export MARKSHARC_HOME
fi
typeset -g _ms_starting=1 _ms_verbose=0
typeset -gi _ms_reloading=${_ms_reloading:-0}
[[ -n ${MARKSHARC_VERBOSE-} && $MARKSHARC_VERBOSE != 0 ]] && _ms_verbose=1

for _ms_lib in util session facts zdot envid modules cache; do
    [[ -r $MARKSHARC_HOME/core/zsh/lib/$_ms_lib.zsh ]] && source "$MARKSHARC_HOME/core/zsh/lib/$_ms_lib.zsh"
done
unset _ms_lib

_ms_trace "env phase: start"
_ms_facts
_ms_session_classify
zdir=$MARKSHARC_HOME
_ms_trace "session=$MARKSHARC_SESSION os=$MARKSHARC_OS arch=$MARKSHARC_ARCH host=$MARKSHARC_HOST distro=$MARKSHARC_DISTRO"
_ms_umask
if [[ -o login || -o interactive ]]; then _ms_zdot_ensure; fi

# Inherit-skip: a child shell whose MARKSHARC_ENV matches the current inputs only
# recomputes shell-local facts. Login shells and reloads always rebuild.
_ms_env_id
_ms_env_rebuild=1
if [[ -z ${_ms_force_rebuild-} && ! -o login && -n $_ms_env_id_value && ${MARKSHARC_ENV-} == $_ms_env_id_value ]]; then
    _ms_env_rebuild=0
fi
_ms_trace "env id=${_ms_env_id_value:-none} rebuild=$_ms_env_rebuild"

# Modules that must see every other module's contribution (the path builder) register
# a function here during the env phase; the finalizers run once, after the last module.
typeset -ga _ms_env_finalizers=()
if (( $+functions[_ms_modules_plan] )); then
    _ms_modules_plan env
    _ms_phase=env
    source "$MARKSHARC_HOME/core/zsh/phase.zsh"
    source "$MARKSHARC_HOME/core/zsh/finalize.zsh"
fi

typeset -gU path
typeset -ga _ms_path_asserted=( "${path[@]}" )
if (( _ms_env_rebuild )) && [[ -n $_ms_env_id_value ]]; then export MARKSHARC_ENV=$_ms_env_id_value; fi
_ms_trace "env phase: done"
unset _ms_starting
