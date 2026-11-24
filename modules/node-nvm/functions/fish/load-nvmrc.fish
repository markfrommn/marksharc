# load-nvmrc: select the node version for the nearest .nvmrc, or the default one after
# leaving an .nvmrc tree. nvm's state stays in bash: bash nvm in $NVM_DIR (the store the
# env phase reads) names the selected bin directory and only that path crosses into fish
# as data, with no bash startup file and no generated shell code evaluated by fish.
#
# With no .nvmrc and no earlier switch in this shell nothing happens and nothing is
# spawned. The bash result is remembered per target (.nvmrc path and contents), so a
# directory change inside the same tree spawns nothing while PATH still has that node.
function load-nvmrc --description 'Select node from the nearest .nvmrc'
    set -l nvm_dir "$HOME/.nvm"
    set -q NVM_DIR[1]; and test -n "$NVM_DIR"; and set nvm_dir "$NVM_DIR"

    set -l rc ''
    set -l dir "$PWD"
    while true
        if test -f "$dir/.nvmrc"
            set rc "$dir/.nvmrc"
            break
        end
        set -l parent (path dirname -- "$dir")
        test "$parent" = "$dir"; and break
        set dir "$parent"
    end

    # No .nvmrc and no earlier switch: node is still the env phase's choice.
    if test -z "$rc"; and not set -q _ms_nvm_switched
        return 0
    end
    test -s "$nvm_dir/nvm.sh"; or return 0

    set -l target default
    set -l key default
    if test -n "$rc"
        set -l content (string collect <"$rc")
        set target nvmrc
        set key "nvmrc:$rc:$content"
    end

    # The first nvm-managed node directory on PATH, or empty.
    set -l pattern '^'(string escape --style=regex -- "$nvm_dir")'/versions/(node|io\.js)/[^/]+/bin$'
    set -l first ''
    for entry in $PATH
        if string match -qr -- $pattern "$entry"
            set first "$entry"
            break
        end
    end
    if set -q _ms_nvm_key; and test "$_ms_nvm_key" = "$key"; and test "$_ms_nvm_bin" = "$first"
        return 0
    end

    set -lx NVM_DIR "$nvm_dir"
    set -l selected (command env -u BASH_ENV bash --noprofile --norc -c '
        source "$NVM_DIR/nvm.sh" --no-use >&2 || exit
        if [ "$1" = nvmrc ]; then
            nvm use --silent >&2 || nvm install >&2 || exit
        else
            nvm use --silent default >&2 || exit
        fi
        printf "%s\n" "${NVM_BIN:-system}"
    ' load-nvmrc "$target")
    or return $status
    test (count $selected) -eq 1; or return 1
    set selected $selected[1]
    if test "$selected" != system; and not test -d "$selected"
        return 1
    end

    # Replace the earlier nvm node entries in place (the first one's position), so the
    # tier order the env phase built is kept; with none there, the node goes in front.
    set -l fresh
    test "$selected" != system; and set fresh "$selected"
    set -l new
    set -l placed 0
    for entry in $PATH
        if string match -qr -- $pattern "$entry"
            if test $placed -eq 0
                set new $new $fresh
                set placed 1
            end
            continue
        end
        set -a new "$entry"
    end
    test $placed -eq 1; or set new $fresh $new
    set -gx PATH $new
    if test "$selected" = system
        set -e -g NVM_BIN
        set -e -g NVM_INC
        set -g _ms_nvm_bin ''
    else
        set -gx NVM_BIN "$selected"
        set -gx NVM_INC (path dirname -- "$selected")/include/node
        set -g _ms_nvm_bin "$selected"
    end
    set -g _ms_nvm_switched 1
    set -g _ms_nvm_key "$key"
    return 0
end
