source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
set -g MOD "$MARKSHARC_ROOT/modules/go-gvm"

# A fake gvm store: scripts/gvm defines a bash gvm function that logs its arguments (one per
# line, `|`-joined) to $OPLOG; three Go versions (1.9.7 is older than 1.21.5 numerically,
# not alphabetically); go is a script.
set -g GV "$TEST_ROOT/gv m"
for name in go1.9.7 go1.21.5 go1.22.1
    command mkdir -p "$GV/gos/$name/bin" "$GV/pkgsets/$name/global/bin" "$GV/pkgsets/$name/global/overlay/bin"
    printf '#!/bin/sh\necho %s\n' $name >"$GV/gos/$name/bin/go"
    command chmod +x "$GV/gos/$name/bin/go"
end
command mkdir -p "$GV/scripts" "$GV/environments" "$GV/bin"
printf '%s\n' \
    'gvm() { { printf "gvm"; for a in "$@"; do printf "|%s" "$a"; done; echo; } >>"$OPLOG"; }' >"$GV/scripts/gvm"
printf 'export gvm_go_name; gvm_go_name="go1.21.5"\n' >"$GV/environments/default"
set -gx GVM_ROOT "$GV"

function gos
    string join '|' -- $PATH
end
function calls
    count (string match -- 'gvm*' <"$OPLOG")
end
set -g OTHER /opt/other /usr/bin /bin
function trio --argument-names name
    printf '%s\n' "$GV/pkgsets/$name/global/bin" "$GV/gos/$name/bin" "$GV/pkgsets/$name/global/overlay/bin"
end

# 1. Startup names the default environment's Go and syncs GOROOT; nothing is run or printed.
set -gx PATH "$TEST_ROOT/bin" (trio go1.21.5) "$GV/bin" $OTHER
set -g START_PATH $PATH
builtin cd "$HOME"
ms_module go-gvm >"$TEST_ROOT/out" 2>&1
@test "startup is quiet" ! -s "$TEST_ROOT/out"
@test "startup runs no bash" (calls) -eq 0
@test "GVM_ROOT is exported" "$GVM_ROOT" = "$GV"
@test "gvm_go_name names the Go that is first on PATH" "$gvm_go_name" = go1.21.5
@test "gvm_pkgset_name is global" "$gvm_pkgset_name" = global
@test "GOPATH is the global pkgset" "$GOPATH" = "$GV/pkgsets/go1.21.5/global"
@test "GVM_OVERLAY_PREFIX is under GOPATH" "$GVM_OVERLAY_PREFIX" = "$GV/pkgsets/go1.21.5/global/overlay"
@test "GOROOT follows the first go on PATH" "$GOROOT" = "$GV/gos/go1.21.5"
@test "gvm variables are exported" (set -qx gvm_go_name GOPATH GOROOT GVM_ROOT; and echo yes) = yes
@test "startup leaves PATH alone" (gos) = (string join '|' -- $START_PATH)
@test "the go.mod hook is installed" (functions -q _ms_fish_gvm_hook; and echo yes) = yes

# 2. A parent shell's explicit use of another Go wins over the default environment.
for v in gvm_go_name gvm_pkgset_name GOPATH GVM_OVERLAY_PREFIX GOROOT
    set -e $v
end
set -gx PATH "$TEST_ROOT/bin" (trio go1.22.1) $OTHER
ms_module go-gvm
@test "the first gvm Go on PATH wins over the default" "$gvm_go_name" = go1.22.1
@test "GOROOT names that Go" "$GOROOT" = "$GV/gos/go1.22.1"

# 3. An inherited activation of the same Go keeps its pkgset.
set -gx GOPATH "$GV/pkgsets/go1.22.1/mine"
ms_module go-gvm
@test "an inherited pkgset of the same Go is kept" "$GOPATH" = "$GV/pkgsets/go1.22.1/mine"

# 4. No gvm Go on PATH: the selection (default environment) names it, GOROOT is untouched
#    for a missing go, and an inherited GOROOT of another Go is dropped.
for v in gvm_go_name gvm_pkgset_name GOPATH GVM_OVERLAY_PREFIX GOROOT
    set -e $v
end
# No system directories here: a host may have go in /usr/bin.
set -gx PATH "$TEST_ROOT/bin" /opt/other
set -gx GOROOT /somewhere/else
ms_module go-gvm
@test "with no go on PATH the default environment names the Go" "$gvm_go_name" = go1.21.5
@test "with no go on PATH GOROOT is left alone" "$GOROOT" = /somewhere/else
set -gx PATH "$TEST_ROOT/bin" $OTHER
printf '#!/bin/sh\n' >"$TEST_ROOT/bin/go"
command chmod +x "$TEST_ROOT/bin/go"
ms_module go-gvm
@test "a non-gvm go first drops an inherited GOROOT of another Go" (set -q GOROOT; echo $status) = 1
command rm -f "$TEST_ROOT/bin/go"

