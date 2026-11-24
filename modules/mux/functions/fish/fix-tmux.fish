# fix-tmux: re-import the tmux client environment (for example a fresh SSH_AUTH_SOCK after
# re-attaching). The output of tmux show-environment is read as data: NAME=value sets and
# exports the variable, -NAME erases it. Nothing is evaluated.
function fix-tmux --description 'Re-import the tmux environment into this shell'
    if test -z "$TMUX"
        echo "Not in tmux"
        return 0
    end
    tmux show-environment | while read -l line
        if string match -q -r '^-[A-Za-z_][A-Za-z0-9_]*$' -- "$line"
            set -l name (string sub -s 2 -- "$line")
            contains -- "$name" PWD SHLVL _ TMUX; and continue
            set -e -g "$name"
        else if set -l parts (string match -r '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$' -- "$line")
            set -l name "$parts[2]"
            contains -- "$name" PWD SHLVL _; and continue
            if string match -q -r 'PATH$' -- "$name"
                # fish keeps path variables as lists.
                set -gx "$name" (string split : -- "$parts[3]")
            else
                set -gx "$name" "$parts[3]"
            end
        end
    end
    return 0
end
