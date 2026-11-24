# setup-ssh-agent: the write-once command; its setenv and unsetenv directives reach this shell.
function setup-ssh-agent --description 'Find or start an ssh-agent and use it in this shell'
    set -lx MARKSHARC_SESSION "$MARKSHARC_SESSION"
    _ms_fish_run_with_directives setup-ssh-agent $argv
end
