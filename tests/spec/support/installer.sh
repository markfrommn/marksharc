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
# INST_XDG=default exports the four XDG variables at their defaults under HOME; INST_XDG=unset
# removes them; otherwise the sandbox values (non-default, inside HOME) apply.
inst() {
  case ${INST_XDG:-sandbox} in
    default)
      env SHELL=${INST_SHELL:-/bin/zsh} XDG_CONFIG_HOME="$HOME/.config" XDG_DATA_HOME="$HOME/.local/share" \
        XDG_STATE_HOME="$HOME/.local/state" XDG_CACHE_HOME="$HOME/.cache" \
        sh "${INST_SCRIPT:-$MARKSHARC_ROOT/install.sh}" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null ;;
    unset)
      env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME SHELL=${INST_SHELL:-/bin/zsh} \
        sh "${INST_SCRIPT:-$MARKSHARC_ROOT/install.sh}" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null ;;
    *)
      SHELL=${INST_SHELL:-/bin/zsh} sh "${INST_SCRIPT:-$MARKSHARC_ROOT/install.sh}" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null ;;
  esac
}
# snapshot: the sorted names under the sandbox HOME.
snapshot() { (cd "$TEST_ROOT" && find home -print | sort); }
# mf KEY: a value from the install manifest (MF_FILE overrides its location).
mf() { awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "${MF_FILE:-$XDG_STATE_HOME/marksharc/install.manifest}"; }
backup_dir() { mf backup; }
# make_origin: a bare repository at $TEST_ROOT/origin.git holding a fake checkout.
make_origin() {
  fake_fw "$TEST_ROOT/seed"
  "$REAL_GIT" init -q -b main "$TEST_ROOT/seed"
  "$REAL_GIT" -C "$TEST_ROOT/seed" add -A
  "$REAL_GIT" -C "$TEST_ROOT/seed" -c user.email=f@example.invalid -c user.name=Fixture commit -qm seed
  "$REAL_GIT" clone -q --bare "$TEST_ROOT/seed" "$TEST_ROOT/origin.git"
}
