# shellcheck shell=sh
# Per-example sandbox: a temporary HOME with XDG dirs and ZDOTDIR, a stub bin
# directory first on PATH, and an operation log. Works under sh, bash and zsh.

# stub_command NAME BODY: install an executable NAME, first on PATH, that runs BODY under /bin/sh.
stub_command() {
  printf '#!/bin/sh\n%s\n' "$2" > "$TEST_ROOT/bin/$1"
  chmod +x "$TEST_ROOT/bin/$1"
}
fixture_setup() {
  TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/marksharc-case.XXXXXX")
  TEST_ROOT=$(CDPATH='' cd -- "$TEST_ROOT" && pwd -P)
  export TEST_ROOT HOME="$TEST_ROOT/home" ZDOTDIR="$TEST_ROOT/home/zsh" OPLOG="$TEST_ROOT/operations"
  export XDG_CONFIG_HOME="$HOME/config" XDG_CACHE_HOME="$HOME/cache" XDG_DATA_HOME="$HOME/data" XDG_STATE_HOME="$HOME/state"
  export XDG_RUNTIME_DIR="$HOME/run"
  export MARKSHARC_NOTIFY=0
  mkdir -p "$HOME" "$ZDOTDIR" "$TEST_ROOT/bin"
  : > "$OPLOG"
  if [ -n "${REAL_FISH:-}" ]; then
    fish_quoted=$(printf '%s' "$REAL_FISH" | sed "s/'/'\\\\''/g")
    printf '#!/bin/sh\nexec '\''%s'\'' "$@"\n' "$fish_quoted" > "$TEST_ROOT/bin/fish"
    chmod +x "$TEST_ROOT/bin/fish"
  fi
  # Only explicit fixture executables precede the basic OS command set.
  PATH="$TEST_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin"; export PATH
  # Commands that reach the network, other hosts or real services fail loudly.
  for tool in curl wget sudo cwf ssh-agent ssh-add herdr collie codegraph brew gvm node npm; do
    # shellcheck disable=SC2016 # $* and $OPLOG expand when the stub runs
    stub_command "$tool" 'printf "FORBIDDEN %s\n" "'"$tool"' $*" >> "$OPLOG"; exit 99'
  done
  stub_command launchctl 'exit 1'
  unset SSH_AUTH_SOCK SSH_AGENT_PID SSH_CONNECTION SSH_TTY TMUX TMUX_PANE NVM_DIR BASH_ENV ENV HERDR_BIN_PATH HERDR_SOCKET_PATH HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_PANE_ID WEZTERM_PANE HC_TERMINAL_ID
}
fixture_teardown() { cd /; rm -rf -- "$TEST_ROOT"; }
iecho() { :; }
ierr() { printf '%s\n' "$*" >&2; }
have_command() { command -v "$1" >/dev/null 2>&1; }
bash_interactive_unavailable() {
  ! "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c \
    '(( BASH_VERSINFO[0] > 4 || (BASH_VERSINFO[0] == 4 && BASH_VERSINFO[1] >= 4) ))' 2>/dev/null
}
bash_prompt_array_unavailable() {
  ! "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c \
    '(( BASH_VERSINFO[0] > 5 || (BASH_VERSINFO[0] == 5 && BASH_VERSINFO[1] >= 1) ))' 2>/dev/null
}
# Real Git only operates on disposable fixtures; no real remote URLs are configured.
git_fixture() {
  "$REAL_GIT" init -q -b "${1:-main}" "$TEST_ROOT/base"
  cd "$TEST_ROOT/base" || return
  "$REAL_GIT" config user.email fixture@example.invalid
  "$REAL_GIT" config user.name Fixture
  printf '%s\n' 'node_modules/' > .gitignore
  printf '%s\n' retained > retained
  "$REAL_GIT" add .
  "$REAL_GIT" commit -qm initial
  "$REAL_GIT" worktree add -qb feature "$TEST_ROOT/worktree" >/dev/null
  cd "$TEST_ROOT/worktree" || return
}
run_bounded() {
  "$@" &
  bounded_child=$!
  (
    trap 'kill "$bounded_delay" 2>/dev/null; exit 0' TERM
    sleep 15 &
    bounded_delay=$!
    wait "$bounded_delay"
    kill -TERM "$bounded_child" 2>/dev/null
  ) &
  bounded_watch=$!
  wait "$bounded_child"
  bounded_result=$?
  kill -TERM "$bounded_watch" 2>/dev/null
  wait "$bounded_watch" 2>/dev/null
  return "$bounded_result"
}
file_mode() {
  case $(uname -s) in
    Darwin) stat -f %Lp "$1";;
    *) stat -c %a "$1";;
  esac
}
