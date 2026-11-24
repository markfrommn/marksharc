# cwf-new takes one argument: the branch for the new session. Offer the local branches.
complete -c cwf-new -f
complete -c cwf-new -n 'test (count (commandline -xpc)) -eq 1' -a '(command git for-each-ref --format="%(refname:short)" refs/heads 2>/dev/null)' -d 'Local branch'
