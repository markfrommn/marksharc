source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
# The module's functions are loaded as the loader does it; init.fish runs per test group.
set -g MOD "$MARKSHARC_ROOT/modules/node-nvm"

# A fake nvm store with a fake nvm.sh. nvm.sh logs that it was sourced; nvm use / install
# choose $NVM_DIR/versions/node/v<version>/bin from the .nvmrc (found upward) or the
# default alias, and install creates the directory unless $NVM_DIR/noinstall exists.
set -g NVM "$TEST_ROOT/nv m"
command mkdir -p "$NVM/alias" "$NVM/versions/node/v20.1.0/bin" "$NVM/versions/node/v18.2.0/bin"
printf '20\n' >"$NVM/alias/default"
printf '%s\n' \
    'echo "sourced $*" >>"$OPLOG"' \
    '_fake_rc() { d=$PWD; while [ ! -f "$d/.nvmrc" ] && [ "$d" != / ]; do d=$(dirname "$d"); done; [ -f "$d/.nvmrc" ] && cat "$d/.nvmrc"; }' \
    '_fake_pick() { v=$1; case "$v" in v*) v=${v#v};; esac; best=; for d in "$NVM_DIR"/versions/node/v"$v"*; do [ -d "$d/bin" ] && best=$d; done; [ -n "$best" ] || return 3; NVM_BIN=$best/bin; NVM_INC=$best/include/node; export NVM_BIN NVM_INC; }' \
    'nvm() {' \
    '  echo "nvm $*" >>"$OPLOG"' \
    '  cmd=$1; shift' \
    '  [ "$1" = --silent ] && shift' \
    '  ver=$1' \
    '  [ -n "$ver" ] || ver=$(_fake_rc) || return 3' \
    '  [ "$ver" = default ] && ver=$(cat "$NVM_DIR/alias/default")' \
    '  case $cmd in' \
    '    use) [ "$ver" = system ] && { unset NVM_BIN NVM_INC; return 0; }; _fake_pick "$ver" ;;' \
    '    install) [ -e "$NVM_DIR/noinstall" ] && return 4; mkdir -p "$NVM_DIR/versions/node/v$ver/bin"; _fake_pick "$ver"; [ -z "$FAKE_NVM_NOISE" ] || echo "Now using node v$ver" ;;' \
    '  esac' \
    '}' >"$NVM/nvm.sh"

set -g PROJ "$TEST_ROOT/pro j/sub dir"
command mkdir -p "$PROJ"
set -g TREE "$TEST_ROOT/pro j"
set -g DEFAULT_BIN "$NVM/versions/node/v20.1.0/bin"
set -g OLD_BIN "$NVM/versions/node/v18.2.0/bin"
set -gx NVM_DIR "$NVM"
set -gx PATH "$TEST_ROOT/bin" /opt/first "$DEFAULT_BIN" /opt/last /usr/bin /bin
set -g START_PATH $PATH

function spawns
    count (string match -- 'sourced*' <"$OPLOG")
end
function pathline
    string join '|' -- $PATH
end

# 1. No .nvmrc and no earlier switch: nothing runs.
builtin cd "$HOME"
ms_module node-nvm >"$TEST_ROOT/out" 2>&1
@test "startup is quiet" ! -s "$TEST_ROOT/out"
@test "no .nvmrc at startup spawns nothing" (spawns) -eq 0
@test "no .nvmrc at startup leaves PATH alone" (pathline) = (string join '|' -- $START_PATH)
@test "no .nvmrc at startup sets no NVM_BIN" (set -q NVM_BIN; echo $status) = 1
@test "the PWD hook is installed" (functions -q _ms_fish_nvmrc_hook; and echo yes) = yes
builtin cd "$TEST_ROOT"
@test "changing directory without an .nvmrc spawns nothing" (spawns) -eq 0

