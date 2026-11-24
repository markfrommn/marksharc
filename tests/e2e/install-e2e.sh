#!/bin/sh
# End-to-end install check (spec 6.15, plans P2.4 and DEV-71): install MarkSharc,
# start shells through their normal startup files, then uninstall.
# Three passes, each in its own temporary HOME:
#   1. "checkout": sh <checkout>/install.sh                    (the clone-first README path)
#   2. "clone":    sh < <checkout>/install.sh with MARKSHARC_REPO=<checkout>, run from a directory
#                  that is not a checkout (the curl | sh README path: the installer clones),
#                  ending in uninstall --purge --yes, which must delete that clone.
#   3. "legacy":   install --clobber over existing zsh, Bash and Fish files, then restore them.
# Needs sh, zsh, bash and git; runs Fish and terminal checks when fish and python3 are available.
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

legacy_dotfiles='.zshenv .zshrc .zprofile .zlogin .zlogout .bashrc .bash_profile .bash_login .profile'
seed_legacy_home() {
  fish_dir=$home/.config/fish
  mkdir -p "$fish_dir/conf.d" "$fish_dir/functions" "$work/$pass/original"
  for name in $legacy_dotfiles; do
    printf '# original %s\n' "$name" > "$home/$name"
  done
  ln -s .profile "$home/.login"
  printf '# original config\n' > "$fish_dir/config.fish"
  printf 'SETUVAR legacy_setting:original\n' > "$fish_dir/fish_variables"
  printf '# original plugin\n' > "$fish_dir/conf.d/plugin.fish"
  printf '# original function\n' > "$fish_dir/functions/legacy.fish"
  cp -pR "$home/." "$work/$pass/original/"
}

verify_legacy_clean() {
  for name in .zshrc .zprofile .zlogin .zlogout .bash_login .profile .login; do
    [ ! -e "$home/$name" ] && [ ! -L "$home/$name" ] || fail "$name remains after cleanup"
  done
  remaining=$(find "$fish_dir" -print | LC_ALL=C sort)
  [ "$remaining" = "$fish_dir
$fish_dir/conf.d
$fish_dir/conf.d/00-marksharc.fish" ] || fail "unexpected entries in clean Fish configuration: $remaining"
}

verify_legacy_restored() {
  original=$work/$pass/original
  for name in $legacy_dotfiles; do
    cmp -s "$original/$name" "$home/$name" || fail "$name was not restored"
  done
  [ -L "$home/.login" ] && [ "$(readlink "$home/.login")" = .profile ] || fail ".login symlink was not restored"
  diff -r "$original/.config/fish" "$fish_dir" || fail "Fish configuration was not restored"
}

# exercise PASS: install (the way PASS says), start shells, uninstall. Sets pass and home.
exercise() {
  pass=$1
  home=$work/$pass/home
  mkdir -p "$home" "$work/$pass/cwd"
  case $pass in
    checkout)
      step "install into a fresh HOME from a checkout"
      fw=$checkout
      clean_env sh "$checkout/install.sh" --no-plugins > "$work/install.log" 2>&1 || { cat "$work/install.log" >&2; fail "install.sh failed"; }
      ;;
    clone)
      step "install into a fresh HOME from a piped script"
      fw=$home/.local/share/marksharc
      # The installer is piped in and run from a directory that is not a checkout.
      (cd "$work/$pass/cwd" && clean_env MARKSHARC_REPO="$checkout" sh -s -- --no-plugins < "$checkout/install.sh") > "$work/install.log" 2>&1 || { cat "$work/install.log" >&2; fail "piped install.sh failed"; }
      [ -d "$fw/.git" ] && [ -r "$fw/core/zsh/zshenv.zsh" ] || fail "the installer did not clone the framework into $fw"
      grep -q '^framework_cloned=1$' "$home/.local/state/marksharc/install.manifest" || fail "the manifest does not record the clone"
      ;;
    legacy)
      step "install into an existing HOME with --clobber"
      fw=$checkout
      seed_legacy_home
      clean_env sh "$checkout/install.sh" --home "$checkout" --no-plugins --clobber > "$work/install.log" 2>&1 || { cat "$work/install.log" >&2; fail "install.sh --clobber failed"; }
      verify_legacy_clean
      ;;
  esac
  [ -f "$home/.zshenv" ] || fail "the stub was not written"
  [ -f "$home/.bashrc" ] && [ -f "$home/.bash_profile" ] || fail "the Bash stubs were not written"
  head -n 1 "$home/.zshenv" | grep -q 'marksharc: managed stub' || fail "the stub has no marksharc header"
  [ -f "$home/.local/state/marksharc/install.manifest" ] || fail "no install manifest"
  [ -f "$home/.config/marksharc/config.conf" ] || fail "the template overlay was not installed"

  step "bootstrap declared packages with a stubbed manager"
  mkdir -p "$work/$pass/stubs"
  cat > "$work/$pass/stubs/brew" <<'EOF'
