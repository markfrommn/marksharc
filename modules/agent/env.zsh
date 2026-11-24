# Opt in to Bash's noninteractive startup hook for agent child shells.
case ${_ms_opt_agent_bash_env-off} in
    on|1|yes|true) export BASH_ENV=$MARKSHARC_HOME/core/bash/env.bash ;;
    *) [[ ${BASH_ENV-} != "$MARKSHARC_HOME/core/bash/env.bash" ]] || unset BASH_ENV ;;
esac
true