# 2. Entering a tree with an .nvmrc switches node and replaces the env phase's entry in place.
printf '18\n' >"$TREE/.nvmrc"
builtin cd "$PROJ"
@test "the hook switched node on cd" "$NVM_BIN" = "$OLD_BIN"
@test "the earlier nvm entry is replaced where it stood" (pathline) = (string join '|' -- "$TEST_ROOT/bin" /opt/first "$OLD_BIN" /opt/last /usr/bin /bin)
@test "NVM_INC points at the node include directory" "$NVM_INC" = "$NVM/versions/node/v18.2.0/include/node"
@test "NVM_BIN is exported" (set -qx NVM_BIN; and echo yes) = yes
@test "bash ran nvm use for the .nvmrc" (count (string match -- 'nvm use --silent' <"$OPLOG")) -eq 1
@test "the switch is quiet" (load-nvmrc 2>&1 | count) -eq 0

# 3. Moving inside the tree spawns nothing while PATH still has that node.
set -l before (spawns)
builtin cd "$TREE"
builtin cd "$PROJ"
@test "moving inside the tree does not spawn bash again" (spawns) -eq $before

# 4. Changing the .nvmrc contents selects again.
printf '20\n' >"$TREE/.nvmrc"
load-nvmrc
@test "an edited .nvmrc selects the new version" "$NVM_BIN" = "$DEFAULT_BIN"
@test "an edited .nvmrc keeps one nvm entry" (count (string match -- "$NVM/versions/node/*" $PATH)) -eq 1

# 5. Someone else changed PATH (a manual switch): the next load restores the .nvmrc node.
set -gx PATH (string match -v -- "$DEFAULT_BIN" $PATH) "$OLD_BIN"
load-nvmrc
@test "the corrected PATH has the .nvmrc node" (contains -- "$DEFAULT_BIN" $PATH; and echo yes) = yes
@test "the corrected PATH drops the other nvm node" (contains -- "$OLD_BIN" $PATH; and echo yes; or echo no) = no

# 6. Leaving the tree selects the default alias.
set -gx PATH $START_PATH
printf '18\n' >"$TREE/.nvmrc"
load-nvmrc
@test "the .nvmrc node is back" "$NVM_BIN" = "$OLD_BIN"
builtin cd "$HOME"
@test "leaving the tree selects the default node" "$NVM_BIN" = "$DEFAULT_BIN"
@test "the default node keeps its place" (pathline) = (string join '|' -- "$TEST_ROOT/bin" /opt/first "$DEFAULT_BIN" /opt/last /usr/bin /bin)
@test "the default was asked for by name" (count (string match -- 'nvm use --silent default' <"$OPLOG")) -ge 1
set before (spawns)
builtin cd "$TEST_ROOT"
@test "moving outside any tree spawns nothing more" (spawns) -eq $before

# 7. A version that is not installed is installed.
printf '22.3.0\n' >"$TREE/.nvmrc"
builtin cd "$PROJ"
@test "a missing version falls back to nvm install" (count (string match -- 'nvm install' <"$OPLOG")) -eq 1
@test "the installed node is on PATH" "$NVM_BIN" = "$NVM/versions/node/v22.3.0/bin"
# nvm's own chatter goes to stderr (fish does not apply a redirect to a command
# substitution's stderr, so one "Now using" line may show in the test log).
command rm -rf "$NVM/versions/node/v22.3.0"
set -e _ms_nvm_key
set -lx FAKE_NVM_NOISE 1
load-nvmrc >"$TEST_ROOT/stdout"
@test "install output never reaches stdout" ! -s "$TEST_ROOT/stdout"

# 8. A failing install keeps PATH and the variables.
printf '99\n' >"$TREE/.nvmrc"
touch "$NVM/noinstall"
set -l path_before (pathline)
set -l bin_before "$NVM_BIN"
load-nvmrc 2>/dev/null
@test "a failing install returns non-zero" $status -ne 0
@test "a failing install leaves PATH alone" (pathline) = "$path_before"
@test "a failing install leaves NVM_BIN alone" "$NVM_BIN" = "$bin_before"
command rm -f "$NVM/noinstall"