#!/bin/sh
[ "$1" = bundle ] && [ "$2" = --file ] || exit 1
grep -qx 'brew "fixture-package"' "$3"
EOF
  chmod +x "$work/$pass/stubs/brew"
  printf '%s\n' 'package brew fixture-package' >> "$home/.config/marksharc/config.conf"
  silent "bootstrap" env PATH="$work/$pass/stubs:$PATH" "$fw/bin/marksharc" bootstrap

  step "login shell comes up working"
  # shellcheck disable=SC2016 # the zsh code is single-quoted on purpose
  silent "login shell" zsh -l -c 'print -r -- "$MARKSHARC_SESSION|$MARKSHARC_HOME"; command -v marksharc'
  session=$(sed -n 1p "$out")
  [ "${session%%|*}" = batch ] || fail "login shell: MARKSHARC_SESSION is '${session%%|*}', expected batch"
  [ "${session#*|}" = "$fw" ] || fail "login shell: MARKSHARC_HOME is '${session#*|}', expected $fw"
  [ "$(sed -n 2p "$out")" = "$fw/bin/marksharc" ] || fail "login shell: marksharc resolves to '$(sed -n 2p "$out")'"
  [ -d "$home/.local/state/marksharc/zdot" ] || fail "login shell did not generate the ZDOTDIR"

  step "login Bash comes up working"
  # shellcheck disable=SC2016
  silent "login Bash" /bin/bash -l -c 'printf "%s\n" "$MARKSHARC_HOME"; command -v marksharc'
  [ "$(sed -n 1p "$out")" = "$fw" ] || fail "login Bash did not locate the framework"
  [ "$(sed -n 2p "$out")" = "$fw/bin/marksharc" ] || fail "login Bash did not add marksharc to PATH"

  if command -v fish > /dev/null 2>&1; then
    step "login Fish comes up working"
    # shellcheck disable=SC2016
    silent "login Fish" fish -l -c 'printf "%s\n" "$MARKSHARC_HOME"; command -v marksharc'
    [ "$(sed -n 1p "$out")" = "$fw" ] || fail "login Fish did not locate the framework"
    [ "$(sed -n 2p "$out")" = "$fw/bin/marksharc" ] || fail "login Fish did not add marksharc to PATH"
  else
    step "fish not found; skipping the login Fish check"
  fi

  step "noninteractive Bash hook comes up working"
  # shellcheck disable=SC2016
  silent "Bash hook" env BASH_ENV="$fw/core/bash/env.bash" /bin/bash -c 'printf "%s\n" "$MARKSHARC_HOME"; command -v marksharc'
  [ "$(sed -n 1p "$out")" = "$fw" ] || fail "Bash hook did not locate the framework"
  [ "$(sed -n 2p "$out")" = "$fw/bin/marksharc" ] || fail "Bash hook did not add marksharc to PATH"

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
  if [ "$pass" = legacy ]; then
    verify_legacy_restored
  else
    [ ! -e "$home/.zshenv" ] || fail "the stub is still there after uninstall"
    [ ! -e "$home/.bashrc" ] && [ ! -e "$home/.bash_profile" ] || fail "Bash stubs remain after uninstall"
    [ ! -e "$home/.config/fish/conf.d/00-marksharc.fish" ] || fail "Fish stub remains after uninstall"
  fi
  [ ! -e "$home/.local/state/marksharc/zdot" ] || fail "the generated ZDOTDIR is still there after uninstall"
  [ -f "$home/.config/marksharc/config.conf" ] || fail "uninstall removed the overlay"
  # shellcheck disable=SC2016
  silent "plain shell after uninstall" zsh -c 'print -r -- "$+MARKSHARC_HOME"'
  [ "$(cat "$out")" = 0 ] || fail "marksharc is still active after uninstall"
}

pass=start
exercise checkout
exercise clone
exercise legacy
echo "e2e: ok"
