# _ms_fish_gvm_select ROOT: print the gvm Go name to use (the one gvm's default environment
# names, else the numerically newest installed Go); returns 1 with no output when none.
function _ms_fish_gvm_select
    set -l root $argv[1]
    test -d "$root/gos"; or return 1
    set -l name ''
    if test -r "$root/environments/default"
        while read -l line
            if string match -q '*gvm_go_name=*' -- "$line"
                set name (string replace -r '^.*gvm_go_name=' '' -- "$line" | string replace -a -r '[\x27" ]' '')
                break
            end
        end <"$root/environments/default"
    end
    if test -z "$name"; or not test -x "$root/gos/$name/bin/go"
        set name ''
        for dir in "$root"/gos/go*
            test -x "$dir/bin/go"; or continue
            set -l candidate (path basename -- "$dir")
            if test -z "$name"; or _ms_fish_version_newer (string replace -r '^go' '' -- "$candidate") (string replace -r '^go' '' -- "$name")
                set name "$candidate"
            end
        end
    end
    test -n "$name"; and test -x "$root/gos/$name/bin/go"; or return 1
    printf '%s\n' "$name"
end
