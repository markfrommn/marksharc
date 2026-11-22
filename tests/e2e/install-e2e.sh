#!/bin/sh
# End-to-end install check (spec 6.15, plan P2.4 "Done when"): install marksharc into a fresh
# HOME, start login and interactive zsh shells, and prove they come up working
# (MARKSHARC_SESSION set, the marksharc command resolves, nothing on stderr), then uninstall.
# Two passes, each in its own fresh HOME:
#   1. "checkout": sh <checkout>/install.sh --home <checkout>   (the clone-first README path)
#   2. "clone":    sh < <checkout>/install.sh with MARKSHARC_REPO=<checkout>, run from a directory
#                  that is not a checkout (the curl | sh README path: the installer clones),
#                  ending in uninstall --purge --yes, which must delete that clone.
# Needs only sh, zsh and git; the interactive-on-a-terminal step also uses python3 when present.
#
# Usage: tests/e2e/install-e2e.sh <checkout>
# CI runs it on macOS and Ubuntu against the pull request checkout; it also runs in a Linux
# container. The checkout is only read; everything else happens under a temporary HOME. (If the
# checkout belongs to another user, git may refuse the clone pass with "dubious ownership".)
set -eu

[ $# -eq 1 ] || { echo "usage: $0 <marksharc checkout>" >&2; exit 2; }
checkout=$(CDPATH='' cd -- "$1" && pwd)
[ -r "$checkout/install.sh" ] && [ -r "$checkout/core/zsh/zshenv.zsh" ] || { echo "e2e: $1 is not a marksharc checkout" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/marksharc-e2e.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
trap 'exit 130' HUP INT TERM
out=$work/out
err=$work/err
home=

fail() { echo "e2e: FAIL: $*" >&2; exit 1; }
step() { echo "e2e: [$pass] $*"; }
# clean_env CMD...: run CMD with a minimal environment and the pass's fresh HOME (no XDG variables).
clean_env() { env -i HOME="$home" PATH="$PATH" TERM=dumb SHELL=/bin/sh LANG=C MARKSHARC_NOTIFY=0 "$@"; }
# silent DESCRIPTION CMD...: run CMD (stdin closed); stdout goes to $out; nothing may reach stderr.
silent() {
  desc=$1; shift
  clean_env "$@" > "$out" 2> "$err" < /dev/null || { cat "$err" >&2; fail "$desc: command failed"; }
  [ ! -s "$err" ] || { cat "$err" >&2; fail "$desc: unexpected stderr"; }
}

# exercise PASS: install (the way PASS says), start shells, uninstall. Sets pass and home.
exercise() {
  pass=$1
  home=$work/$pass/home
  mkdir -p "$home" "$work/$pass/cwd"
  step "install into a fresh HOME"
  case $pass in
    checkout)
      fw=$checkout
      clean_env sh "$checkout/install.sh" --home "$checkout" > "$work/install.log" 2>&1 || { cat "$work/install.log" >&2; fail "install.sh failed"; }
      ;;
    clone)
      fw=$home/.local/share/marksharc
      # The installer is piped in and run from a directory that is not a checkout.
      (cd "$work/$pass/cwd" && clean_env MARKSHARC_REPO="$checkout" sh < "$checkout/install.sh") > "$work/install.log" 2>&1 || { cat "$work/install.log" >&2; fail "piped install.sh failed"; }
      [ -d "$fw/.git" ] && [ -r "$fw/core/zsh/zshenv.zsh" ] || fail "the installer did not clone the framework into $fw"
      grep -q '^framework_cloned=1$' "$home/.local/state/marksharc/install.manifest" || fail "the manifest does not record the clone"
      ;;
  esac
  [ -f "$home/.zshenv" ] || fail "the stub was not written"
  head -n 1 "$home/.zshenv" | grep -q 'marksharc: managed stub' || fail "the stub has no marksharc header"
  [ -f "$home/.local/state/marksharc/install.manifest" ] || fail "no install manifest"
  [ -f "$home/.config/marksharc/config.conf" ] || fail "the template overlay was not installed"

  step "login shell comes up working"
  # shellcheck disable=SC2016 # the zsh code is single-quoted on purpose
  silent "login shell" zsh -l -c 'print -r -- "$MARKSHARC_SESSION|$MARKSHARC_HOME"; command -v marksharc'
  session=$(sed -n 1p "$out")
  [ "${session%%|*}" = batch ] || fail "login shell: MARKSHARC_SESSION is '${session%%|*}', expected batch"
  [ "${session#*|}" = "$fw" ] || fail "login shell: MARKSHARC_HOME is '${session#*|}', expected $fw"
  [ "$(sed -n 2p "$out")" = "$fw/bin/marksharc" ] || fail "login shell: marksharc resolves to '$(sed -n 2p "$out")'"
  [ -d "$home/.local/state/marksharc/zdot" ] || fail "login shell did not generate the ZDOTDIR"

  step "interactive shell (no terminal) comes up working"
  # shellcheck disable=SC2016
  silent "interactive shell" zsh -i -c 'print -r -- "$MARKSHARC_SESSION"; command -v marksharc'
  [ -n "$(sed -n 1p "$out")" ] || fail "interactive shell: MARKSHARC_SESSION is empty"
  [ "$(sed -n 2p "$out")" = "$fw/bin/marksharc" ] || fail "interactive shell: marksharc not on PATH"

  step "agent-marked shell is quiet and has the command"
  # shellcheck disable=SC2016
  silent "agent shell" env CLAUDECODE=1 zsh -c 'print -r -- "$MARKSHARC_SESSION"; command -v marksharc'
  [ "$(sed -n 1p "$out")" = agent ] || fail "agent shell: MARKSHARC_SESSION is '$(sed -n 1p "$out")'"

  step "marksharc version and module list"
  silent "marksharc version" zsh -c 'marksharc version'
  grep -q '^marksharc [0-9]' "$out" || fail "marksharc version printed '$(cat "$out")'"
  silent "marksharc module list" zsh -c 'marksharc module list'
  grep -q ' enabled ' "$out" || fail "marksharc module list shows no enabled module"
  ! grep -q ' disabled ' "$out" || fail "the template overlay disables a module"

  if command -v python3 > /dev/null 2>&1; then
    step "interactive shell on a terminal comes up working"
    # shellcheck disable=SC2016
    clean_env TERM=xterm-256color python3 "$checkout/tests/support/pty_socket.py" pty zsh -i -c 'print -r -- "S=$MARKSHARC_SESSION F=$+functions[marksharc]"; exit' > "$out" 2>&1 < /dev/null || { cat "$out" >&2; fail "terminal shell failed"; }
    grep -q 'S=interactive F=1' "$out" || { cat "$out" >&2; fail "terminal shell: expected S=interactive F=1"; }
    # Tools on the machine (starship, atuin, ...) may print in a terminal; marksharc itself must not.
    ! grep -Ei 'marksharc:|command not found|no such file|error' "$out" > /dev/null || { cat "$out" >&2; fail "terminal shell reported a problem"; }
  else
    step "python3 not found; skipping the terminal check"
  fi

  step "uninstall"
  if [ "$pass" = clone ]; then
    silent "marksharc uninstall --purge" zsh -c 'marksharc uninstall --purge --yes'
    [ ! -e "$fw" ] || fail "--purge did not delete the clone"
    [ ! -e "$home/.local/state/marksharc" ] || fail "--purge did not delete the state directory"
  else
    silent "marksharc uninstall" zsh -c 'marksharc uninstall'
    [ -d "$fw" ] || fail "uninstall removed the checkout"
  fi
  [ ! -e "$home/.zshenv" ] || fail "the stub is still there after uninstall"
  [ ! -e "$home/.local/state/marksharc/zdot" ] || fail "the generated ZDOTDIR is still there after uninstall"
  [ -f "$home/.config/marksharc/config.conf" ] || fail "uninstall removed the overlay"
  # shellcheck disable=SC2016
  silent "plain shell after uninstall" zsh -c 'print -r -- "$+MARKSHARC_HOME"'
  [ "$(cat "$out")" = 0 ] || fail "marksharc is still active after uninstall"
}

pass=start
exercise checkout
exercise clone
echo "e2e: ok"
