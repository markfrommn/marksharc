# zsh-only helpers for the core loader specs. Each example gets its own HOME
# (fixture_setup); the core is copied into $MS_HOME so nothing writes into the repo.
# Sourced from spec_helper.sh only under zsh (this file is not POSIX).
ms_fixture() {
  MS_HOME="$TEST_ROOT/ms"; export MS_HOME
  mkdir -p "$MS_HOME/modules"
  cp -R "$MARKSHARC_ROOT/core" "$MS_HOME/core"
  # A hand-written equivalent of the installer's stub (no fallback). The real stub is covered by
  # spec/install and spec/zsh/fallback_spec.sh.
  print -r -- "export MARKSHARC_HOME=\"$MS_HOME\"
source \"\$MARKSHARC_HOME/core/zsh/zshenv.zsh\"" > "$HOME/.zshenv"
}
# ms_mod <module> <relative-file> <content>
ms_mod() {
  local dir="$MS_HOME/modules/$1"
  mkdir -p "$dir/${2:h}"
  print -r -- "$3" > "$dir/$2"
}
# Hermetic child environment; leading VAR=value arguments are added to it.
ms_env() {
  # SHLVL > 1 keeps nested test shells from behaving like a fresh login.
  MS_ENV=( HOME="$HOME" PATH="$PATH" TERM=dumb SHLVL=2 MARKSHARC_MODULE_GUARD=0 MARKSHARC_NOTIFY=0 OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT"
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME"
    XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" )
}
# ms_run [VAR=value ...] zsh-args... ; stdout/stderr go to $TEST_ROOT/out and $TEST_ROOT/err
ms_run() {
  ms_env
  local -a extra=()
  while [[ $1 == [A-Za-z_]*=* ]]; do extra+=( "$1" ); shift; done
  env -i "${MS_ENV[@]}" "${extra[@]}" /bin/zsh "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
}
# ms_pty [VAR=value ...] zsh-args... ; combined output in $TEST_ROOT/out
ms_pty() {
  ms_env
  local -a extra=()
  while [[ $1 == [A-Za-z_]*=* ]]; do extra+=( "$1" ); shift; done
  "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty env -i "${MS_ENV[@]}" "${extra[@]}" /bin/zsh "$@" > "$TEST_ROOT/out" 2>&1
}
# ms_fixture_full: copy the whole public tree (core and modules) so a spec
# can patch files without touching the repository. The overlay is per-test.
ms_fixture_full() {
  MS_HOME="$TEST_ROOT/ms"; export MS_HOME
  mkdir -p "$MS_HOME"
  cp -R "$MARKSHARC_ROOT/core" "$MS_HOME/core"
  cp -R "$MARKSHARC_ROOT/modules" "$MS_HOME/modules"
  print -r -- "export MARKSHARC_HOME=\"$MS_HOME\"
source \"\$MARKSHARC_HOME/core/zsh/zshenv.zsh\"" > "$HOME/.zshenv"
}
# ms_unit [VAR=value ...] <script>: run <script> in zsh -f (no rc files) with the core
# libraries loaded from the repository, so a module file can be exercised directly with
# preset facts. Output goes to $TEST_ROOT/out and $TEST_ROOT/err.
ms_unit() {
  ms_env
  local -a extra=()
  while [[ $1 == [A-Za-z_][A-Za-z0-9_]#=[^[:space:]]# ]]; do extra+=( "$1" ); shift; done
  local pre='MARKSHARC_HOME="$MARKSHARC_ROOT"; _ms_verbose=0; MARKSHARC_SESSION=${MARKSHARC_SESSION:-batch}
for _l in util session facts cache modules; do source "$MARKSHARC_HOME/core/zsh/lib/$_l.zsh"; done
_ms_facts; _ms_env_rebuild=1; typeset -ga _ms_env_finalizers=()
_ms_test_render_module() {
  local _dot=${_ms_opt_core_dot_in_path-} _cache
  source "$MARKSHARC_HOME/core/zsh/lib/render.zsh"
  _ms_env_id_value=test
  _ms_render 0 || return
  [[ -n $_dot ]] && _ms_opt_core_dot_in_path=$_dot
  _cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/$MARKSHARC_HOST
  source "$_cache/env.zsh" || return
  _ms_rendered_env "$1"
}
'
  env -i "${MS_ENV[@]}" MARKSHARC_ROOT="$MARKSHARC_ROOT" "${extra[@]}" /bin/zsh -f -c "$pre$1" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
}
# ms_copy_module <name>...: copy real modules into the core fixture.
ms_copy_module() {
  local m
  for m in "$@"; do cp -R "$MARKSHARC_ROOT/modules/$m" "$MS_HOME/modules/$m"; done
}
# load_mfn <module> [fn...]: put a module's functions/zsh on fpath and autoload the named
# functions (every file when none are named), the way the module loader does; internal helpers
# resolve too.
load_mfn() {
  local dir="$MARKSHARC_ROOT/modules/$1/functions/zsh" fn
  shift
  fpath=( "$dir" ${fpath:#$dir} )
  (( $# )) || set -- "$dir"/*(N-.:t)
  for fn; do unfunction "$fn" 2>/dev/null; autoload -Uz "$fn"; done
}
# module_run <module> <zsh-code>: run code in a clean zsh -f child with the module's init.zsh
# available as $MOD_INIT and the module's functions on fpath. Output goes to $TEST_ROOT/out.
module_run() {
  local mod=$1 code=$2 moddir="$MARKSHARC_ROOT/modules/$1"
  env -i HOME="$HOME" PATH="$PATH" TERM=dumb OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT" MOD_DIR="$moddir" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    /bin/zsh -f -c 'fpath=( "$MOD_DIR/functions/zsh"(N) $fpath ); autoload -Uz "$MOD_DIR"/functions/zsh/*(N:t); MOD_INIT=$MOD_DIR/init.zsh; '"$code" > "$TEST_ROOT/out" 2>&1 < /dev/null
}
