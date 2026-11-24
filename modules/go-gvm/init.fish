# go-gvm module, init phase (interactive only). Startup only names the Go that is first on
# PATH (the env phase's selection, or a parent shell's explicit gvm use) in the variables
# gvm use would set, and syncs GOROOT to it. Nothing is sourced: the gvm function
# (functions/fish/gvm.fish) switches Go natively and runs every other subcommand under
# bash. The default environment is never rewritten (no --default), and startup prints
# nothing. The go.mod hook switches versions.
if functions -q _ms_fish_mise_owns; and _ms_fish_mise_owns go
    functions -e _ms_fish_gvm_hook
    return 0
end
if functions -q _ms_fish_mise_restore_autoload
    _ms_fish_mise_restore_autoload gvm
end
set -l _ms_gvm_root "$HOME/.gvm"
set -q GVM_ROOT[1]; and test -n "$GVM_ROOT"; and set _ms_gvm_root "$GVM_ROOT"
if test -f "$_ms_gvm_root/scripts/gvm"
    # The first gvm Go on PATH is a parent shell's explicit gvm use; else the selection.
    set -l _ms_gvm_want (_ms_fish_gvm_first "$_ms_gvm_root")
    test -n "$_ms_gvm_want"; or set _ms_gvm_want (_ms_fish_gvm_select "$_ms_gvm_root")
    if test -n "$_ms_gvm_want"
        set -gx GVM_ROOT "$_ms_gvm_root"
        # An inherited activation of the same Go keeps its pkgset.
        if test "$gvm_go_name" != "$_ms_gvm_want"; or not set -q GOPATH[1]; or test -z "$GOPATH"
            set -gx gvm_go_name "$_ms_gvm_want"
            set -gx gvm_pkgset_name global
            set -gx GOPATH "$GVM_ROOT/pkgsets/$_ms_gvm_want/global"
            set -gx GVM_OVERLAY_PREFIX "$GOPATH/overlay"
        end
    end
    _ms_fish_gvm_sync_goroot "$_ms_gvm_root"
    function _ms_fish_gvm_hook --on-variable PWD
        _gvm_auto_use
    end
    _gvm_auto_use
else
    test "$_ms_fish_verbose" = 1; and printf 'marksharc: removing the go.mod hook\n' >&2
    functions -e _ms_fish_gvm_hook
end
return 0
