# _ms_fish_gvm_first ROOT: print the gvm Go name of the first go on PATH; nothing when that
# go is not a gvm Go or there is none.
function _ms_fish_gvm_first
    set -l root $argv[1]
    for dir in $PATH
        if test -x "$dir/go"; and not test -d "$dir/go"
            set -l gos (path dirname -- (path dirname -- "$dir"))
            test "$gos" = "$root/gos"; and path basename -- (path dirname -- "$dir")
            return 0
        end
    end
    return 0
end
