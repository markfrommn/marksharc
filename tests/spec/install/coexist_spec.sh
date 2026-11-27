# install.sh --coexist and marksharc uninstall in coexist mode (plan L4 / DEV-63).
Describe 'install.sh --coexist'
  installer="$MARKSHARC_ROOT/install.sh"

  uninstall() {
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb SHELL=/bin/zsh XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      "$FW/bin/marksharc" uninstall "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
  }

  existing_files_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    mkdir -p "$FW/core/fish" "$XDG_CONFIG_HOME/fish"
    : > "$FW/core/fish/marksharc.fish"
    printf 'export USER_ENV=1' > "$HOME/.zshenv"
    printf 'alias mine="echo hi"\n' > "$HOME/.zshrc"
    chmod 600 "$HOME/.zshrc"
    printf 'profile line\n' > "$HOME/.zprofile"
    printf 'login line\n' > "$HOME/.zlogin"
    printf 'logout line\n' > "$HOME/.zlogout"
    printf 'bash rc\n' > "$HOME/.bashrc"
    printf 'bash profile\n' > "$HOME/.bash_profile"
    printf 'posix profile\n' > "$HOME/.profile"
    printf 'fish config\n' > "$XDG_CONFIG_HOME/fish/config.fish"

    inst --home "$FW" --coexist --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    [ ! -s "$TEST_ROOT/err" ] || { cat "$TEST_ROOT/err"; return 2; }
    # Existing startup files are kept in place, with no backup directory created.
    [ ! -e "$XDG_STATE_HOME/marksharc/backup" ] || return 3
    [ "$(cat "$HOME/.zprofile")" = 'profile line' ] || return 4
    [ "$(cat "$HOME/.zlogin")" = 'login line' ] || return 5
    [ "$(cat "$HOME/.zlogout")" = 'logout line' ] || return 6
    [ "$(cat "$HOME/.bashrc")" = 'bash rc' ] || return 7
    [ "$(cat "$HOME/.bash_profile")" = 'bash profile' ] || return 8
    [ "$(cat "$HOME/.profile")" = 'posix profile' ] || return 9
    [ "$(cat "$XDG_CONFIG_HOME/fish/config.fish")" = 'fish config' ] || return 10
    [ ! -e "$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish" ] || return 11
    # Exactly one coexist source line was added to ~/.zshenv and ~/.zshrc, preserving content & mode.
    [ "$(grep -c '# marksharc: coexist' "$HOME/.zshenv")" = 1 ] || { cat "$HOME/.zshenv"; return 12; }
    [ "$(grep -c '# marksharc: coexist' "$HOME/.zshrc")" = 1 ] || { cat "$HOME/.zshrc"; return 13; }
    [ "$(sed -n '1p' "$HOME/.zshenv")" = 'export USER_ENV=1' ] || { cat "$HOME/.zshenv"; return 14; }
    [ "$(sed -n '1p' "$HOME/.zshrc")" = 'alias mine="echo hi"' ] || { cat "$HOME/.zshrc"; return 15; }
    [ "$(file_mode "$HOME/.zshrc")" = 600 ] || return 16
    # Generated coexist stubs and dotfiles parse cleanly under zsh.
    zsh -n "$HOME/.zshenv" && zsh -n "$HOME/.zshrc" &&
      zsh -n "$XDG_STATE_HOME/marksharc/coexist/zshenv.zsh" &&
      zsh -n "$XDG_STATE_HOME/marksharc/coexist/zshrc.zsh" || return 17
    [ "$(mf mode)" = coexist ] || return 18
    [ "$(mf coexist_zshenv_created)" = 0 ] && [ "$(mf coexist_zshrc_created)" = 0 ] || return 19

    # Uninstall removes only the coexist lines and leaves existing files intact, including later edits.
    printf 'export ADDED_LATER=2\n' >> "$HOME/.zshrc"
    uninstall || { cat "$TEST_ROOT/err"; return 20; }
    grep -Fq '# marksharc: coexist' "$HOME/.zshenv" && return 21
    grep -Fq '# marksharc: coexist' "$HOME/.zshrc" && return 22
    [ "$(cat "$HOME/.zshenv")" = 'export USER_ENV=1' ] || { cat "$HOME/.zshenv"; return 23; }
    grep -Fq 'alias mine="echo hi"' "$HOME/.zshrc" && grep -Fq 'export ADDED_LATER=2' "$HOME/.zshrc" || { cat "$HOME/.zshrc"; return 24; }
    [ "$(file_mode "$HOME/.zshrc")" = 600 ] || return 25
    [ ! -e "$XDG_STATE_HOME/marksharc/coexist" ] || return 26
    [ -f "$XDG_CONFIG_HOME/marksharc/config.conf" ] || return 27
    [ ! -e "$XDG_STATE_HOME/marksharc/install.manifest" ]
  }
  It 'adds one source line to existing ~/.zshenv and ~/.zshrc without disturbing other dotfiles, and uninstalls cleanly'
    When run existing_files_case
    The status should be success
  End

  created_files_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    inst --home "$FW" --coexist --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    [ -f "$HOME/.zshenv" ] && [ -f "$HOME/.zshrc" ] || return 2
    [ "$(mf coexist_zshenv_created)" = 1 ] && [ "$(mf coexist_zshrc_created)" = 1 ] || return 3
    # Re-run preserves created=1.
    inst --home "$FW" --coexist --no-plugins || return 4
    [ "$(mf coexist_zshenv_created)" = 1 ] && [ "$(mf coexist_zshrc_created)" = 1 ] || return 5
    # User adds a line to ~/.zshrc after install; ~/.zshenv stays untouched.
    printf 'export KEEP_ME=yes\n' >> "$HOME/.zshrc"
    uninstall || { cat "$TEST_ROOT/err"; return 6; }
    # Empty created file is removed; created file with user additions is kept without the coexist line.
    [ ! -e "$HOME/.zshenv" ] || return 7
    [ -f "$HOME/.zshrc" ] || return 8
    [ "$(cat "$HOME/.zshrc")" = 'export KEEP_ME=yes' ] || { cat "$HOME/.zshrc"; return 9; }
  }
  It 'removes empty dotfiles it created on uninstall while keeping files that gained user lines'
    When run created_files_case
    The status should be success
  End

  symlink_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    mkdir -p "$TEST_ROOT/dotfiles"
    printf 'linked env\n' > "$TEST_ROOT/dotfiles/zshenv"
    printf 'linked rc\n' > "$HOME/real-zshrc"
    ln -s "$TEST_ROOT/dotfiles/zshenv" "$HOME/.zshenv"
    ln -s real-zshrc "$HOME/.zshrc"

    inst --home "$FW" --coexist --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    [ -L "$HOME/.zshenv" ] && [ "$(readlink "$HOME/.zshenv")" = "$TEST_ROOT/dotfiles/zshenv" ] || return 2
    [ -L "$HOME/.zshrc" ] && [ "$(readlink "$HOME/.zshrc")" = real-zshrc ] || return 3
    grep -Fq 'linked env' "$TEST_ROOT/dotfiles/zshenv" && grep -Fq '# marksharc: coexist' "$TEST_ROOT/dotfiles/zshenv" || return 4
    grep -Fq 'linked rc' "$HOME/real-zshrc" && grep -Fq '# marksharc: coexist' "$HOME/real-zshrc" || return 5

    uninstall || { cat "$TEST_ROOT/err"; return 6; }
    [ -L "$HOME/.zshenv" ] && [ -L "$HOME/.zshrc" ] || return 7
    [ "$(cat "$TEST_ROOT/dotfiles/zshenv")" = 'linked env' ] || return 8
    [ "$(cat "$HOME/real-zshrc")" = 'linked rc' ]
  }
  It 'preserves symlinked ~/.zshenv and ~/.zshrc on coexist install and uninstall'
    When run symlink_case
    The status should be success
  End

  rerun_and_repoint_case() {
    FW=$TEST_ROOT/fw1
    fake_fw "$FW"
    printf 'user rc\n' > "$HOME/.zshrc"
    inst --home "$FW" --coexist --no-plugins || return 1
    cp "$HOME/.zshenv" "$TEST_ROOT/zshenv.1"
    cp "$HOME/.zshrc" "$TEST_ROOT/zshrc.1"
    cp "$XDG_STATE_HOME/marksharc/install.manifest" "$TEST_ROOT/manifest.1"

    inst --home "$FW" --coexist --no-plugins || { cat "$TEST_ROOT/err"; return 2; }
    cmp -s "$TEST_ROOT/zshenv.1" "$HOME/.zshenv" || return 3
    cmp -s "$TEST_ROOT/zshrc.1" "$HOME/.zshrc" || return 4
    cmp -s "$TEST_ROOT/manifest.1" "$XDG_STATE_HOME/marksharc/install.manifest" || return 5
    grep -q 'already installed; nothing to change' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 6; }

    # Repointing to another checkout updates the coexist stubs without duplicating lines.
    FW2=$TEST_ROOT/fw2
    fake_fw "$FW2"
    inst --home "$FW2" --coexist --no-plugins || { cat "$TEST_ROOT/err"; return 7; }
    [ "$(grep -c '# marksharc: coexist' "$HOME/.zshenv")" = 1 ] || return 8
    [ "$(grep -c '# marksharc: coexist' "$HOME/.zshrc")" = 1 ] || return 9
    grep -Fq "MARKSHARC_HOME='$FW2'" "$XDG_STATE_HOME/marksharc/coexist/zshenv.zsh" || return 10
    grep -Fq "MARKSHARC_HOME='$FW2'" "$XDG_STATE_HOME/marksharc/coexist/zshrc.zsh" || return 11

    # Hand-edited coexist stub is preserved across re-run and purge.
    printf '# custom coexist edit\n' >> "$XDG_STATE_HOME/marksharc/coexist/zshenv.zsh"
    inst --home "$FW2" --coexist --no-plugins || { cat "$TEST_ROOT/err"; return 12; }
    saved=$(find "$XDG_STATE_HOME/marksharc/replaced" -type f -name 'coexist-zshenv.*' -print)
    [ -n "$saved" ] && grep -Fq '# custom coexist edit' "$saved" || return 13
    FW=$FW2 uninstall --purge --yes || { cat "$TEST_ROOT/err"; return 14; }
    kept=
    for copy in "$HOME"/.zshenv.marksharc-replaced.*; do
      [ -f "$copy" ] || continue
      kept=$copy
      break
    done
    [ -n "$kept" ] && grep -Fq '# custom coexist edit' "$kept" || return 15
    [ "$(cat "$HOME/.zshrc")" = 'user rc' ] && [ ! -e "$XDG_STATE_HOME/marksharc" ]
  }
  It 're-runs idempotently, repoints cleanly, and preserves hand-edited coexist stubs through purge'
    When run rerun_and_repoint_case
    The status should be success
  End

  dry_run_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    printf 'existing rc\n' > "$HOME/.zshrc"
    before=$(snapshot)
    inst --home "$FW" --coexist --dry-run --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    [ "$(snapshot)" = "$before" ] || return 2
    [ "$(cat "$HOME/.zshrc")" = 'existing rc' ] || return 3
    grep -q 'would write the coexist stub' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 4; }
    grep -q 'would add the marksharc coexist line' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 5; }
  }
  It 'previews coexist actions and writes nothing with --dry-run'
    When run dry_run_case
    The status should be success
  End

  conflicts_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    printf 'existing rc\n' > "$HOME/.zshrc"
    before=$(snapshot)
    # --coexist and --clobber are mutually exclusive.
    inst --home "$FW" --coexist --clobber --no-plugins && return 1
    grep -Fq 'cannot be combined' "$TEST_ROOT/err" || return 2
    [ "$(snapshot)" = "$before" ] || return 3

    # Broken symlink is refused before any write.
    ln -s missing-target "$HOME/.zshenv"
    before=$(snapshot)
    inst --home "$FW" --coexist --no-plugins && return 4
    grep -Fq 'broken symlink' "$TEST_ROOT/err" || return 5
    [ "$(snapshot)" = "$before" ] || return 6
    rm "$HOME/.zshenv"

    # Multiple coexist markers in a dotfile are refused before any write.
    printf 'line1 # marksharc: coexist\nline2 # marksharc: coexist\n' > "$HOME/.zshrc"
    before=$(snapshot)
    inst --home "$FW" --coexist --no-plugins && return 7
    grep -Fq 'multiple marksharc coexist lines' "$TEST_ROOT/err" || return 8
    [ "$(snapshot)" = "$before" ] || return 9
    printf 'existing rc\n' > "$HOME/.zshrc"

    # Standard install -> --coexist refused before any write.
    inst --home "$FW" --no-plugins || return 10
    before=$(snapshot)
    inst --home "$FW" --coexist --no-plugins && return 11
    grep -Fq 'standard mode' "$TEST_ROOT/err" && grep -Fq 'uninstall' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 12; }
    [ "$(snapshot)" = "$before" ] || return 13

    # Uninstall standard -> install --coexist -> standard install refused before any write.
    uninstall || return 14
    inst --home "$FW" --coexist --no-plugins || return 15
    before=$(snapshot)
    inst --home "$FW" --no-plugins && return 16
    grep -Fq 'coexist mode' "$TEST_ROOT/err" && grep -Fq 'uninstall' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 17; }
    [ "$(snapshot)" = "$before" ]
  }
  It 'refuses conflicting modes, --clobber, broken symlinks, and duplicate markers before writing'
    When run conflicts_case
    The status should be success
  End

  quoting_case() {
    FW="$TEST_ROOT/my fw's \$dir"
    fake_fw "$FW"
    XDG_STATE_HOME="$TEST_ROOT/my state's \$dir"
    export XDG_STATE_HOME
    MARKSHARC_CONFIG="$TEST_ROOT/my cfg's \$dir" inst --home "$FW" --coexist --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    got=$(env -i HOME="$HOME" PATH="$PATH" zsh -fc 'source "$HOME/.zshenv"; print -r -- "$MARKSHARC_HOME|$MARKSHARC_CONFIG|$MARKSHARC_COEXIST"')
    [ "$got" = "$FW|$TEST_ROOT/my cfg's \$dir|1" ] || { printf 'got: %s\n' "$got"; return 2; }
  }
  It 'keeps spaces, quotes, and dollars in framework, config, and state paths as data'
    When run quoting_case
    The status should be success
  End

  live_zsh_case() {
    FW=$MARKSHARC_ROOT
    printf 'export USER_ZSHENV_VAL=from_user_zshenv\n' > "$HOME/.zshenv"
    cat > "$HOME/.zshrc" <<'EOF'
USER_ZSHRC_VAL=from_user_zshrc
user_greeting() { print -r -- "hello-from-user-zshrc"; }
EOF
    mkdir -p "$TEST_ROOT/overlay"
    printf 'module core\nmodule path\nmodule agent\n' > "$TEST_ROOT/overlay/config.conf"

    inst --home "$FW" --overlay "$TEST_ROOT/overlay" --coexist --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    # Batch shell: silent, keeps user ~/.zshenv export, sets MARKSHARC_HOME, does NOT redirect ZDOTDIR.
    out=$(env -i HOME="$HOME" PATH="$PATH" TERM=dumb XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      MARKSHARC_NOTIFY=0 zsh -c 'print -r -- "$USER_ZSHENV_VAL|$MARKSHARC_SESSION|${ZDOTDIR:-unset}|$(command -v marksharc)"' 2>"$TEST_ROOT/zerr") || return 2
    [ ! -s "$TEST_ROOT/zerr" ] || { cat "$TEST_ROOT/zerr"; return 3; }
    [ "$out" = "from_user_zshenv|batch|unset|$FW/bin/marksharc" ] || { printf 'batch got: %s\n' "$out"; return 4; }
    [ ! -e "$XDG_STATE_HOME/marksharc/zdot" ] || return 5

    # Agent shell: silent, agent class, no ZDOTDIR redirect.
    out=$(env -i HOME="$HOME" PATH="$PATH" TERM=dumb XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      CLAUDECODE=1 MARKSHARC_NOTIFY=0 zsh -c 'print -r -- "$USER_ZSHENV_VAL|$MARKSHARC_SESSION|${ZDOTDIR:-unset}"' 2>"$TEST_ROOT/zerr") || return 6
    [ ! -s "$TEST_ROOT/zerr" ] || { cat "$TEST_ROOT/zerr"; return 7; }
    [ "$out" = "from_user_zshenv|agent|unset" ] || { printf 'agent got: %s\n' "$out"; return 8; }

    # Interactive PTY shell: user ~/.zshrc still works, marksharc init ran, ZDOTDIR stays unset, reload works.
    if [ -n "$PYTHON" ]; then
      env -i HOME="$HOME" PATH="$PATH" TERM=xterm-256color XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
        XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
        MARKSHARC_NOTIFY=0 "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty \
        zsh -i -c '
          marksharc reload || exit 11
          print -r -- "COEXIST_OK|$USER_ZSHENV_VAL|$USER_ZSHRC_VAL|$(user_greeting)|$MARKSHARC_SESSION|${ZDOTDIR:-unset}|$+functions[marksharc]"
          exit
        ' > "$TEST_ROOT/pty.out" 2>&1 < /dev/null || { cat "$TEST_ROOT/pty.out"; return 9; }
      grep -Fq 'COEXIST_OK|from_user_zshenv|from_user_zshrc|hello-from-user-zshrc|interactive|unset|1' "$TEST_ROOT/pty.out" || { cat "$TEST_ROOT/pty.out"; return 10; }
      [ ! -e "$XDG_STATE_HOME/marksharc/zdot" ] || return 11
    fi

    # Uninstall leaves user ~/.zshenv and ~/.zshrc working without marksharc.
    uninstall || { cat "$TEST_ROOT/err"; return 12; }
    out=$(env -i HOME="$HOME" PATH="$PATH" TERM=dumb zsh -ic 'print -r -- "$USER_ZSHENV_VAL|$USER_ZSHRC_VAL|$(user_greeting)|$+MARKSHARC_HOME"' 2>/dev/null) || return 13
    [ "$out" = "from_user_zshenv|from_user_zshrc|hello-from-user-zshrc|0" ] || { printf 'after uninstall got: %s\n' "$out"; return 14; }
  }
  It 'keeps existing ~/.zshenv and ~/.zshrc working alongside marksharc without redirecting ZDOTDIR'
    When run live_zsh_case
    The status should be success
  End

  fallback_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    printf 'export USER_ENV=kept\n' > "$HOME/.zshenv"
    inst --home "$FW" --coexist --no-plugins || return 1
    rm "$FW/core/zsh/zshenv.zsh"
    out=$(env -i HOME="$HOME" PATH="$PATH" TERM=dumb zsh -c 'print -r -- "$USER_ENV|$PATH"' 2>"$TEST_ROOT/ferr") || return 2
    [ "$out" = "kept|$FW/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin" ] || { printf 'out: %s\n' "$out"; return 3; }
    [ "$(grep -c '^marksharc: could not load ' "$TEST_ROOT/ferr")" = 1 ] || { cat "$TEST_ROOT/ferr"; return 4; }
  }
  It 'falls back to a minimal PATH with one stderr line when the core fails to load in coexist mode'
    When run fallback_case
    The status should be success
  End

  dash_case() {
    FW=$TEST_ROOT/fw
    fake_fw "$FW"
    printf 'user rc\n' > "$HOME/.zshrc"
    dash -n "$installer" || return 1
    dash "$installer" --home "$FW" --coexist --no-plugins > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    grep -Fq '# marksharc: coexist' "$HOME/.zshenv" && grep -Fq '# marksharc: coexist' "$HOME/.zshrc"
  }
  It 'runs --coexist under dash'
    Skip if 'dash is not installed' ! command -v dash > /dev/null 2>&1
    When run dash_case
    The status should be success
  End
End
