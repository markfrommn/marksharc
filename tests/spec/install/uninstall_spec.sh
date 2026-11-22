# marksharc uninstall (spec 6.15, design rule 8): restore from the manifest, remove the stub
# and the generated ZDOTDIR, validate everything before the first deletion. Each example
# installs into its own temporary HOME first.
Describe 'marksharc uninstall'
  uninstall() {
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb SHELL=/bin/zsh XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      "$FW/bin/marksharc" uninstall "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
  }
  # setup: install a fake framework over regular dotfiles and a symlink.
  setup() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    for n in .zshrc .zprofile .zlogin .zlogout; do printf 'original %s\n' "$n" > "$HOME/$n"; done
    chmod 600 "$HOME/.zshrc"
    if [ -n "$SETUP_LINK" ]; then
      mkdir -p "$TEST_ROOT/target dir"
      printf 'linked\n' > "$TEST_ROOT/target dir/zshenv"
      ln -s "$TEST_ROOT/target dir/zshenv" "$HOME/.zshenv"
    else
      printf 'foreign env\n' > "$HOME/.zshenv"
    fi
    inst --home "$FW" || { cat "$TEST_ROOT/err"; return 1; }
    mkdir -p "$XDG_STATE_HOME/marksharc/zdot" "$XDG_CACHE_HOME/marksharc/somehost"
    : > "$XDG_STATE_HOME/marksharc/zdot/.zshrc"
    : > "$XDG_CACHE_HOME/marksharc/somehost/cached"
  }

  restore_case() {
    SETUP_LINK=1 setup || return 1
    uninstall || { cat "$TEST_ROOT/err"; return 3; }
    [ -L "$HOME/.zshenv" ] && [ "$(readlink "$HOME/.zshenv")" = "$TEST_ROOT/target dir/zshenv" ] || { echo "zshenv not restored as a symlink"; return 4; }
    for n in .zshrc .zprofile .zlogin .zlogout; do [ "$(cat "$HOME/$n")" = "original $n" ] || { echo "$n not restored"; return 5; }; done
    [ "$(file_mode "$HOME/.zshrc")" = 600 ] || return 6
    [ -e "$XDG_STATE_HOME/marksharc/zdot" ] && { echo "zdot kept"; return 7; }
    # framework, overlay, cache and the backup are kept
    [ -d "$FW" ] && [ -f "$XDG_CONFIG_HOME/marksharc/config.conf" ] && [ -d "$XDG_CACHE_HOME/marksharc/somehost" ] || return 8
    [ -f "$XDG_STATE_HOME/marksharc/install.manifest" ] && return 9
    for want in "$FW" "$XDG_CONFIG_HOME/marksharc" "$XDG_CACHE_HOME/marksharc" 'rm -rf'; do
      grep -q -F "$want" "$TEST_ROOT/out" || { echo "no mention of $want"; cat "$TEST_ROOT/out"; return 10; }
    done
    # a second run has nothing to do
    uninstall; [ $? -eq 1 ] || return 11
    grep -q 'nothing to uninstall' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 12; }
  }
  It 'restores regular and symlinked dotfiles, removes the stub and zdot, and keeps the rest'
    When run restore_case
    The status should be success
  End

  no_original_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    inst --home "$FW" || return 1
    [ -f "$HOME/.zshenv" ] || return 2
    uninstall || { cat "$TEST_ROOT/err"; return 3; }
    [ -e "$HOME/.zshenv" ] && return 4
    return 0
  }
  It 'removes the stub when there was no original ~/.zshenv'
    When run no_original_case
    The status should be success
  End

  conflict_case() {
    setup || return 1
    printf 'new rc\n' > "$HOME/.zshrc"
    before=$(snapshot)
    uninstall; [ $? -eq 1 ] || return 2
    grep -q '.zshrc' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    [ "$(snapshot)" = "$before" ] || return 4
    head -n 1 "$HOME/.zshenv" | grep -q 'marksharc: managed stub' || return 5
    [ -f "$XDG_STATE_HOME/marksharc/install.manifest" ] || return 6
    # a replaced ~/.zshenv that is no longer ours counts as a conflict when the original is to return
    rm "$HOME/.zshrc"; printf 'someone else\n' > "$HOME/.zshenv"
    before=$(snapshot)
    uninstall; [ $? -eq 1 ] || return 7
    [ "$(snapshot)" = "$before" ] && [ "$(cat "$HOME/.zshenv")" = 'someone else' ]
  }
  It 'fails before changing anything when a restore target is occupied'
    When run conflict_case
    The status should be success
  End

  missing_backup_case() {
    setup || return 1
    rm "$(mf backup)/.zshlogin" 2> /dev/null || rm "$(mf backup)/.zlogin"
    before=$(snapshot)
    uninstall; [ $? -eq 1 ] || return 2
    grep -q 'zlogin' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    [ "$(snapshot)" = "$before" ] || return 4
    # no manifest at all
    rm "$XDG_STATE_HOME/marksharc/install.manifest"
    uninstall; [ $? -eq 1 ] || return 5
    grep -q 'install.manifest' "$TEST_ROOT/err"
  }
  It 'fails before changing anything when the backup or the manifest is missing'
    When run missing_backup_case
    The status should be success
  End

  purge_case() {
    make_origin
    mkdir -p "$TEST_ROOT/elsewhere"
    cp "$MARKSHARC_ROOT/install.sh" "$TEST_ROOT/elsewhere/install.sh"
    printf 'original\n' > "$HOME/.zshrc"
    INST_SCRIPT="$TEST_ROOT/elsewhere/install.sh"
    MARKSHARC_REPO="file://$TEST_ROOT/origin.git" inst || { cat "$TEST_ROOT/err"; return 1; }
    FW=$XDG_DATA_HOME/marksharc
    mkdir -p "$XDG_STATE_HOME/marksharc/zdot" "$XDG_CACHE_HOME/marksharc/somehost"
    # Without --yes and without a terminal, nothing happens at all.
    before=$(snapshot)
    uninstall --purge; [ $? -eq 1 ] || return 2
    grep -q -- '--yes' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    [ "$(snapshot)" = "$before" ] || return 4
    # --purge --yes, run from the clone it deletes
    uninstall --purge --yes || { cat "$TEST_ROOT/err"; return 5; }
    [ "$(cat "$HOME/.zshrc")" = original ] || return 6
    [ -e "$FW" ] && { echo "clone kept"; return 7; }
    [ -e "$XDG_CACHE_HOME/marksharc" ] && { echo "cache kept"; return 8; }
    [ -e "$XDG_STATE_HOME/marksharc" ] && { echo "state kept"; return 9; }
    # the overlay is never removed
    [ -f "$XDG_CONFIG_HOME/marksharc/config.conf" ] || return 10
    [ -e "$HOME/.zshenv" ] && return 11
    return 0
  }
  It 'purges the cache, the state and an installer-made clone only after confirmation, never the overlay'
    When run purge_case
    The status should be success
  End

  purge_checkout_case() {
    setup || return 1
    uninstall --purge --yes || { cat "$TEST_ROOT/err"; return 2; }
    [ -d "$FW" ] && [ -f "$FW/core/zsh/zshenv.zsh" ] || { echo "checkout deleted"; return 3; }
    [ -f "$XDG_CONFIG_HOME/marksharc/config.conf" ] || return 4
    [ -e "$XDG_CACHE_HOME/marksharc" ] || [ -e "$XDG_STATE_HOME/marksharc" ] && return 5
    grep -q 'not created by the installer' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 6; }
    return 0
  }
  It 'never deletes a --home checkout, even with --purge'
    When run purge_checkout_case
    The status should be success
  End

  purge_guard_case() {
    setup || return 1
    # a manifest that points a purge target somewhere else is refused before anything changes
    sed "s|^cache=.*|cache=$HOME|" "$XDG_STATE_HOME/marksharc/install.manifest" > "$TEST_ROOT/m" && cp "$TEST_ROOT/m" "$XDG_STATE_HOME/marksharc/install.manifest"
    before=$(snapshot)
    uninstall --purge --yes; [ $? -eq 1 ] || return 2
    [ "$(snapshot)" = "$before" ] || return 3
    # an overlay inside a purge target is refused too
    inst --home "$FW" || return 4
    sed "s|^cache=.*|cache=$XDG_CACHE_HOME/marksharc|; s|^config=.*|config=$XDG_CACHE_HOME/marksharc/overlay|" "$XDG_STATE_HOME/marksharc/install.manifest" > "$TEST_ROOT/m" && cp "$TEST_ROOT/m" "$XDG_STATE_HOME/marksharc/install.manifest"
    mkdir -p "$XDG_CACHE_HOME/marksharc/overlay"
    before=$(snapshot)
    uninstall --purge --yes; [ $? -eq 1 ] || return 5
    grep -q 'overlay' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 6; }
    [ "$(snapshot)" = "$before" ]
  }
  It 'refuses purge targets that are not marksharc directories or that hold the overlay'
    When run purge_guard_case
    The status should be success
  End

  prompt_case() {
    [ -n "$PYTHON" ] || return 0
    setup || return 1
    pty() {
      PTY_INPUT=$1 "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty env -i HOME="$HOME" PATH="$PATH" TERM=dumb \
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
        "$FW/bin/marksharc" uninstall --purge > "$TEST_ROOT/out" 2>&1
    }
    before=$(snapshot)
    pty 'no
'; [ $? -eq 1 ] || { cat "$TEST_ROOT/out"; return 2; }
    grep -q 'yes' "$TEST_ROOT/out" || return 3
    [ "$(snapshot)" = "$before" ] || return 4
    pty 'yes
' || { cat "$TEST_ROOT/out"; return 5; }
    [ -e "$XDG_STATE_HOME/marksharc" ] && return 6
    [ "$(cat "$HOME/.zshrc")" = 'original .zshrc' ]
  }
  It 'asks on a terminal and purges only after "yes"'
    When run prompt_case
    The status should be success
  End

  roundtrip_case() {
    setup || return 1
    uninstall || { cat "$TEST_ROOT/err"; return 2; }
    inst --home "$FW" || { cat "$TEST_ROOT/err"; return 3; }
    head -n 1 "$HOME/.zshenv" | grep -q 'marksharc: managed stub' || return 4
    [ ! -e "$HOME/.zshrc" ] || return 5
    [ "$(cat "$(backup_dir)/.zshrc")" = 'original .zshrc' ] || return 6
    [ "$(cat "$(backup_dir)/.zshenv")" = 'foreign env' ] || return 7
    uninstall || return 8
    [ "$(cat "$HOME/.zshenv")" = 'foreign env' ] && [ "$(cat "$HOME/.zshrc")" = 'original .zshrc' ]
  }
  It 'installs again after an uninstall and restores the originals once more'
    When run roundtrip_case
    The status should be success
  End
End
