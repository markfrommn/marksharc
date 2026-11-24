# gvm: the Go version manager, without sourcing it into fish.
#
#   gvm use <go> [--default]   switches natively: PATH, GOROOT, GOPATH and the gvm_*
#                              variables from the known gvm layout; --default also asks
#                              gvm under bash to record the default environment
#   anything else              runs under bash (bash --noprofile --norc, gvm sourced)
#
# Subcommands that change the environment other than use (such as pkgset use) change
# only the bash child, never this shell.
function gvm --description 'Go version manager (use switches natively)'
    set -l root "$HOME/.gvm"
    set -q GVM_ROOT[1]; and test -n "$GVM_ROOT"; and set root "$GVM_ROOT"
    if not test -f "$root/scripts/gvm"
        printf 'gvm: %s/scripts/gvm not found\n' "$root" >&2
        return 1
    end

    set -l name ''
    set -l make_default 0
    set -l native 0
    if test "$argv[1]" = use
        set native 1
        for arg in $argv[2..]
            if test "$arg" = --default
                set make_default 1
            else if test -z "$name"; and string match -qr -- '^go[0-9][A-Za-z0-9._-]*$' "$arg"
                set name "$arg"
            else
                set native 0
            end
        end
        test -n "$name"; or set native 0
    end

    if test $native -eq 1
        if not test -x "$root/gos/$name/bin/go"
            printf 'gvm: %s is not installed\n' "$name" >&2
            return 1
        end
        set -l rx (string escape --style=regex -- "$root")
        set -l pattern "^$rx/(gos/[^/]+|pkgsets/[^/]+/global|pkgsets/[^/]+/global/overlay)/bin\$"
        set -l fresh "$root/pkgsets/$name/global/bin" "$root/gos/$name/bin" "$root/pkgsets/$name/global/overlay/bin"
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
        set -gx GVM_ROOT "$root"
        set -gx gvm_go_name "$name"
        set -gx gvm_pkgset_name global
        set -gx GOROOT "$root/gos/$name"
        set -gx GOPATH "$root/pkgsets/$name/global"
        set -gx GVM_OVERLAY_PREFIX "$GOPATH/overlay"
        test $make_default -eq 1; or printf 'Now using version %s\n' "$name"
        test $make_default -eq 1; or return 0
    end

    set -lx GVM_ROOT "$root"
    command env -u BASH_ENV bash --noprofile --norc -c 'source "$GVM_ROOT/scripts/gvm" >/dev/null 2>&1; gvm "$@"' gvm $argv
end