# 5. Without a default environment the numerically newest installed Go is chosen.
command rm -f "$GV/environments/default"
for v in gvm_go_name gvm_pkgset_name GOPATH GVM_OVERLAY_PREFIX GOROOT
    set -e $v
end
set -gx PATH "$TEST_ROOT/bin" $OTHER
ms_module go-gvm
@test "the newest installed Go is the fallback (numeric order)" "$gvm_go_name" = go1.22.1
printf 'export gvm_go_name; gvm_go_name="go1.21.5"\n' >"$GV/environments/default"

# 6. gvm use switches natively: PATH entries are replaced in place, variables set, no bash.
set -gx PATH "$TEST_ROOT/bin" /opt/first (trio go1.21.5) "$GV/bin" /opt/last /usr/bin /bin
printf '' >"$OPLOG"
set -l out (gvm use go1.22.1)
@test "use prints the gvm acknowledgement" "$out" = "Now using version go1.22.1"
@test "use replaces the gvm entries where they stood" (gos) = (string join '|' -- "$TEST_ROOT/bin" /opt/first (trio go1.22.1) "$GV/bin" /opt/last /usr/bin /bin)
@test "use sets GOROOT" "$GOROOT" = "$GV/gos/go1.22.1"
@test "use sets GOPATH to the global pkgset" "$GOPATH" = "$GV/pkgsets/go1.22.1/global"
@test "use sets gvm_go_name and gvm_pkgset_name" "$gvm_go_name $gvm_pkgset_name" = "go1.22.1 global"
@test "use sets GVM_OVERLAY_PREFIX" "$GVM_OVERLAY_PREFIX" = "$GV/pkgsets/go1.22.1/global/overlay"
@test "use exports what it sets" (set -qx GOROOT GOPATH PATH gvm_go_name GVM_OVERLAY_PREFIX; and echo yes) = yes
@test "use runs no bash" (calls) -eq 0
@test "go resolves to the new Go" "$(go)" = go1.22.1

# 7. Use with the gvm entries absent puts the new ones in front.
set -gx PATH "$TEST_ROOT/bin" /usr/bin /bin
gvm use go1.9.7 >/dev/null
@test "use with no gvm entries prepends them" (gos) = (string join '|' -- (trio go1.9.7) "$TEST_ROOT/bin" /usr/bin /bin)

# 8. A Go that is not installed fails without changing anything.
set -l before (gos)
gvm use go1.99.0 2>"$TEST_ROOT/err" >"$TEST_ROOT/out"
@test "an uninstalled Go fails" $status -eq 1
@test "an uninstalled Go prints nothing on stdout" ! -s "$TEST_ROOT/out"
@test "an uninstalled Go says so on stderr" (count (string match -- '*go1.99.0*' <"$TEST_ROOT/err")) -eq 1
@test "an uninstalled Go leaves PATH alone" (gos) = "$before"
@test "an uninstalled Go leaves gvm_go_name alone" "$gvm_go_name" = go1.9.7

# 9. use --default also asks gvm under bash to record the default.
printf '' >"$OPLOG"
set out (gvm use go1.22.1 --default)
@test "use --default switches natively too" "$gvm_go_name" = go1.22.1
@test "use --default leaves the acknowledgement to gvm" -z "$out"
@test "use --default runs gvm use under bash" "$(cat "$OPLOG")" = "gvm|use|go1.22.1|--default"
printf '' >"$OPLOG"
gvm use --default go1.21.5 >/dev/null
@test "the --default flag may come first" "$(cat "$OPLOG")" = "gvm|use|--default|go1.21.5"

# 10. Every other subcommand runs under bash, argument for argument, and changes nothing here.
printf '' >"$OPLOG"
set before (gos)
gvm pkgset create 'my set' >/dev/null
@test "other subcommands run under bash with arguments intact" "$(cat "$OPLOG")" = "gvm|pkgset|create|my set"
gvm list >/dev/null
@test "gvm list runs under bash" (calls) -eq 2
@test "other subcommands leave PATH alone" (gos) = "$before"
printf '' >"$OPLOG"
gvm use 'go1.21.5@mine' >/dev/null
@test "use with a pkgset is left to bash" "$(cat "$OPLOG")" = "gvm|use|go1.21.5@mine"

