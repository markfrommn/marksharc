# shellcheck shell=sh
# Helpers for the installer and uninstall specs (POSIX; loaded by spec_helper.sh).

# fake_fw DIR: the smallest tree install.sh accepts as a checkout, plus the real CLI and
# overlay template, so marksharc uninstall can run from it.
fake_fw() {
  mkdir -p "$1/core/zsh" "$1/core/cli"
  : > "$1/core/zsh/zshenv.zsh"
  cp -R "$MARKSHARC_ROOT/bin" "$1/bin"
  cp "$MARKSHARC_ROOT"/core/cli/* "$1/core/cli/"
  cp "$MARKSHARC_ROOT/VERSION" "$1/VERSION"
  cp -R "$MARKSHARC_ROOT/templates" "$1/templates"
}
# inst ARGS...: run the installer in the sandbox; stdout/stderr land in $TEST_ROOT/out and err.
# INST_SCRIPT and INST_SHELL override the script and the SHELL it sees.
inst() {
  SHELL=${INST_SHELL:-/bin/zsh} sh "${INST_SCRIPT:-$MARKSHARC_ROOT/install.sh}" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
}
# snapshot: the sorted names under the sandbox HOME.
snapshot() { (cd "$TEST_ROOT" && find home -print | sort); }
# mf KEY: a value from the install manifest.
mf() { awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$XDG_STATE_HOME/marksharc/install.manifest"; }
backup_dir() { mf backup; }
# make_origin: a bare repository at $TEST_ROOT/origin.git holding a fake checkout.
make_origin() {
  fake_fw "$TEST_ROOT/seed"
  "$REAL_GIT" init -q -b main "$TEST_ROOT/seed"
  "$REAL_GIT" -C "$TEST_ROOT/seed" add -A
  "$REAL_GIT" -C "$TEST_ROOT/seed" -c user.email=f@example.invalid -c user.name=Fixture commit -qm seed
  "$REAL_GIT" clone -q --bare "$TEST_ROOT/seed" "$TEST_ROOT/origin.git"
}
