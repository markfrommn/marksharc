# Native pieces that cannot yet be expressed by module directives.
function _ms_fish_module_env
    switch $argv[1]
        case go-gvm
            set -l root "$HOME/.gvm"
            set -q GVM_ROOT; and test -n "$GVM_ROOT"; and set root "$GVM_ROOT"
            set -l chosen
            if test -r "$root/environments/default"
                while read -l line
                    if string match -q '*gvm_go_name=*' -- "$line"
                        set chosen (string replace -r '^.*gvm_go_name=' '' -- "$line" | string replace -a -r '[\x27" ]' '')
                        break
                    end
                end <"$root/environments/default"
            end
            if test -z "$chosen"; or not test -x "$root/gos/$chosen/bin/go"
                set chosen ''
                for dir in "$root"/gos/go*
                    test -x "$dir/bin/go"; or continue
                    set -l candidate (path basename "$dir")
                    if test -z "$chosen"; or _ms_fish_version_newer (string replace -r '^go' '' -- "$candidate") (string replace -r '^go' '' -- "$chosen")
                        set chosen "$candidate"
                    end
                end
            end
            if test -n "$chosen"
                if test "$MARKSHARC_SESSION" = interactive
                    _ms_fish_path_add_force manager "$root/pkgsets/$chosen/global/bin"
                    _ms_fish_path_add manager "$root/gos/$chosen/bin"
                    _ms_fish_path_add_force manager "$root/pkgsets/$chosen/global/overlay/bin"
                    _ms_fish_path_add manager "$root/bin"
                else
                    _ms_fish_path_add manager "$root/pkgsets/$chosen/global/bin" "$root/gos/$chosen/bin"
                end
            end
            set -g _ms_fish_gvm_root "$root"
        case go
            set -l root "$HOME/go"
            set -q GOPATH; and test -n "$GOPATH"; and set root $GOPATH
            for dir in (string split : -- "$root")
                _ms_fish_path_add_bindirs user "$dir"
            end
        case rust
            set -l root "$HOME/.cargo"
            set -q CARGO_HOME; and test -n "$CARGO_HOME"; and set root "$CARGO_HOME"
            _ms_fish_path_add_bindirs user "$root"
        case pnpm
            for dir in "$HOME/.local/share/pnpm" "$HOME/Library/pnpm"
                test -d "$dir"; and set -gx PNPM_HOME "$dir"
            end
            if set -q PNPM_HOME; and contains -- "$_ms_opt_pnpm_path" on 1 yes true
                _ms_fish_path_add user "$PNPM_HOME"
            end
        case python
            if test -f "$HOME/.pyenv/bin/pyenv"; and not _ms_fish_command_available uv
                set -gx PYENV_ROOT "$HOME/.pyenv"
                _ms_fish_path_add manager "$PYENV_ROOT/shims" "$PYENV_ROOT/bin"
            end
        case node-nvm
            if not set -q NVM_DIR; or test -z "$NVM_DIR"
                set -gx NVM_DIR "$HOME/.nvm"
            end
            set -l alias_file "$NVM_DIR/alias/default"
            test -r "$alias_file"; or return 0
            read -l nvm_version <"$alias_file"
            for hop in 1 2 3 4 5 6
                set nvm_version (string trim -- "$nvm_version")
                test -n "$nvm_version"; or return 0
                if string match -qr '^(v?[0-9]|node$|stable$|system$)' -- "$nvm_version"
                    break
                end
                test -r "$NVM_DIR/alias/$nvm_version"; or return 0
                read nvm_version <"$NVM_DIR/alias/$nvm_version"
            end
            if contains -- "$nvm_version" node stable
                set nvm_version ''
            else
                set nvm_version (string replace -r '^v' '' -- "$nvm_version")
                string match -qr '^[0-9]+(\\.[0-9]+)*$' -- "$nvm_version"; or return 0
            end
            set -l best
            for dir in "$NVM_DIR"/versions/node/v*/bin
                test -d "$dir"; or continue
                set -l candidate (string replace -r '^v' '' -- (path basename (path dirname "$dir")))
                if test -n "$nvm_version"; and not string match -qr "^$nvm_version(\\.|\$)" -- "$candidate"
                    continue
                end
                if test -z "$best"; or _ms_fish_version_newer "$candidate" "$best"
                    set best "$candidate"
                end
            end
            test -n "$best"; and _ms_fish_path_add manager "$NVM_DIR/versions/node/v$best/bin"
    end
    return 0
end

function _ms_fish_gvm_finalize
    set -q _ms_fish_gvm_root; or return
    for dir in $PATH
        test -x "$dir/go"; and not test -d "$dir/go"; or continue
        if string match -q -- "$_ms_fish_gvm_root/gos/*/bin" "$dir"
            set -gx GOROOT (path dirname "$dir")
        else if set -q GOROOT; and test -n "$GOROOT"
            if test (path resolve "$dir/go") != (path resolve "$GOROOT/bin/go")
                set -e -g GOROOT
            end
        end
        break
    end
end

function _ms_fish_version_newer
    set -l left (string split . -- "$argv[1]")
    set -l right (string split . -- "$argv[2]")
    for i in 1 2 3
        set -l a 0
        set -l b 0
        set -q left[$i]; and set a $left[$i]
        set -q right[$i]; and set b $right[$i]
        test "$a" -gt "$b"; and return 0
        test "$a" -lt "$b"; and return 1
    end
    return 1
end

function _ms_fish_init_module
    set -l dir $argv[1]
    switch (path basename "$dir")
        case cwf
            functions -e cwf-new
            functions -c _ms_fish_caller_state_command cwf-new
            set -ga _ms_fish_wrappers cwf-new
        case git-worktree
            functions -e gwt-clean
            functions -c _ms_fish_caller_state_command gwt-clean
            set -ga _ms_fish_wrappers gwt-clean
        case ssh-agent
            functions -e setup-ssh-agent
            functions -c _ms_fish_caller_state_command setup-ssh-agent
            set -ga _ms_fish_wrappers setup-ssh-agent
    end
    if test -d "$dir/functions/fish"; and not contains -- "$dir/functions/fish" $fish_function_path
        set -gp fish_function_path "$dir/functions/fish"
        set -ga _ms_fish_function_paths "$dir/functions/fish"
    end
    if test -d "$dir/completions/fish"; and not contains -- "$dir/completions/fish" $fish_complete_path
        set -gp fish_complete_path "$dir/completions/fish"
        set -ga _ms_fish_completion_paths "$dir/completions/fish"
    end
    if test -r "$dir/init.fish"
        source "$dir/init.fish"
    end
    return 0
end