# 11. bash starts without BASH_ENV and prints nothing of the sourcing.
printf 'echo BASHENV >>"$OPLOG"\n' >"$TEST_ROOT/bashenv"
set -gx BASH_ENV "$TEST_ROOT/bashenv"
printf '' >"$OPLOG"
gvm list >"$TEST_ROOT/out" 2>&1
set -e BASH_ENV
@test "gvm under bash ignores BASH_ENV" (count (string match -- BASHENV <"$OPLOG")) -eq 0
@test "gvm under bash adds no output of its own" ! -s "$TEST_ROOT/out"

# 12. The go.mod hook.
set -gx PATH "$TEST_ROOT/bin" (trio go1.21.5) $OTHER
gvm use go1.21.5 >/dev/null
set -g PROJ "$TEST_ROOT/pro j"
command mkdir -p "$PROJ/sub"
printf 'module example.com/x\n\ngo 1.22.1\n\nrequire x v1\n' >"$PROJ/go.mod"
printf '' >"$OPLOG"
builtin cd "$PROJ"
@test "entering a go.mod directory switches to its Go" "$gvm_go_name" = go1.22.1
@test "the go.mod switch runs no bash" (calls) -eq 0
@test "the go.mod switch is quiet" "$(_gvm_auto_use)" = ""
builtin cd sub
@test "a directory without go.mod leaves the Go alone" "$gvm_go_name" = go1.22.1
builtin cd "$PROJ"
printf 'go 1.21.5\ntoolchain go1.22.1\n' >"$PROJ/go.mod"
builtin cd sub
builtin cd "$PROJ"
@test "a changed go.mod switches again (first go line only)" "$gvm_go_name" = go1.21.5
printf 'go 1.80\n' >"$PROJ/go.mod"
# (an event handler's output is not captured by a redirect, so the hook is called directly)
builtin cd "$HOME"
functions -e _ms_fish_gvm_hook
builtin cd "$PROJ"
_gvm_auto_use >"$TEST_ROOT/out" 2>&1
@test "an uninstalled Go in go.mod is reported" "$(cat "$TEST_ROOT/out")" = "GVM: go1.80 is not installed."
@test "an uninstalled Go in go.mod leaves the Go alone" "$gvm_go_name" = go1.21.5
printf 'module x\n' >"$PROJ/go.mod"
@test "a go.mod without a go line does nothing" "$(_gvm_auto_use)" = ""
builtin cd "$HOME"

# 13. A reload keeps one hook and stays quiet.
set -g _ms_fish_reloading 1
ms_module go-gvm >"$TEST_ROOT/out" 2>&1
set -e _ms_fish_reloading
@test "a reload is quiet" ! -s "$TEST_ROOT/out"
printf 'go 1.22.1\n' >"$PROJ/go.mod"
builtin cd "$PROJ"
@test "the hook still switches after a reload" "$gvm_go_name" = go1.22.1
builtin cd "$HOME"

# 14. Owned Go removes the go.mod PWD hook; empty tools or missing mise restore it.
builtin cd "$HOME"
set -g _ms_opt_mise_tools go
ms_stub mise 'exit 0'
ms_module go-gvm >"$TEST_ROOT/out" 2>&1
@test "owned Go removes the gvm PWD hook" (functions -q _ms_fish_gvm_hook; echo $status) = 1
@test "owned Go startup is quiet" ! -s "$TEST_ROOT/out"
set -g _ms_opt_mise_tools ''
ms_module go-gvm
@test "empty mise tools restore the gvm PWD hook" (functions -q _ms_fish_gvm_hook; and echo yes) = yes
command rm -f "$TEST_ROOT/bin/mise"
set -g _ms_opt_mise_tools go
ms_module go-gvm
@test "missing mise restores the gvm PWD hook" (functions -q _ms_fish_gvm_hook; and echo yes) = yes
set -g _ms_opt_mise_tools ''

# 15. No gvm installation: quiet, no hook, and gvm says so.
set -gx GVM_ROOT "$TEST_ROOT/none"
set -e gvm_go_name
ms_module go-gvm >"$TEST_ROOT/out" 2>&1
@test "without gvm startup is quiet" ! -s "$TEST_ROOT/out"
@test "without gvm the hook is removed" (functions -q _ms_fish_gvm_hook; echo $status) = 1
@test "without gvm nothing is exported" (set -q gvm_go_name; echo $status) = 1
gvm list 2>"$TEST_ROOT/err"
@test "gvm without an installation fails" $status -eq 1
@test "gvm without an installation names the missing script" (count (string match -- '*scripts/gvm not found*' <"$TEST_ROOT/err")) -eq 1

ms_cleanup
