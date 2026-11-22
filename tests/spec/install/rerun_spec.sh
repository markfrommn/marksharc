# Re-runs, edited stubs, XDG variables and trailing slashes (review fixes for DEV-44).
Describe 'install.sh re-runs and environment'
  uninstall() {
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb SHELL=/bin/zsh XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      "$FW/bin/marksharc" uninstall "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
  }

  # A re-run that finds backups in the manifest but no stub of ours must not rebuild the manifest.
  stale_case() {
    # $1 is a command that damages the stub: delete or replace
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    printf 'original rc\n' > "$HOME/.zshrc"
    printf 'original env\n' > "$HOME/.zshenv"
    inst --home "$FW" || { cat "$TEST_ROOT/err"; return 1; }
    first_backup=$(mf backup)
    case $1 in
      delete) rm "$HOME/.zshenv" ;;
      replace) printf 'foreign\n' > "$HOME/.zshenv" ;;
    esac
    before=$(snapshot)
    cp "$XDG_STATE_HOME/marksharc/install.manifest" "$TEST_ROOT/manifest.before"
    inst --home "$FW"; [ $? -eq 1 ] || return 2
    grep -q "$first_backup" "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    grep -q 'marksharc uninstall' "$TEST_ROOT/err" || return 4
    [ "$(snapshot)" = "$before" ] || return 5
    cmp -s "$TEST_ROOT/manifest.before" "$XDG_STATE_HOME/marksharc/install.manifest" || return 6
    # Following the advice restores everything, including the file the stub replaced.
    if [ "$1" = replace ]; then mv "$HOME/.zshenv" "$TEST_ROOT/aside"; fi
    uninstall --purge --yes || { cat "$TEST_ROOT/err"; return 7; }
    [ "$(cat "$HOME/.zshrc")" = 'original rc' ] && [ "$(cat "$HOME/.zshenv")" = 'original env' ] || return 8
  }
  It 'refuses to rebuild the manifest when the stub was deleted, naming the earlier backup'
    When run stale_case delete
    The status should be success
  End
  It 'refuses to rebuild the manifest when the stub was replaced, naming the earlier backup'
    When run stale_case replace
    The status should be success
  End

  no_backup_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    inst --home "$FW" || return 1
    rm "$HOME/.zshenv"
    inst --home "$FW" || { cat "$TEST_ROOT/err"; return 2; }
    head -n 1 "$HOME/.zshenv" | grep -q 'marksharc: managed stub'
  }
  It 'reinstalls over a deleted stub when nothing was backed up'
    When run no_backup_case
    The status should be success
  End

  edited_stub_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    inst --home "$FW" || return 1
    printf '. "$HOME/.cargo/env"\n' >> "$HOME/.zshenv"
    inst --home "$FW" || { cat "$TEST_ROOT/err"; return 2; }
    # the stub is canonical again and the edited text is kept, with its location printed
    grep -q cargo "$HOME/.zshenv" && return 3
    saved=$(ls "$XDG_STATE_HOME"/marksharc/replaced/* 2> /dev/null | head -n 1)
    [ -n "$saved" ] && grep -q 'cargo/env' "$saved" || { echo "no saved copy"; return 4; }
    grep -q -F "$saved" "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 5; }
    # an unedited re-run saves nothing new and changes nothing
    inst --home "$FW" || return 6
    [ "$(ls "$XDG_STATE_HOME"/marksharc/replaced | wc -l | tr -d ' ')" = 1 ] || return 7
    grep -q 'already installed' "$TEST_ROOT/out" || return 8
    # repointing an unedited stub saves nothing either
    fake_fw "$TEST_ROOT/fw2"
    inst --home "$TEST_ROOT/fw2" || return 9
    [ "$(ls "$XDG_STATE_HOME"/marksharc/replaced | wc -l | tr -d ' ')" = 1 ]
  }
  It 'keeps a copy of a hand-edited stub before rewriting it and says where'
    When run edited_stub_case
    The status should be success
  End

  edited_uninstall_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    printf 'original env\n' > "$HOME/.zshenv"
    inst --home "$FW" || return 1
    printf '. "$HOME/.cargo/env"\n' >> "$HOME/.zshenv"
    uninstall || { cat "$TEST_ROOT/err"; return 2; }
    [ "$(cat "$HOME/.zshenv")" = 'original env' ] || return 3
    grep -q 'cargo/env' "$HOME/.zshenv.marksharc-removed" || { ls -A "$HOME"; return 4; }
    grep -q '.zshenv.marksharc-removed' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 5; }
    # an untouched stub leaves no such file
    inst --home "$FW" || return 6
    rm "$HOME/.zshenv.marksharc-removed"
    uninstall --purge --yes || return 7
    [ ! -e "$HOME/.zshenv.marksharc-removed" ]
  }
  It 'uninstall saves hand-added stub lines next to the restored file'
    When run edited_uninstall_case
    The status should be success
  End

  xdg_case() {
    fake_fw "$TEST_ROOT/fw"
    # default XDG values: no MARKSHARC_CONFIG and no warning
    INST_XDG=default inst --home "$TEST_ROOT/fw" || return 1
    grep -q '^MARKSHARC_CONFIG' "$HOME/.zshenv" && return 2
    grep -qi 'warning' "$TEST_ROOT/out" && return 3
    rm -rf "$HOME/.zshenv" "$HOME/.config" "$HOME/.local"
    # XDG unset behaves the same
    INST_XDG=unset inst --home "$TEST_ROOT/fw" || return 4
    grep -q '^MARKSHARC_CONFIG' "$HOME/.zshenv" && return 5
    [ -f "$HOME/.config/marksharc/config.conf" ] && [ -f "$HOME/.local/state/marksharc/install.manifest" ] || return 6
    rm -rf "$HOME/.zshenv" "$HOME/.config" "$HOME/.local"
    # a non-default XDG_CONFIG_HOME is written into the stub, so new shells find the overlay
    XDG_CONFIG_HOME=$TEST_ROOT/xdgcfg inst --home "$TEST_ROOT/fw" || return 7
    got=$(env -i HOME="$HOME" PATH="$PATH" zsh -fc 'source "$HOME/.zshenv"; print -r -- "$MARKSHARC_CONFIG"')
    [ "$got" = "$TEST_ROOT/xdgcfg/marksharc" ] || { echo "got $got"; return 8; }
    # the other non-default XDG variables cannot be carried: the installer warns, naming each
    rm -rf "$HOME/.zshenv" "$TEST_ROOT/xdgcfg" "$HOME/.local"
    env XDG_CONFIG_HOME="$HOME/.config" XDG_STATE_HOME="$TEST_ROOT/st" XDG_CACHE_HOME="$TEST_ROOT/ca" XDG_DATA_HOME="$TEST_ROOT/da" SHELL=/bin/zsh \
      sh "$MARKSHARC_ROOT/install.sh" --home "$TEST_ROOT/fw" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null || return 9
    for v in XDG_STATE_HOME XDG_CACHE_HOME XDG_DATA_HOME; do
      grep -q "warning:.*$v" "$TEST_ROOT/out" || { echo "no warning for $v"; cat "$TEST_ROOT/out"; return 10; }
    done
    grep -q 'warning:.*XDG_CONFIG_HOME' "$TEST_ROOT/out" && return 11
    return 0
  }
  It 'decides MARKSHARC_CONFIG against ~/.config/marksharc and warns about other XDG variables'
    When run xdg_case
    The status should be success
  End

  uninstall_hint_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    uninstall; [ $? -eq 1 ] || return 1
    grep -q 'XDG_STATE_HOME' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
  }
  It 'names XDG_STATE_HOME when uninstall finds no manifest'
    When run uninstall_hint_case
    The status should be success
  End

  slash_case() {
    fake_fw "$TEST_ROOT/fw"
    mkdir -p "$TEST_ROOT/ov"
    MARKSHARC_CONFIG="$TEST_ROOT/cfg/marksharc/" inst --home "$TEST_ROOT/fw" --overlay "$TEST_ROOT/ov" || { cat "$TEST_ROOT/err"; return 1; }
    [ -L "$TEST_ROOT/cfg/marksharc" ] || { ls -lA "$TEST_ROOT/cfg"; return 2; }
    [ "$(ls -A "$TEST_ROOT/ov")" = '' ] || return 3
    grep -q "^MARKSHARC_CONFIG='$TEST_ROOT/cfg/marksharc'\$" "$HOME/.zshenv" || { cat "$HOME/.zshenv"; return 4; }
    [ "$(mf config)" = "$TEST_ROOT/cfg/marksharc" ]
  }
  It 'strips trailing slashes from MARKSHARC_CONFIG'
    When run slash_case
    The status should be success
  End

  other_checkout_case() {
    # The command runs against its own checkout, not the one the stub points at.
    fake_fw "$TEST_ROOT/a"; fake_fw "$TEST_ROOT/b"
    printf '1.0-a\n' > "$TEST_ROOT/a/VERSION"
    printf '2.0-b\n' > "$TEST_ROOT/b/VERSION"
    inst --home "$TEST_ROOT/a" || return 1
    out=$(env -i HOME="$HOME" PATH="$PATH" XDG_STATE_HOME="$XDG_STATE_HOME" "$TEST_ROOT/b/bin/marksharc" version 2>&1)
    [ "$out" = 'marksharc 2.0-b' ] || { echo "got: $out"; return 2; }
    out=$(env -i HOME="$HOME" PATH="$PATH" "$TEST_ROOT/b/core/cli/version" 2>&1)
    [ "$out" = 'marksharc 2.0-b' ] || { echo "got: $out"; return 3; }
  }
  It 'runs each checkout bin/marksharc against its own framework, whatever the stub says'
    When run other_checkout_case
    The status should be success
  End
End
