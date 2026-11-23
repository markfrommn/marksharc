# Bash interactive and login stubs load the same quiet environment.
if [[ -r $MARKSHARC_HOME/core/bash/env.bash ]]; then
    source "$MARKSHARC_HOME/core/bash/env.bash"
fi
