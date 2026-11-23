# install.sh (spec 6.15), exercised in a temporary HOME with a minimal fake framework,
# local bare repositories for the clone paths and no network.
Describe 'install.sh'
  installer="$MARKSHARC_ROOT/install.sh"

  fish_stub_case() {
    fake_fw "$TEST_ROOT/fw"
    mkdir -p "$XDG_CONFIG_HOME/fish" "$TEST_ROOT/fw/core/fish"
    : > "$TEST_ROOT/fw/core/fish/marksharc.fish"
    printf 'user config\n' > "$XDG_CONFIG_HOME/fish/config.fish"
    inst --home "$TEST_ROOT/fw" --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    stub="$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish"
    [ -f "$stub" ] || return 2
    [ "$(cat "$XDG_CONFIG_HOME/fish/config.fish")" = 'user config' ] || return 3
    grep -Fq 'core/fish/marksharc.fish' "$stub" || return 4
    before=$(cksum "$stub")
    inst --home "$TEST_ROOT/fw" --no-plugins || return 5
    [ "$(cksum "$stub")" = "$before" ]
  }
  It 'installs an idempotent fish stub without touching fish config'
    When run fish_stub_case
    The status should be success
  End

  fish_quote_case() {
    fw="$TEST_ROOT/fw 'dollar\$ and \\ slash"
    fake_fw "$fw"
    mkdir -p "$fw/core/fish"
    printf 'printf "%%s\\n" "$MARKSHARC_HOME"\n' > "$fw/core/fish/marksharc.fish"
    inst --home "$fw" --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    result=$(fish --no-config -c 'source "$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish"') || return 2
    [ "$result" = "$fw" ] || { printf 'expected <%s> got <%s>\n' "$fw" "$result"; cat "$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish"; return 3; }
  }
  It 'preserves quotes, dollar signs, and backslashes in the fish framework path'
    When run fish_quote_case
    The status should be success
  End

  fish_collision_case() {
    fake_fw "$TEST_ROOT/fw"
    mkdir -p "$XDG_CONFIG_HOME/fish/conf.d" "$TEST_ROOT/fw/core/fish"
    : > "$TEST_ROOT/fw/core/fish/marksharc.fish"
    printf 'foreign\n' > "$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish"
    inst --home "$TEST_ROOT/fw" --no-plugins && return 1
    [ "$(cat "$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish")" = foreign ] || return 2
    [ ! -e "$HOME/.zshenv" ]
  }
  It 'refuses a foreign fish stub before writing'
    When run fish_collision_case
    The status should be success
  End

  fresh_case() {
    fake_fw "$TEST_ROOT/fw"
    # With the XDG variables at their defaults the stub names no MARKSHARC_CONFIG.
    INST_XDG=default inst --home "$TEST_ROOT/fw" || { cat "$TEST_ROOT/err"; return 1; }
    MF_FILE=$HOME/.local/state/marksharc/install.manifest
    [ -s "$TEST_ROOT/err" ] && { cat "$TEST_ROOT/err"; return 2; }
    head -n 1 "$HOME/.zshenv" | grep -q '^# marksharc: managed stub' || return 3
    grep -q "^MARKSHARC_HOME='$TEST_ROOT/fw'\$" "$HOME/.zshenv" || return 4
    grep -q '^MARKSHARC_CONFIG' "$HOME/.zshenv" && return 5
    zsh -n "$HOME/.zshenv" || return 6
    [ -f "$HOME/.config/marksharc/config.conf" ] && [ -f "$HOME/.config/marksharc/local/post.zsh" ] || return 7
    [ -e "$HOME/.config/marksharc/.gitkeep" ] && return 8
    [ "$(mf framework)" = "$TEST_ROOT/fw" ] && [ "$(mf framework_cloned)" = 0 ] || return 9
    [ "$(mf home)" = "$HOME" ] && [ "$(mf config)" = "$HOME/.config/marksharc" ] || return 10
    grep -q 'installed' "$TEST_ROOT/out" || return 11
    # The framework checkout is only read.
    [ -z "$(find "$TEST_ROOT/fw" -newer "$HOME/.zshenv" -print)" ] || return 12
    # No XDG warnings when nothing is non-default.
    grep -qi 'warning' "$TEST_ROOT/out" && return 13
    return 0
  }
  It 'installs the stub, the template overlay and a manifest from a checkout'
    When run fresh_case
    The status should be success
  End

  render_case() {
    mkdir -p "$TEST_ROOT/overlay"
    printf 'module path\n' > "$TEST_ROOT/overlay/config.conf"
    inst --home "$MARKSHARC_ROOT" --overlay "$TEST_ROOT/overlay" --no-plugins || { cat "$TEST_ROOT/err"; return 1; }
    host=$(zsh -fc 'print -r -- ${HOST%%.*}')
    cache="$XDG_CACHE_HOME/marksharc/$host"
    [ -s "$cache/env.zsh" ] && [ -s "$cache/render-id" ] || return 2
    [ "$(sed -n '2p' "$cache/env.zsh")" = "# render id: $(cat "$cache/render-id")" ]
  }
  It 'writes the first declarative render into the cache'
    When run render_case
    The status should be success
  End

  quoting_case() {
    fake_fw "$TEST_ROOT/my fw's \$dir"
    inst --home "$TEST_ROOT/my fw's \$dir" || { cat "$TEST_ROOT/err"; return 1; }
    got=$(env -i HOME="$HOME" PATH="$PATH" zsh -fc 'source "$HOME/.zshenv"; print -r -- "$MARKSHARC_HOME"')
    [ "$got" = "$TEST_ROOT/my fw's \$dir" ] || { printf 'got %s\n' "$got"; return 2; }
    [ "$(mf framework)" = "$TEST_ROOT/my fw's \$dir" ] || return 3
  }
  It 'keeps spaces, quotes and dollars in the framework path as data'
    When run quoting_case
    The status should be success
  End

  config_case() {
    fake_fw "$TEST_ROOT/fw"
    MARKSHARC_CONFIG="$TEST_ROOT/custom config" inst --home "$TEST_ROOT/fw" || { cat "$TEST_ROOT/err"; return 1; }
    got=$(env -i HOME="$HOME" PATH="$PATH" zsh -fc 'source "$HOME/.zshenv"; print -r -- "$MARKSHARC_CONFIG"')
    [ "$got" = "$TEST_ROOT/custom config" ] || { printf 'got %s\n' "$got"; return 2; }
    [ -f "$TEST_ROOT/custom config/config.conf" ] || return 3
    [ -e "$XDG_CONFIG_HOME/marksharc" ] && return 4
    return 0
  }
  It 'names a non-default MARKSHARC_CONFIG in the stub and installs the overlay there'
    When run config_case
    The status should be success
  End

  dotfiles_case() {
    fake_fw "$TEST_ROOT/fw"
    for n in .zshenv .zshrc .zprofile .zlogin .zlogout; do printf 'original %s\n' "$n" > "$HOME/$n"; done
    inst --home "$TEST_ROOT/fw" || { cat "$TEST_ROOT/err"; return 1; }
    for n in .zshrc .zprofile .zlogin .zlogout; do [ -e "$HOME/$n" ] && { echo "$n left in HOME"; return 2; }; done
    head -n 1 "$HOME/.zshenv" | grep -q '^# marksharc: managed stub' || return 3
    bk=$(backup_dir)
    case $bk in "$XDG_STATE_HOME"/marksharc/backup/*) ;; *) echo "backup at $bk"; return 4;; esac
    for n in .zshenv .zshrc .zprofile .zlogin .zlogout; do
      [ "$(cat "$bk/$n")" = "original $n" ] || { echo "backup of $n wrong"; return 5; }
      grep -qx "file=$n" "$XDG_STATE_HOME/marksharc/install.manifest" || { echo "manifest lacks $n"; return 6; }
    done
    [ "$(file_mode "$bk")" = 700 ] || return 7
    grep -q 'backed up' "$TEST_ROOT/out" || return 8
  }
  It 'moves every existing zsh dotfile into a private backup recorded in the manifest'
    When run dotfiles_case
    The status should be success
  End

  symlink_case() {
    fake_fw "$TEST_ROOT/fw"
    mkdir -p "$TEST_ROOT/linked dir"
    printf 'linked\n' > "$TEST_ROOT/linked dir/zshenv"
    ln -s "$TEST_ROOT/linked dir/zshenv" "$HOME/.zshenv"
    printf 'rc\n' > "$HOME/real-rc"
    ln -s real-rc "$HOME/.zshrc"
    inst --home "$TEST_ROOT/fw" || { cat "$TEST_ROOT/err"; return 1; }
    [ -L "$HOME/.zshenv" ] && return 2
    [ -L "$HOME/.zshrc" ] && return 3
    [ "$(cat "$TEST_ROOT/linked dir/zshenv")" = linked ] || return 4
    grep -qx "link=.zshenv=$TEST_ROOT/linked dir/zshenv" "$XDG_STATE_HOME/marksharc/install.manifest" || { cat "$XDG_STATE_HOME/marksharc/install.manifest"; return 5; }
    grep -qx 'link=.zshrc=real-rc' "$XDG_STATE_HOME/marksharc/install.manifest" || return 6
    [ -e "$(backup_dir)/.zshenv" ] && return 7
    return 0
  }
  It 'records a symlinked dotfile by its target and writes the stub as a regular file'
    When run symlink_case
    The status should be success
  End

  idempotent_case() {
    fake_fw "$TEST_ROOT/fw"
    printf 'original\n' > "$HOME/.zshrc"
    printf 'foreign\n' > "$HOME/.zshenv"
    inst --home "$TEST_ROOT/fw" || return 1
    cp "$XDG_STATE_HOME/marksharc/install.manifest" "$TEST_ROOT/manifest.1"
    cp "$HOME/.zshenv" "$TEST_ROOT/stub.1"
    inst --home "$TEST_ROOT/fw" || { cat "$TEST_ROOT/err"; return 2; }
    [ "$(ls "$XDG_STATE_HOME/marksharc/backup" | wc -l | tr -d ' ')" = 1 ] || { ls "$XDG_STATE_HOME/marksharc/backup"; return 3; }
    cmp -s "$TEST_ROOT/manifest.1" "$XDG_STATE_HOME/marksharc/install.manifest" || return 4
    cmp -s "$TEST_ROOT/stub.1" "$HOME/.zshenv" || return 5
    [ "$(cat "$(backup_dir)/.zshrc")" = original ] && [ "$(cat "$(backup_dir)/.zshenv")" = foreign ] || return 6
    grep -q 'already installed; nothing to change' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 7; }
    # Pointing the stub at another checkout rewrites it but keeps the original backup.
    fake_fw "$TEST_ROOT/fw2"
    inst --home "$TEST_ROOT/fw2" || { cat "$TEST_ROOT/err"; return 8; }
    [ "$(ls "$XDG_STATE_HOME/marksharc/backup" | wc -l | tr -d ' ')" = 1 ] || return 9
    grep -q "^MARKSHARC_HOME='$TEST_ROOT/fw2'\$" "$HOME/.zshenv" || return 10
    [ "$(mf framework)" = "$TEST_ROOT/fw2" ] || return 11
    grep -qx 'file=.zshrc' "$XDG_STATE_HOME/marksharc/install.manifest" && grep -qx 'file=.zshenv' "$XDG_STATE_HOME/marksharc/install.manifest" || return 12
    [ "$(cat "$(backup_dir)/.zshenv")" = foreign ] || return 13
  }
  It 're-runs safely: no new backup, the original backup kept, the stub repointed on request'
    When run idempotent_case
    The status should be success
  End

  dry_run_case() {
    fake_fw "$TEST_ROOT/fw"
    printf 'original\n' > "$HOME/.zshrc"
    printf 'foreign\n' > "$HOME/.zshenv"
    mkdir -p "$TEST_ROOT/ov"
    before=$(snapshot)
    cp "$HOME/.zshenv" "$TEST_ROOT/zshenv.before"
    MARKSHARC_REPO=file:///nonexistent inst --dry-run --home "$TEST_ROOT/fw" --overlay "$TEST_ROOT/ov" || { cat "$TEST_ROOT/err"; return 1; }
    [ "$(snapshot)" = "$before" ] || { snapshot; return 2; }
    cmp -s "$TEST_ROOT/zshenv.before" "$HOME/.zshenv" || return 3
    for want in 'would back up' 'would write' 'would link'; do grep -q "$want" "$TEST_ROOT/out" || { echo "missing: $want"; cat "$TEST_ROOT/out"; return 4; }; done
    # Without --home or an overlay flag, a clone and the template copy are planned too.
    INST_SCRIPT="$TEST_ROOT/elsewhere/install.sh"
    mkdir -p "$TEST_ROOT/elsewhere"; cp "$installer" "$INST_SCRIPT"
    MARKSHARC_REPO=file:///nonexistent inst --dry-run || { cat "$TEST_ROOT/err"; return 5; }
    [ "$(snapshot)" = "$before" ] || return 6
    grep -q 'would run: git clone' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 7; }
    grep -q 'would copy' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 8; }
  }
  It 'prints every action and writes nothing with --dry-run'
    When run dry_run_case
    The status should be success
  End

  overlay_path_case() {
    fake_fw "$TEST_ROOT/fw"
    mkdir -p "$TEST_ROOT/my overlay"
    printf 'module brew off\n' > "$TEST_ROOT/my overlay/config.conf"
    inst --home "$TEST_ROOT/fw" --overlay "$TEST_ROOT/my overlay" || { cat "$TEST_ROOT/err"; return 1; }
    [ -L "$XDG_CONFIG_HOME/marksharc" ] || return 2
    [ "$(readlink "$XDG_CONFIG_HOME/marksharc")" = "$TEST_ROOT/my overlay" ] || return 3
    [ "$(ls -A "$TEST_ROOT/my overlay")" = config.conf ] || return 4
    inst --home "$TEST_ROOT/fw" --overlay "$TEST_ROOT/my overlay" || { cat "$TEST_ROOT/err"; return 5; }
    [ "$(mf config_origin)" = link ] || return 6
  }
  It 'links a local overlay path and leaves it untouched, also on re-run'
    When run overlay_path_case
    The status should be success
  End

  overlay_url_case() {
    make_origin
    fake_fw "$TEST_ROOT/fw"
    inst --home "$TEST_ROOT/fw" --overlay "file://$TEST_ROOT/origin.git" || { cat "$TEST_ROOT/err"; return 1; }
    [ -d "$XDG_CONFIG_HOME/marksharc/.git" ] && [ -f "$XDG_CONFIG_HOME/marksharc/core/zsh/zshenv.zsh" ] || return 2
    [ "$(mf config_origin)" = clone ] || return 3
    inst --home "$TEST_ROOT/fw" --overlay "file://$TEST_ROOT/origin.git" || { cat "$TEST_ROOT/err"; return 4; }
    before=$(snapshot)
    inst --home "$TEST_ROOT/fw" --overlay "file://$TEST_ROOT/other.git" && return 5
    grep -q 'overlay' "$TEST_ROOT/err" || return 6
    [ "$(snapshot)" = "$before" ] || return 7
  }
  It 'clones an overlay URL and treats a different URL for the same place as a conflict'
    When run overlay_url_case
    The status should be success
  End

  overlay_conflict_case() {
    fake_fw "$TEST_ROOT/fw"
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$TEST_ROOT/wanted"
    printf 'mine\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    printf 'original\n' > "$HOME/.zshrc"
    before=$(snapshot)
    inst --home "$TEST_ROOT/fw" --overlay "$TEST_ROOT/wanted" && return 1
    grep -q 'already exists' "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    [ "$(snapshot)" = "$before" ] || { snapshot; return 3; }
    [ -f "$HOME/.zshrc" ] || return 4
    [ "$(cat "$XDG_CONFIG_HOME/marksharc/config.conf")" = mine ] || return 5
    # A missing local path is refused before any write too.
    inst --home "$TEST_ROOT/fw" --overlay "$TEST_ROOT/no such overlay" && return 6
    [ "$(snapshot)" = "$before" ]
  }
  It 'refuses a conflicting or missing overlay before writing anything'
    When run overlay_conflict_case
    The status should be success
  End

  existing_overlay_case() {
    fake_fw "$TEST_ROOT/fw"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf 'mine\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    inst --home "$TEST_ROOT/fw" || { cat "$TEST_ROOT/err"; return 1; }
    [ "$(ls -A "$XDG_CONFIG_HOME/marksharc")" = config.conf ] || return 2
    [ "$(cat "$XDG_CONFIG_HOME/marksharc/config.conf")" = mine ] || return 3
    [ "$(mf config_origin)" = existing ]
  }
  It 'never modifies an overlay that already exists'
    When run existing_overlay_case
    The status should be success
  End

  clone_case() {
    make_origin
    mkdir -p "$TEST_ROOT/elsewhere"
    cp "$installer" "$TEST_ROOT/elsewhere/install.sh"
    INST_SCRIPT="$TEST_ROOT/elsewhere/install.sh"
    MARKSHARC_REPO="file://$TEST_ROOT/origin.git" inst || { cat "$TEST_ROOT/err"; return 1; }
    clone=$XDG_DATA_HOME/marksharc
    [ -f "$clone/core/zsh/zshenv.zsh" ] && [ -d "$clone/.git" ] || return 2
    [ "$(mf framework)" = "$clone" ] && [ "$(mf framework_cloned)" = 1 ] || return 3
    grep -q "^MARKSHARC_HOME='$clone'\$" "$HOME/.zshenv" || return 4
    # A new upstream commit is not pulled into an existing clone.
    head=$("$REAL_GIT" -C "$clone" rev-parse HEAD)
    : > "$TEST_ROOT/seed/new"
    "$REAL_GIT" -C "$TEST_ROOT/seed" add -A
    "$REAL_GIT" -C "$TEST_ROOT/seed" -c user.email=f@example.invalid -c user.name=Fixture commit -qm more
    "$REAL_GIT" -C "$TEST_ROOT/seed" push -q "$TEST_ROOT/origin.git" main
    MARKSHARC_REPO="file://$TEST_ROOT/origin.git" inst || { cat "$TEST_ROOT/err"; return 5; }
    [ "$("$REAL_GIT" -C "$clone" rev-parse HEAD)" = "$head" ] || return 6
    [ "$(mf framework_cloned)" = 1 ] || return 7
  }
  It 'clones the framework when not run from a checkout, and reuses an existing clone without pulling'
    When run clone_case
    The status should be success
  End

  self_case() {
    fake_fw "$TEST_ROOT/fw"
    cp "$installer" "$TEST_ROOT/fw/install.sh"
    INST_SCRIPT="$TEST_ROOT/fw/install.sh"
    MARKSHARC_REPO=file:///nonexistent inst || { cat "$TEST_ROOT/err"; return 1; }
    [ "$(mf framework)" = "$TEST_ROOT/fw" ] && [ "$(mf framework_cloned)" = 0 ] || return 2
    [ -e "$XDG_DATA_HOME/marksharc" ] && return 3
    # --home always wins over the checkout the script sits in.
    fake_fw "$TEST_ROOT/other"
    inst --home "$TEST_ROOT/other" || return 4
    [ "$(mf framework)" = "$TEST_ROOT/other" ]
  }
  It 'uses its own checkout without cloning, unless --home names another'
    When run self_case
    The status should be success
  End

  bad_home_case() {
    mkdir -p "$TEST_ROOT/notfw"
    printf 'original\n' > "$HOME/.zshrc"
    before=$(snapshot)
    inst --home "$TEST_ROOT/notfw" && return 1
    grep -q 'core/zsh/zshenv.zsh' "$TEST_ROOT/err" || return 2
    inst --bogus && return 3
    grep -q 'unknown option' "$TEST_ROOT/err" || return 4
    inst --overlay && return 5
    [ "$(snapshot)" = "$before" ]
  }
  It 'rejects a --home that is not a checkout and bad options before writing'
    When run bad_home_case
    The status should be success
  End

  needs_case() {
    fake_fw "$TEST_ROOT/fw"
    printf 'original\n' > "$HOME/.zshrc"
    before=$(snapshot)
    mkdir "$TEST_ROOT/minbin"
    for t in sh mkdir cp mv rm ln date readlink dirname basename cat sed awk grep cmp chmod find sort tr wc uname head; do
      p=$(command -v "$t") && ln -s "$p" "$TEST_ROOT/minbin/$t"
    done
    # no zsh
    ln -s "$REAL_GIT" "$TEST_ROOT/minbin/git"
    PATH="$TEST_ROOT/minbin" inst --home "$TEST_ROOT/fw" && return 1
    grep -q 'zsh' "$TEST_ROOT/err" || return 2
    [ "$(snapshot)" = "$before" ] || return 3
    # no git
    rm "$TEST_ROOT/minbin/git"
    ln -s "$(command -v zsh)" "$TEST_ROOT/minbin/zsh"
    PATH="$TEST_ROOT/minbin" inst --home "$TEST_ROOT/fw" && return 4
    grep -q 'git' "$TEST_ROOT/err" || return 5
    [ "$(snapshot)" = "$before" ] || return 6
    # zsh older than 5.9
    rm "$TEST_ROOT/minbin/zsh"
    printf '#!/bin/sh\necho 5.8\n' > "$TEST_ROOT/minbin/zsh"; chmod +x "$TEST_ROOT/minbin/zsh"
    ln -s "$REAL_GIT" "$TEST_ROOT/minbin/git"
    PATH="$TEST_ROOT/minbin" inst --home "$TEST_ROOT/fw" && return 7
    grep -q '5.9' "$TEST_ROOT/err" || return 8
    [ "$(snapshot)" = "$before" ]
  }
  It 'fails before any write when zsh or git is missing or zsh is too old'
    When run needs_case
    The status should be success
  End

  shell_hint_case() {
    fake_fw "$TEST_ROOT/fw"
    stub_command chsh 'echo "$*" >> "$OPLOG"'
    INST_SHELL=/bin/bash inst --home "$TEST_ROOT/fw" || return 1
    grep -q 'chsh -s' "$TEST_ROOT/out" || return 2
    INST_SHELL=/usr/bin/zsh inst --home "$TEST_ROOT/fw" || return 3
    grep -q 'chsh' "$TEST_ROOT/out" && return 4
    # The installer prints the hint; it never changes the login shell itself.
    [ ! -s "$OPLOG" ]
  }
  It 'prints the chsh hint for a non-zsh login shell and never runs chsh'
    When run shell_hint_case
    The status should be success
  End

  dash_case() {
    fake_fw "$TEST_ROOT/fw"
    dash -n "$installer" || return 1
    dash "$installer" --home "$TEST_ROOT/fw" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    [ -f "$HOME/.zshenv" ]
  }
  It 'runs under dash'
    Skip if 'dash is not installed' ! command -v dash > /dev/null 2>&1
    When run dash_case
    The status should be success
  End

End
