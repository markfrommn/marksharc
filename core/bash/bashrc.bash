# Both installed stubs use this entry point. BASH_ENV sources env.bash directly.
[[ -r $MARKSHARC_HOME/core/bash/env.bash ]] || return 0
if [[ $- == *i* && -t 0 && -t 1 ]] &&
   (( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) )); then
    [[ ${_ms_bash_interactive_pid-} != "$BASHPID" ]] || return 0
    _ms_bash_rc_loading=1
    _ms_bash_env_ready=
fi
# shellcheck source=core/bash/env.bash
source "$MARKSHARC_HOME/core/bash/env.bash"
if [[ ${_ms_bash_rc_loading-} == 1 && -n ${_ms_bash_env_ready-} && ${MARKSHARC_SESSION-} == interactive ]]; then
    # shellcheck source=core/bash/interactive.bash
    source "$MARKSHARC_HOME/core/bash/interactive.bash"
    _ms_bash_interactive_start "$_ms_bash_env_ready"
fi
unset _ms_bash_rc_loading _ms_bash_env_ready
true