# 9. A default of system removes the nvm entries and variables.
printf 'system\n' >"$NVM/alias/default"
builtin cd "$HOME"
@test "a system default drops the nvm node from PATH" (count (string match -- "$NVM/versions/node/*" $PATH)) -eq 0
@test "a system default unsets NVM_BIN" (set -q NVM_BIN; echo $status) = 1
@test "a system default unsets NVM_INC" (set -q NVM_INC; echo $status) = 1
@test "a system default keeps the other entries" (pathline) = (string join '|' -- "$TEST_ROOT/bin" /opt/first /opt/last /usr/bin /bin)
set before (spawns)
load-nvmrc
@test "a repeated system selection spawns nothing" (spawns) -eq $before
printf '20\n' >"$NVM/alias/default"

# 10. No nvm entry on PATH: the selected node goes in front.
printf '18\n' >"$TREE/.nvmrc"
set -gx PATH "$TEST_ROOT/bin" /usr/bin /bin
builtin cd "$PROJ"
@test "with no nvm entry the node goes in front" "$PATH[1]" = "$OLD_BIN"

# 11. Startup and reload inside a tree.
set -e _ms_nvm_switched _ms_nvm_key _ms_nvm_bin
set -gx PATH "$TEST_ROOT/bin" /usr/bin /bin
set before (spawns)
ms_module node-nvm >"$TEST_ROOT/out" 2>&1
@test "startup inside a tree selects the .nvmrc node" "$NVM_BIN" = "$OLD_BIN"
@test "startup inside a tree is quiet" ! -s "$TEST_ROOT/out"
set before (spawns)
set -g _ms_fish_reloading 1
ms_module node-nvm >"$TEST_ROOT/out" 2>&1
set -e _ms_fish_reloading
@test "a reload inside a tree does not spawn bash again" (spawns) -eq $before
@test "a reload is quiet" ! -s "$TEST_ROOT/out"

# 12. BASH_ENV is never honoured.
printf 'echo BASHENV >>"$OPLOG"\n' >"$TEST_ROOT/bashenv"
set -gx BASH_ENV "$TEST_ROOT/bashenv"
printf '20\n' >"$TREE/.nvmrc"
load-nvmrc
set -e BASH_ENV
@test "bash runs without BASH_ENV" (count (string match -- BASHENV <"$OPLOG")) -eq 0

# 13. Owned node removes the legacy PWD hook; empty tools or missing mise restore it.
builtin cd "$HOME"
set -l before (spawns)
set -g _ms_opt_mise_tools node
ms_stub mise 'exit 0'
ms_module node-nvm >"$TEST_ROOT/out" 2>&1
@test "owned node removes the nvm PWD hook" (functions -q _ms_fish_nvmrc_hook; echo $status) = 1
@test "owned node startup spawns no legacy nvm" (spawns) = $before
@test "owned node startup is quiet" ! -s "$TEST_ROOT/out"
set -g _ms_opt_mise_tools ''
ms_module node-nvm
@test "empty mise tools restore the nvm PWD hook" (functions -q _ms_fish_nvmrc_hook; and echo yes) = yes
command rm -f "$TEST_ROOT/bin/mise"
set -g _ms_opt_mise_tools node
ms_module node-nvm
@test "missing mise restores the nvm PWD hook" (functions -q _ms_fish_nvmrc_hook; and echo yes) = yes
set -g _ms_opt_mise_tools ''

# 14. Missing nvm.sh: quiet, no hook, nothing spawned.
builtin cd "$HOME"
set -gx NVM_DIR "$TEST_ROOT/no-nvm"
printf '' >"$OPLOG"
ms_module node-nvm >"$TEST_ROOT/out" 2>&1
@test "a missing nvm.sh is quiet" ! -s "$TEST_ROOT/out"
@test "a missing nvm.sh removes the hook" (functions -q _ms_fish_nvmrc_hook; echo $status) = 1
builtin cd "$PROJ"
load-nvmrc
@test "a missing nvm.sh makes load-nvmrc a quiet no-op" $status -eq 0
@test "a missing nvm.sh spawns nothing" ! -s "$OPLOG"

ms_cleanup
