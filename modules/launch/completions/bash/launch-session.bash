if ! declare -F _ms_workflow_complete >/dev/null; then
    # shellcheck source=modules/launch/completions/bash/lib/workflow.bash
    source "$MARKSHARC_HOME/modules/launch/completions/bash/lib/workflow.bash"
fi
complete -o filenames -F _ms_workflow_complete launch-session
