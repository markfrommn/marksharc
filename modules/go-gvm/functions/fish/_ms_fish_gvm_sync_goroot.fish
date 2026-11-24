# _ms_fish_gvm_sync_goroot ROOT: GOROOT names the Go that is first on PATH. A gvm Go sets it
# to its own directory; for any other Go an inherited GOROOT that points elsewhere is
# removed so the go binary finds its own root. With no go on PATH nothing changes.
function _ms_fish_gvm_sync_goroot
    set -l root $argv[1]
    set -l first ''
    for dir in $PATH
        if test -x "$dir/go"; and not test -d "$dir/go"
            set first "$dir/go"
            break
        end
    end
    test -n "$first"; or return 0
    set -l godir (path dirname -- (path dirname -- "$first"))
    if test (path dirname -- "$godir") = "$root/gos"
        set -gx GOROOT "$godir"
    else if set -q GOROOT[1]; and test -n "$GOROOT"
        if test (path resolve -- "$first") != (path resolve -- "$GOROOT/bin/go")
            set -e -g GOROOT
        end
    end
    return 0
end
