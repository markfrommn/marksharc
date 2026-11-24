# Print the first child directory of $PWD, dotted directories included, in byte order
# (the zsh _dirhistory_first_child rule). Symlinks to directories count. Returns 1 when
# there is none. The name is printed without a trailing newline.
function _ms_nav_first_child
    set -l children
    for entry in .* *
        test -d "$entry"; or continue
        set -a children "$entry"
    end
    set -q children[1]; or return 1
    printf '%s\0' $children | LC_ALL=C command sort -z | read -z first
    printf '%s' "$first"
end
