function __ms_cwf_new_repos
    set -l host local
    set -l tokens (commandline -opc)
    set -l index (contains -i -- --host $tokens)
    if test -n "$index"; and set -q tokens[(math $index + 1)]
        set host $tokens[(math $index + 1)]
    end
    contains -- $host '' local localhost $MARKSHARC_HOST; and set host local
    string match -qr '^[A-Za-z0-9._@:-]+$' -- $host; or return
    set -l cache "$XDG_CACHE_HOME"
    test -n "$cache"; or set cache "$HOME/.cache"
    set -l machine "$MARKSHARC_HOST"
    test -n "$machine"; or set machine (hostname -s)
    set -l file "$cache/marksharc/$machine/repos/$host.tsv"
    test -r "$file"; or return
    while read -l row
        set -l fields (string split \t -- $row)
        test (count $fields) -ge 3; and test "$fields[3]" = base; and echo $fields[1]
    end <$file
end

function __ms_cwf_new_needs_branch
    set -l tokens (commandline -opc)
    set -l skip 0
    for token in $tokens[2..-1]
        if test $skip -eq 1
            set skip 0
        else if contains -- $token --repo --host --mux --mux-id --place
            set skip 1
        else if not string match -q -- '-*' "$token"
            return 1
        end
    end
    test $skip -eq 0
end

complete -c cwf-new -f
complete -c cwf-new -n __ms_cwf_new_needs_branch -a '(command git for-each-ref --format="%(refname:short)" refs/heads 2>/dev/null)' -d 'Local branch'
complete -c cwf-new -l repo -x -a '(__ms_cwf_new_repos)' -d 'Select base repository'
complete -c cwf-new -l host -x -d 'Select host'
complete -c cwf-new -l mux -x -a 'hc herdr tmux herdr-core' -d 'Select multiplexer'
complete -c cwf-new -l mux-id -x -d 'Select instance'
complete -c cwf-new -l place -x -a 'workspace tab hidden' -d 'Set placement'
complete -c cwf-new -l launch -d 'Launch in a new terminal'
complete -c cwf-new -l pick -d 'Choose a repository'
