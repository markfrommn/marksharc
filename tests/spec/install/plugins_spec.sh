# install.sh fetches the pinned plugins (spec 6.8, 6.15) as an explicit install step, from
# local repositories only: startup never fetches them.
Describe 'install.sh plugin pins'
  # plugin_fw DIR: fake_fw plus the plugin functions and a module whose registry pins a
  # local repository; PLUG_SHA names the pinned commit.
  plugin_fw() {
    fake_fw "$1"
    "$REAL_GIT" init -q -b main "$TEST_ROOT/plug"
    printf 'typeset -g demo_loaded=1\n' > "$TEST_ROOT/plug/demo.plugin.zsh"
    "$REAL_GIT" -C "$TEST_ROOT/plug" add -A
    "$REAL_GIT" -C "$TEST_ROOT/plug" -c user.email=f@example.invalid -c user.name=Fixture commit -qm one
    PLUG_SHA=$("$REAL_GIT" -C "$TEST_ROOT/plug" rev-parse HEAD)
    # A later commit: the clone must be detached at the pin, not at the branch tip.
    printf '# later\n' >> "$TEST_ROOT/plug/demo.plugin.zsh"
    "$REAL_GIT" -C "$TEST_ROOT/plug" -c user.email=f@example.invalid -c user.name=Fixture commit -qam two
    mkdir -p "$1/modules/completion-fzf-tab/functions/zsh" "$1/modules/demo"
    cp "$MARKSHARC_ROOT"/modules/completion-fzf-tab/functions/zsh/* "$1/modules/completion-fzf-tab/functions/zsh/"
    printf 'plugin demo %s %s shell zsh kind source\n' "$TEST_ROOT/plug" "$PLUG_SHA" > "$1/modules/demo/zsh.plugins"
  }

  fetch_case() {
    plugin_fw "$TEST_ROOT/fw"
    inst --home "$TEST_ROOT/fw" || { cat "$TEST_ROOT/err"; return 1; }
    clone=$XDG_CACHE_HOME/marksharc/plugins/demo@$PLUG_SHA
    [ -d "$clone/.git" ] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    [ "$("$REAL_GIT" -C "$clone" rev-parse HEAD)" = "$PLUG_SHA" ] || return 3
    grep -q 'plugins: fetched' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 4; }
  }
  It 'clones every registry pin into the cache and checks out the pinned commit'
    When run fetch_case
    The status should be success
  End

  skip_case() {
    plugin_fw "$TEST_ROOT/fw"
    inst --home "$TEST_ROOT/fw" --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    [ ! -e "$XDG_CACHE_HOME/marksharc/plugins" ] || return 2
    grep -q 'marksharc update' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 3; }
  }
  It 'skips the fetch with --no-plugins and names the later command'
    When run skip_case
    The status should be success
  End

  dry_case() {
    plugin_fw "$TEST_ROOT/fw"
    inst --home "$TEST_ROOT/fw" --dry-run || { cat "$TEST_ROOT/err"; return 1; }
    [ ! -e "$XDG_CACHE_HOME/marksharc/plugins" ] || return 2
    grep -q 'would fetch the pinned plugins' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 3; }
  }
  It 'only reports the fetch in a dry run'
    When run dry_case
    The status should be success
  End

  dry_clone_case() {
    # The piped installer (curl | sh) clones the framework, so a dry run cannot read its
    # registries yet; it still names the plugin step.
    make_origin
    mkdir -p "$TEST_ROOT/elsewhere"
    cp "$MARKSHARC_ROOT/install.sh" "$TEST_ROOT/elsewhere/install.sh"
    MARKSHARC_REPO="$TEST_ROOT/origin.git" INST_SCRIPT="$TEST_ROOT/elsewhere/install.sh" inst --dry-run || { cat "$TEST_ROOT/err"; return 1; }
    grep -q 'would run: git clone' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 2; }
    grep -q 'would fetch the pinned plugins' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 3; }
  }
  It 'names the plugin fetch in a dry run of the cloning installer'
    When run dry_clone_case
    The status should be success
  End

  offline_case() {
    plugin_fw "$TEST_ROOT/fw"
    printf 'plugin demo %s %s shell zsh kind source\n' "$TEST_ROOT/no-such-repo" "$PLUG_SHA" > "$TEST_ROOT/fw/modules/demo/zsh.plugins"
    inst --home "$TEST_ROOT/fw" || { cat "$TEST_ROOT/err"; return 1; }
    head -n 1 "$HOME/.zshenv" | grep -q '^# marksharc: managed stub' || return 2
    grep -q 'warning: could not fetch the pinned plugins' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 3; }
  }
  It 'still installs when a pin cannot be fetched, and says how to retry'
    When run offline_case
    The status should be success
  End
End
