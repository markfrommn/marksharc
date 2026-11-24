source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
# A host uv would make the module prefer it, so the module runs with only the stub bin
# and a private directory of the few system tools the cache needs; the full PATH is back
# for the helpers.
set -g TOOLS "$TEST_ROOT/tools"
command mkdir -p "$TOOLS"
for tool in sh env mkdir mv rm
    command -sq $tool; and command ln -s (command -s $tool) "$TOOLS/$tool"
end
set -g FULL_PATH $PATH
function init_python
    set -gx PATH "$TEST_ROOT/bin" "$TOOLS"
    ms_module python
    set -l result $status
    set -g MODULE_PATH $PATH
    set -gx PATH $FULL_PATH
    return $result
end

# A fake pyenv: init output, a command list with or without virtualenv-init.
set -g PYENV_BIN "$HOME/.pyenv/bin/pyenv"
command mkdir -p "$HOME/.pyenv/bin"
printf '%s\n' '#!/bin/sh' \
    'echo "pyenv $*" >>"$OPLOG"' \
    'case "$1 $2 $3" in' \
    '  "init - fish") echo "set -gx PYENV_INIT_RAN yes"; echo "function pyenv; command pyenv $argv; end" ;;' \
    '  "virtualenv-init - fish") echo "set -gx PYENV_VENV_RAN yes" ;;' \
    esac \
    'if [ "$1" = commands ]; then echo init; echo "$FAKE_PYENV_COMMANDS"; fi' >"$PYENV_BIN"
command chmod +x "$PYENV_BIN"
command cp "$PYENV_BIN" "$TEST_ROOT/pyenv.fake"

set -gx FAKE_PYENV_COMMANDS virtualenv-init
init_python >"$TEST_ROOT/out" 2>&1
@test "startup is quiet" ! -s "$TEST_ROOT/out"
@test "PYENV_ROOT is exported" "$PYENV_ROOT" = "$HOME/.pyenv"
@test "the pyenv bin directory is on PATH" (contains -- "$HOME/.pyenv/bin" $MODULE_PATH; and echo yes) = yes
@test "pyenv init output is applied" "$PYENV_INIT_RAN" = yes
@test "virtualenv-init output is applied when pyenv lists it" "$PYENV_VENV_RAN" = yes
@test "the init output is cached under the host" (count "$XDG_CACHE_HOME"/marksharc/fixture/init/pyenv__init*.fish) -eq 1

set -l before (count $MODULE_PATH)
init_python
@test "a second init does not duplicate the PATH entry" (count $MODULE_PATH) -eq $before

# A second shell run hits the cache: pyenv is asked for commands only.
printf '' >"$OPLOG"
set -e PYENV_INIT_RAN PYENV_VENV_RAN
init_python
@test "a cache hit still applies the init output" "$PYENV_INIT_RAN" = yes
@test "a cache hit does not run pyenv init again" (count (string match -- 'pyenv init*' <"$OPLOG")) -eq 0

# Reload: once-per-shell init output is skipped.
printf '' >"$OPLOG"
set -e PYENV_INIT_RAN PYENV_VENV_RAN
set -g _ms_fish_reloading 1
init_python >"$TEST_ROOT/out" 2>&1
set -e _ms_fish_reloading
@test "a reload skips the pyenv init output" -z "$PYENV_INIT_RAN"
@test "a reload does not run pyenv" ! -s "$OPLOG"
@test "a reload is quiet" ! -s "$TEST_ROOT/out"

# Without virtualenv-init in the command list it is not sourced.
command rm -rf "$XDG_CACHE_HOME"
set -e PYENV_INIT_RAN PYENV_VENV_RAN
set -gx FAKE_PYENV_COMMANDS other
init_python
@test "init output is applied without virtualenv-init" "$PYENV_INIT_RAN" = yes
@test "virtualenv-init is skipped when pyenv does not list it" -z "$PYENV_VENV_RAN"

# uv is preferred: nothing is run or exported.
ms_stub uv 'exit 0'
command rm -rf "$XDG_CACHE_HOME"
printf '' >"$OPLOG"
set -e PYENV_INIT_RAN PYENV_VENV_RAN PYENV_ROOT
init_python >"$TEST_ROOT/out" 2>&1
@test "with uv installed pyenv is not initialised" -z "$PYENV_INIT_RAN$PYENV_VENV_RAN"
@test "with uv installed pyenv is not run" ! -s "$OPLOG"
@test "with uv installed PYENV_ROOT stays unset" (set -q PYENV_ROOT; and echo set; or echo unset) = unset
@test "uv startup is quiet" ! -s "$TEST_ROOT/out"
command rm -f "$TEST_ROOT/bin/uv"

# No pyenv at all: nothing happens.
command rm -rf "$HOME/.pyenv"
init_python >"$TEST_ROOT/out" 2>&1
@test "without pyenv or uv startup succeeds quietly" ! -s "$TEST_ROOT/out"
init_python
@test "without pyenv or uv init returns success" $status -eq 0

# A HOME with a space in it.
set -gx HOME "$TEST_ROOT/home dir"
command mkdir -p "$HOME/.pyenv/bin"
command cp "$TEST_ROOT/pyenv.fake" "$HOME/.pyenv/bin/pyenv"
command rm -rf "$XDG_CACHE_HOME"
set -e PYENV_INIT_RAN
init_python
@test "a HOME with a space works" "$PYENV_INIT_RAN$PYENV_ROOT" = "yes$HOME/.pyenv"

ms_cleanup
