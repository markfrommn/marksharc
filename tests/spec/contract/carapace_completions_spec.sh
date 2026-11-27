# Carapace managed spec wiring, lifecycle, precedence, and end-to-end parity
# (COMPLETION-SPEC sections 6 and 8).
Describe 'Carapace managed specs and lifecycle'
  carapace_absent() {
    [ -z "${REAL_CARAPACE:-}" ] || [ ! -x "${REAL_CARAPACE:-}" ]
  }

  render_carapace_fixture() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_HOST=carahost
    config="$XDG_CONFIG_HOME/marksharc"
    mkdir -p "$config/modules/custom-mod"
    cat > "$config/hosts.conf" <<'EOF'
host alpha ops@alpha
host builder ops@builder
EOF
    cat > "$config/modules/custom-mod/module.conf" <<'EOF'
describe "Custom overlay module"
installer demo-tool ./install.sh
update custom-step echo ok
EOF
    printf '#!/bin/sh\nexit 0\n' > "$config/modules/custom-mod/install.sh"
    chmod +x "$config/modules/custom-mod/install.sh"
  }

  run_render() {
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb \
      MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$XDG_CONFIG_HOME/marksharc" \
      MARKSHARC_HOST=carahost HOST=carahost OPLOG="$OPLOG" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      /bin/zsh -f "$MARKSHARC_ROOT/core/cli/render" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
  }

  specs_dir_resolution_case() {
    out=$(/bin/zsh -fc '
      source "$1"
      XDG_CONFIG_HOME="/tmp/custom-xdg///" MARKSHARC_OS=darwin _ms_carapace_specs_dir
      print -r -- "XDG_DARWIN=$REPLY"
      XDG_CONFIG_HOME="/tmp/custom-xdg" MARKSHARC_OS=linux _ms_carapace_specs_dir
      print -r -- "XDG_LINUX=$REPLY"
      unset XDG_CONFIG_HOME
      HOME="/Users/demo" MARKSHARC_OS=darwin _ms_carapace_specs_dir
      print -r -- "DEF_DARWIN=$REPLY"
      HOME="/home/demo" MARKSHARC_OS=linux _ms_carapace_specs_dir
      print -r -- "DEF_LINUX=$REPLY"
    ' _ "$MARKSHARC_ROOT/core/zsh/lib/carapace.zsh") || return 1
    case "$out" in
      *"XDG_DARWIN=/tmp/custom-xdg/carapace/specs"*);; *) printf '%s\n' "$out"; return 2 ;;
    esac
    case "$out" in
      *"XDG_LINUX=/tmp/custom-xdg/carapace/specs"*);; *) printf '%s\n' "$out"; return 3 ;;
    esac
    case "$out" in
      *"DEF_DARWIN=/Users/demo/Library/Application Support/carapace/specs"*);; *) printf '%s\n' "$out"; return 4 ;;
    esac
    case "$out" in
      *"DEF_LINUX=/home/demo/.config/carapace/specs"*);; *) printf '%s\n' "$out"; return 5 ;;
    esac
  }
  It 'resolves Carapace specs directory for XDG_CONFIG_HOME, macOS, and Linux'
    When run specs_dir_resolution_case
    The status should be success
  End

  symlink_lifecycle_case() {
    render_carapace_fixture || return 1
    cache="$XDG_CACHE_HOME/marksharc/carahost"
    specs_dir="$XDG_CONFIG_HOME/carapace/specs"

    # Default (completion-carapace off): renders YAML cache but creates no symlinks or specs dir.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module launch
module cwf
module completion-carapace
set completion-carapace.enable off
EOF
    run_render || { cat "$TEST_ROOT/err"; return 1; }
    [ -r "$cache/completions/carapace/marksharc.yaml" ] || return 2
    [ ! -e "$specs_dir" ] && [ ! -e "$cache/carapace-specs-manifest" ] || return 3

    # Enable completion-carapace: creates managed symlinks and manifest.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module launch
module cwf
module completion-carapace
set completion-carapace.enable on
EOF
    run_render || { cat "$TEST_ROOT/err"; return 4; }
    for cmd in marksharc launch-session launch-repo cwf-new; do
      [ -L "$specs_dir/$cmd.yaml" ] || return 5
      [ "$(readlink "$specs_dir/$cmd.yaml")" = "$cache/completions/carapace/$cmd.yaml" ] || return 6
      grep -q "^${cmd}	${specs_dir}/${cmd}.yaml	${cache}/completions/carapace/${cmd}.yaml$" "$cache/carapace-specs-manifest" || return 7
    done

    # Replace launch-repo with a user regular file and cwf-new with a foreign symlink.
    rm -f "$specs_dir/launch-repo.yaml" "$specs_dir/cwf-new.yaml"
    printf 'name: launch-repo\n# user custom spec\n' > "$specs_dir/launch-repo.yaml"
    printf 'name: cwf-new\n# foreign target\n' > "$TEST_ROOT/foreign-cwf.yaml"
    ln -s "$TEST_ROOT/foreign-cwf.yaml" "$specs_dir/cwf-new.yaml"
    printf 'name: user-only\n' > "$specs_dir/user-only.yaml"

    run_render || { cat "$TEST_ROOT/err"; return 8; }
    # Regular file and foreign symlink preserved; warnings emitted on stderr; not added to manifest.
    [ -f "$specs_dir/launch-repo.yaml" ] && [ ! -L "$specs_dir/launch-repo.yaml" ] || return 9
    grep -Fq '# user custom spec' "$specs_dir/launch-repo.yaml" || return 10
    [ -L "$specs_dir/cwf-new.yaml" ] && [ "$(readlink "$specs_dir/cwf-new.yaml")" = "$TEST_ROOT/foreign-cwf.yaml" ] || return 11
    grep -Fq "$specs_dir/launch-repo.yaml" "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 12; }
    grep -Fq "$specs_dir/cwf-new.yaml" "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 13; }
    ! grep -q '^launch-repo	' "$cache/carapace-specs-manifest" || return 14
    ! grep -q '^cwf-new	' "$cache/carapace-specs-manifest" || return 15
    [ -L "$specs_dir/marksharc.yaml" ] && [ -L "$specs_dir/launch-session.yaml" ] || return 16

    # --env-only never modifies symlinks or manifest even when config disables Carapace.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module launch off
module completion-carapace off
EOF
    run_render --env-only || { cat "$TEST_ROOT/err"; return 17; }
    [ -L "$specs_dir/marksharc.yaml" ] && [ -L "$specs_dir/launch-session.yaml" ] && [ -r "$cache/carapace-specs-manifest" ] || return 18

    # Disable launch module only: prunes launch-session symlink, keeps marksharc and user files.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module cwf
module completion-carapace
EOF
    run_render || { cat "$TEST_ROOT/err"; return 19; }
    [ ! -e "$specs_dir/launch-session.yaml" ] && [ ! -L "$specs_dir/launch-session.yaml" ] || return 20
    [ -L "$specs_dir/marksharc.yaml" ] || return 21
    [ -f "$specs_dir/launch-repo.yaml" ] && [ -L "$specs_dir/cwf-new.yaml" ] && [ -f "$specs_dir/user-only.yaml" ] || return 22

    # Disable completion-carapace: prunes remaining managed symlinks and removes manifest; user files untouched.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module cwf
module completion-carapace off
EOF
    run_render || { cat "$TEST_ROOT/err"; return 23; }
    [ ! -e "$specs_dir/marksharc.yaml" ] && [ ! -L "$specs_dir/marksharc.yaml" ] || return 24
    [ ! -e "$cache/carapace-specs-manifest" ] || return 25
    grep -Fq '# user custom spec' "$specs_dir/launch-repo.yaml" || return 26
    [ "$(readlink "$specs_dir/cwf-new.yaml")" = "$TEST_ROOT/foreign-cwf.yaml" ] || return 27
    [ -f "$specs_dir/user-only.yaml" ] || return 28
  }
  It 'reconciles managed symlinks, preserves non-MarkSharc conflicts, respects --env-only, and prunes on disable'
    When run symlink_lifecycle_case
    The status should be success
  End

  uninstall_cleanup_case() {
    # Remove forbidden herdr/cwf stubs so full-tree render during install/render stays hermetic.
    rm -f "$TEST_ROOT/bin/herdr" "$TEST_ROOT/bin/cwf"
    specs_dir="$XDG_CONFIG_HOME/carapace/specs"
    mkdir -p "$specs_dir"
    printf 'name: custom-user\n' > "$specs_dir/custom-user.yaml"
    printf 'name: launch-repo\n# user owned\n' > "$specs_dir/launch-repo.yaml"

    env -i HOME="$HOME" PATH="$PATH:${REAL_GIT%/*}" TERM=dumb SHELL=/bin/zsh OPLOG="$OPLOG" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      sh "$MARKSHARC_ROOT/install.sh" --home "$MARKSHARC_ROOT" --no-plugins \
      > "$TEST_ROOT/inst-out" 2> "$TEST_ROOT/inst-err" || { cat "$TEST_ROOT/inst-err"; return 1; }

    printf 'set completion-carapace.enable on\n' >> "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb SHELL=/bin/zsh OPLOG="$OPLOG" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      "$MARKSHARC_ROOT/bin/marksharc" render > "$TEST_ROOT/r-out" 2> "$TEST_ROOT/r-err" || { cat "$TEST_ROOT/r-err"; return 2; }
    [ -L "$specs_dir/marksharc.yaml" ] && [ -L "$specs_dir/launch-session.yaml" ] && [ -L "$specs_dir/cwf-new.yaml" ] || return 3

    # Standard uninstall removes managed symlinks and leaves user files untouched.
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb SHELL=/bin/zsh OPLOG="$OPLOG" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      "$MARKSHARC_ROOT/bin/marksharc" uninstall > "$TEST_ROOT/u-out" 2> "$TEST_ROOT/u-err" || { cat "$TEST_ROOT/u-err"; return 4; }
    [ ! -L "$specs_dir/marksharc.yaml" ] && [ ! -L "$specs_dir/launch-session.yaml" ] && [ ! -L "$specs_dir/cwf-new.yaml" ] || return 5
    grep -Fq '# user owned' "$specs_dir/launch-repo.yaml" && [ -f "$specs_dir/custom-user.yaml" ] || return 6

    # Re-install, re-render, and test uninstall --purge --yes removes symlinks BEFORE deleting cache.
    env -i HOME="$HOME" PATH="$PATH:${REAL_GIT%/*}" TERM=dumb SHELL=/bin/zsh OPLOG="$OPLOG" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      sh "$MARKSHARC_ROOT/install.sh" --home "$MARKSHARC_ROOT" --no-plugins \
      > "$TEST_ROOT/inst2-out" 2> "$TEST_ROOT/inst2-err" || { cat "$TEST_ROOT/inst2-err"; return 7; }
    [ -L "$specs_dir/marksharc.yaml" ] && [ -L "$specs_dir/launch-session.yaml" ] || return 8

    env -i HOME="$HOME" PATH="$PATH" TERM=dumb SHELL=/bin/zsh OPLOG="$OPLOG" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      "$MARKSHARC_ROOT/bin/marksharc" uninstall --purge --yes > "$TEST_ROOT/up-out" 2> "$TEST_ROOT/up-err" || { cat "$TEST_ROOT/up-err"; return 9; }
    [ ! -L "$specs_dir/marksharc.yaml" ] && [ ! -L "$specs_dir/launch-session.yaml" ] && [ ! -L "$specs_dir/cwf-new.yaml" ] || return 10
    [ ! -e "$XDG_CACHE_HOME/marksharc" ] || return 11
    grep -Fq '# user owned' "$specs_dir/launch-repo.yaml" && [ -f "$specs_dir/custom-user.yaml" ] || return 12
  }
  It 'removes manifest-tracked Carapace symlinks on uninstall and uninstall --purge without touching user specs'
    When run uninstall_cleanup_case
    The status should be success
  End

  doctor_diagnostics_case() {
    render_carapace_fixture || return 1
    cache="$XDG_CACHE_HOME/marksharc/carahost"
    specs_dir="$XDG_CONFIG_HOME/carapace/specs"
    stub_command carapace 'exit 0'
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module launch
module cwf
module completion-carapace
set completion-carapace.enable on
EOF
    run_render || { cat "$TEST_ROOT/err"; return 1; }

    run_doctor() {
      env -i HOME="$HOME" PATH="$PATH" TERM=dumb \
        MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$XDG_CONFIG_HOME/marksharc" \
        MARKSHARC_HOST=carahost HOST=carahost MARKSHARC_NOTIFY=0 \
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
        "$MARKSHARC_ROOT/bin/marksharc" doctor > "$TEST_ROOT/doc-out" 2> "$TEST_ROOT/doc-err"
    }

    # Healthy symlinks: no Carapace spec diagnostics.
    run_doctor || return 2
    ! grep -Fq 'Carapace spec' "$TEST_ROOT/doc-out" || { cat "$TEST_ROOT/doc-out"; return 3; }

    # Missing symlink, broken managed symlink, conflicting regular file, and conflicting foreign symlink.
    rm -f "$specs_dir/marksharc.yaml"
    ln -sf "$cache/completions/carapace/nonexistent.yaml" "$specs_dir/launch-session.yaml"
    rm -f "$specs_dir/launch-repo.yaml" "$specs_dir/cwf-new.yaml"
    printf 'name: launch-repo\n' > "$specs_dir/launch-repo.yaml"
    printf 'name: cwf-new\n' > "$TEST_ROOT/user-cwf.yaml"
    ln -s "$TEST_ROOT/user-cwf.yaml" "$specs_dir/cwf-new.yaml"

    run_doctor || return 4
    grep -Fq "missing Carapace spec symlink: $specs_dir/marksharc.yaml (run marksharc render)" "$TEST_ROOT/doc-out" || { cat "$TEST_ROOT/doc-out"; return 5; }
    grep -Fq "broken Carapace spec symlink: $specs_dir/launch-session.yaml" "$TEST_ROOT/doc-out" || { cat "$TEST_ROOT/doc-out"; return 6; }
    grep -Fq "conflicting non-MarkSharc Carapace spec: $specs_dir/launch-repo.yaml" "$TEST_ROOT/doc-out" || { cat "$TEST_ROOT/doc-out"; return 7; }
    grep -Fq "conflicting non-MarkSharc Carapace spec: $specs_dir/cwf-new.yaml" "$TEST_ROOT/doc-out" || { cat "$TEST_ROOT/doc-out"; return 8; }

    # When completion-carapace is disabled, doctor stays quiet about Carapace symlinks.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module launch
module cwf
module completion-carapace off
EOF
    run_doctor || return 9
    ! grep -Fq 'Carapace spec' "$TEST_ROOT/doc-out" || { cat "$TEST_ROOT/doc-out"; return 10; }
  }
  It 'reports missing, broken, and conflicting managed Carapace symlinks in marksharc doctor'
    When run doctor_diagnostics_case
    The status should be success
  End

  zsh_cache_and_precedence_case() {
    render_carapace_fixture || return 1
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
module completion
module completion-carapace
module launch
module cwf
set completion-carapace.enable on
EOF
    stub_command carapace '
if [ "$1" = "_carapace" ] && [ "$2" = "zsh" ]; then
  printf "ZSH_CARAPACE_GEN\n" >> "$OPLOG"
  printf "_carapace_completer() { :; }\n"
  for c in marksharc launch-session launch-repo cwf-new; do
    case ",${CARAPACE_EXCLUDES-}," in
      *",$c,"*) ;;
      *) printf "compdef _carapace_completer %s\n" "$c" ;;
    esac
  done
fi
'
    mkdir -p "$ZDOTDIR" "$TEST_ROOT/fs"
    printf 'source "%s/core/zsh/zshenv.zsh"\n' "$MARKSHARC_ROOT" > "$ZDOTDIR/.zshenv"
    printf 'source "%s/core/zsh/zshrc.zsh"\n' "$MARKSHARC_ROOT" > "$ZDOTDIR/.zshrc"

    run_render || { cat "$TEST_ROOT/err"; return 1; }

    zsh_pty() {
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty env -i \
        HOME="$HOME" ZDOTDIR="$ZDOTDIR" PATH="$PATH" TERM=dumb \
        MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$XDG_CONFIG_HOME/marksharc" \
        MARKSHARC_HOST=carahost HOST=carahost MARKSHARC_NOTIFY=0 _ms_fs_root="$TEST_ROOT/fs" \
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
        OPLOG="$OPLOG" "$@" /bin/zsh -dic \
        'print -r -- "MS=${_comps[marksharc]-none} LR=${_comps[launch-repo]-none} CWF=${_comps[cwf-new]-none}"' \
        > "$TEST_ROOT/zout" 2>&1
    }

    # 1. Active Carapace owns all managed specs; first run generates init cache.
    : > "$OPLOG"
    zsh_pty || { cat "$TEST_ROOT/zout"; return 2; }
    grep -Fq 'MS=_carapace_completer LR=_carapace_completer CWF=_carapace_completer' "$TEST_ROOT/zout" || { cat "$TEST_ROOT/zout"; return 3; }
    [ "$(grep -c '^ZSH_CARAPACE_GEN$' "$OPLOG")" -eq 1 ] || { cat "$OPLOG"; return 4; }

    # 2. Second shell hits cache (no new carapace _carapace zsh call).
    zsh_pty || { cat "$TEST_ROOT/zout"; return 5; }
    [ "$(grep -c '^ZSH_CARAPACE_GEN$' "$OPLOG")" -eq 1 ] || { cat "$OPLOG"; return 6; }

    # 3. Changing rendered specs (disabling launch + re-render) invalidates init cache!
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
module completion
module completion-carapace
module cwf
set completion-carapace.enable on
EOF
    run_render || { cat "$TEST_ROOT/err"; return 7; }
    zsh_pty || { cat "$TEST_ROOT/zout"; return 8; }
    [ "$(grep -c '^ZSH_CARAPACE_GEN$' "$OPLOG")" -eq 2 ] || { cat "$OPLOG"; return 9; }

    # 4. CARAPACE_EXCLUDES lets native _launch-repo take over while Carapace keeps marksharc.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
module completion
module completion-carapace
module launch
module cwf
set completion-carapace.enable on
set completion-carapace.excludes "launch-repo"
EOF
    run_render || { cat "$TEST_ROOT/err"; return 10; }
    zsh_pty || { cat "$TEST_ROOT/zout"; return 11; }
    grep -Fq 'MS=_carapace_completer LR=_launch-repo CWF=_carapace_completer' "$TEST_ROOT/zout" || { cat "$TEST_ROOT/zout"; return 12; }

    # 5. Native fallback when Carapace is inactive (MARKSHARC_COMPLETION_UI=native).
    zsh_pty MARKSHARC_COMPLETION_UI=native || { cat "$TEST_ROOT/zout"; return 13; }
    grep -Fq 'MS=_marksharc LR=_launch-repo CWF=_cwf-new' "$TEST_ROOT/zout" || { cat "$TEST_ROOT/zout"; return 14; }
  }
  It 'invalidates zsh init cache on manifest changes and honors Carapace/native/CARAPACE_EXCLUDES precedence'
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run zsh_cache_and_precedence_case
    The status should be success
  End

  bash_cache_and_precedence_case() {
    render_carapace_fixture || return 1
    rm -f "$TEST_ROOT/bin/cwf"
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
module completion-carapace
module launch
module cwf
set completion-carapace.enable on
EOF
    printf '%s\n' 'source "$MARKSHARC_HOME/core/bash/bashrc.bash"' > "$HOME/.bashrc"
    stub_command carapace '
if [ "$1" = "_carapace" ] && [ "$2" = "bash" ]; then
  printf "BASH_CARAPACE_GEN\n" >> "$OPLOG"
  printf "_carapace_completer() { :; }\n"
  for c in marksharc launch-session launch-repo cwf-new; do
    case ",${CARAPACE_EXCLUDES-}," in
      *",$c,"*) ;;
      *) printf "complete -o nospace -F _carapace_completer %s\n" "$c" ;;
    esac
  done
fi
'
    run_bash_render() {
      env -i HOME="$HOME" PATH="$PATH" TERM=dumb \
        MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$XDG_CONFIG_HOME/marksharc" \
        OPLOG="$OPLOG" \
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
        "$MARKSHARC_ROOT/bin/marksharc" render > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    }

    run_bash_render || { cat "$TEST_ROOT/err"; return 1; }

    bash_pty() {
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty env -i \
        HOME="$HOME" PATH="$PATH" TERM=dumb \
        MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$XDG_CONFIG_HOME/marksharc" \
        MARKSHARC_NOTIFY=0 \
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
        OPLOG="$OPLOG" "$@" "${MARKSHARC_TEST_BASH:-bash}" -ic '
          printf "MS=%s\nLR=%s\nCWF=%s\n" \
            "$(complete -p marksharc 2>/dev/null || echo none)" \
            "$(complete -p launch-repo 2>/dev/null || echo none)" \
            "$(complete -p cwf-new 2>/dev/null || echo none)"
        ' > "$TEST_ROOT/bout" 2>&1
    }

    # 1. Active Carapace owns managed specs; native Bash completions do not override them.
    : > "$OPLOG"
    bash_pty || { cat "$TEST_ROOT/bout"; return 2; }
    grep -Fq 'MS=complete -o nospace -F _carapace_completer marksharc' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 3; }
    grep -Fq 'LR=complete -o nospace -F _carapace_completer launch-repo' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 4; }
    grep -Fq 'CWF=complete -o nospace -F _carapace_completer cwf-new' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 5; }
    [ "$(grep -c '^BASH_CARAPACE_GEN$' "$OPLOG")" -eq 1 ] || { cat "$OPLOG"; return 6; }

    # 2. Second shell hits Bash init cache.
    bash_pty || { cat "$TEST_ROOT/bout"; return 7; }
    [ "$(grep -c '^BASH_CARAPACE_GEN$' "$OPLOG")" -eq 1 ] || { cat "$OPLOG"; return 8; }

    # 3. Changing managed specs (disabling launch + re-render) invalidates Bash init cache.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
module completion-carapace
module cwf
set completion-carapace.enable on
EOF
    run_bash_render || { cat "$TEST_ROOT/err"; return 9; }
    bash_pty || { cat "$TEST_ROOT/bout"; return 10; }
    [ "$(grep -c '^BASH_CARAPACE_GEN$' "$OPLOG")" -eq 2 ] || { cat "$OPLOG"; return 11; }

    # 4. CARAPACE_EXCLUDES lets native Bash take over for excluded commands while Carapace owns the rest.
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
module completion-carapace
module launch
module cwf
set completion-carapace.enable on
set completion-carapace.excludes "launch-repo"
EOF
    run_bash_render || { cat "$TEST_ROOT/err"; return 12; }
    bash_pty || { cat "$TEST_ROOT/bout"; return 13; }
    grep -Fq 'MS=complete -o nospace -F _carapace_completer marksharc' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 14; }
    grep -Fq '_ms_complete_launch_repo launch-repo' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 15; }
    grep -Fq 'CWF=complete -o nospace -F _carapace_completer cwf-new' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 16; }

    # 5. Native fallback when Carapace is inactive (MARKSHARC_BASH_COMPLETION_UI=native).
    bash_pty MARKSHARC_BASH_COMPLETION_UI=native || { cat "$TEST_ROOT/bout"; return 17; }
    grep -Fq '_ms_complete_marksharc marksharc' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 18; }
    grep -Fq '_ms_complete_launch_repo launch-repo' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 19; }
    grep -Fq '_ms_complete_cwf_new cwf-new' "$TEST_ROOT/bout" || { cat "$TEST_ROOT/bout"; return 20; }
  }
  It 'invalidates Bash init cache on manifest changes and honors Carapace/native/CARAPACE_EXCLUDES precedence'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run bash_cache_and_precedence_case
    The status should be success
  End

  real_carapace_e2e_case() {
    render_carapace_fixture || return 1
    cache="$XDG_CACHE_HOME/marksharc/carahost"
    mkdir -p "$cache/repos" "$TEST_ROOT/workrepo"

    # Loud offline guards: ssh and hc must never be called during completion.
    stub_command ssh 'printf "FORBIDDEN ssh %s\n" "$*" >> "$OPLOG"; exit 99'
    stub_command hc 'printf "FORBIDDEN hc %s\n" "$*" >> "$OPLOG"; exit 99'

    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module launch
module cwf
module custom-mod
module completion-carapace
set completion-carapace.enable on
EOF
    printf '%s\t%s\t%s\t%s\t%s\n' \
      'alpha' '/repos/alpha' base '/repos/alpha' 'main' \
      'wt1' '/worktrees/wt1' worktree '/repos/alpha' 'feat/demo' > "$cache/repos/local.tsv"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      'api-srv' '/srv/api-srv' base '/srv/api-srv' 'main' \
      'wt-fix' '/srv/wt-fix' worktree '/srv/api-srv' 'fix/login' \
      'other-wt' '/srv/other-wt' worktree '/srv/unrelated' 'other/branch' > "$cache/repos/builder.tsv"

    "$REAL_GIT" -C "$TEST_ROOT/workrepo" init -q -b main || return 1
    "$REAL_GIT" -C "$TEST_ROOT/workrepo" -c user.name=Test -c user.email=test@example.invalid commit -qm initial --allow-empty || return 2
    "$REAL_GIT" -C "$TEST_ROOT/workrepo" branch feat/carapace-test || return 3

    # Render wires the managed symlinks into $XDG_CONFIG_HOME/carapace/specs automatically.
    run_render || { cat "$TEST_ROOT/err"; return 4; }

    run_cara() {
      env -i HOME="$HOME" PATH="$PATH:${REAL_GIT%/*}" TERM=dumb \
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        MARKSHARC_CONFIG="$XDG_CONFIG_HOME/marksharc" MARKSHARC_HOST=carahost \
        OPLOG="$OPLOG" "$REAL_CARAPACE" "$@"
    }

    # Verify Carapace discovers all four managed specs.
    list_out=$(run_cara --list) || return 5
    for cmd in marksharc launch-session launch-repo cwf-new; do
      case "$list_out" in
        *"$cmd"*) ;;
        *) printf 'MISSING FROM --list: %s\n%s\n' "$cmd" "$list_out"; return 6 ;;
      esac
    done

    # 1. marksharc: subcommands, hosts, modules, installers, update-steps
    out=$(run_cara marksharc export marksharc "") || return 10
    case "$out" in *'"messages":[]'*'"value":"doctor"'*'"value":"reload"'*) ;; *) printf 'MS_ROOT=%s\n' "$out"; return 11 ;; esac

    out=$(run_cara marksharc export marksharc hosts remove "") || return 12
    case "$out" in *'"messages":[]'*'"value":"builder"'*) ;; *) printf 'MS_HOSTS=%s\n' "$out"; return 13 ;; esac

    out=$(run_cara marksharc export marksharc module enable "") || return 14
    case "$out" in *'"messages":[]'*'"value":"custom-mod"'*) ;; *) printf 'MS_MODS=%s\n' "$out"; return 15 ;; esac

    out=$(run_cara marksharc export marksharc install "") || return 16
    case "$out" in *'"messages":[]'*'"value":"demo-tool"'*) ;; *) printf 'MS_INST=%s\n' "$out"; return 17 ;; esac

    out=$(run_cara marksharc export marksharc update --only "") || return 18
    case "$out" in *'"messages":[]'*'"value":"custom-step"'*) ;; *) printf 'MS_UPD=%s\n' "$out"; return 19 ;; esac

    # 2. launch-session: hosts, colon target with nospace, choices
    out=$(run_cara launch-session export launch-session --host "") || return 20
    case "$out" in *'"messages":[]'*'"value":"builder"'*) ;; *) printf 'LS_HOST=%s\n' "$out"; return 21 ;; esac

    out=$(run_cara launch-session export launch-session "") || return 22
    case "$out" in *'"messages":[]'*'"nospace":'*':'*'"value":"builder:"'*) ;; *) printf 'LS_TGT=%s\n' "$out"; return 23 ;; esac

    out=$(run_cara launch-session export launch-session --mux "") || return 24
    case "$out" in *'"messages":[]'*'"value":"herdr-core"'*) ;; *) printf 'LS_MUX=%s\n' "$out"; return 25 ;; esac

    # 3. launch-repo: local repos/worktrees, --base-only, remote --host/--repo/--worktree, host: target
    out=$(run_cara launch-repo export launch-repo "") || return 30
    case "$out" in *'"messages":[]'*'"value":"alpha"'*'"value":"alpha/wt1"'*) ;; *) printf 'LR_LOC=%s\n' "$out"; return 31 ;; esac

    out=$(run_cara launch-repo export launch-repo --base-only "") || return 32
    case "$out" in *'"messages":[]'*'"value":"alpha"'*) ;; *) printf 'LR_BASE=%s\n' "$out"; return 33 ;; esac
    case "$out" in *'"value":"alpha/wt1"'*) printf 'LR_BASE_LEAK=%s\n' "$out"; return 34 ;; esac

    out=$(run_cara launch-repo export launch-repo --host builder --repo "") || return 35
    case "$out" in *'"messages":[]'*'"value":"api-srv"'*) ;; *) printf 'LR_REM=%s\n' "$out"; return 36 ;; esac

    out=$(run_cara launch-repo export launch-repo --host builder --repo api-srv --worktree "") || return 37
    case "$out" in *'"messages":[]'*'"value":"fix/login"'*'"value":"wt-fix"'*) ;; *) printf 'LR_WT=%s\n' "$out"; return 38 ;; esac
    case "$out" in *'"value":"other-wt"'*) printf 'LR_WT_LEAK=%s\n' "$out"; return 39 ;; esac

    out=$(run_cara launch-repo export launch-repo "builder:") || return 40
    case "$out" in *'"messages":[]'*'"value":"builder:api-srv"'*'"value":"builder:api-srv/wt-fix"'*) ;; *) printf 'LR_COLON=%s\n' "$out"; return 41 ;; esac

    # 4. cwf-new: live git branches and remote --host/--repo
    out=$(cd "$TEST_ROOT/workrepo" && run_cara cwf-new export cwf-new "") || return 50
    case "$out" in *'"messages":[]'*'"value":"feat/carapace-test"'*) ;; *) printf 'CWF_BR=%s\n' "$out"; return 51 ;; esac

    out=$(run_cara cwf-new export cwf-new --host builder --repo "") || return 52
    case "$out" in *'"messages":[]'*'"value":"api-srv"'*) ;; *) printf 'CWF_REPO=%s\n' "$out"; return 53 ;; esac

    # 5. Fish integration: carapace _carapace fish discovers the managed symlinks.
    fish_init=$(run_cara _carapace fish) || return 60
    for cmd in marksharc launch-session launch-repo cwf-new; do
      case "$fish_init" in
        *"$cmd"*) ;;
        *) printf 'MISSING FROM fish INIT: %s\n' "$cmd"; return 61 ;;
      esac
    done

    # Offline guarantee: zero calls to ssh/hc.
    [ ! -s "$OPLOG" ] || { cat "$OPLOG"; return 70; }
  }
  It 'completes marksharc, launch-session, launch-repo, and cwf-new end-to-end via real Carapace'
    Skip if 'carapace binary is unavailable' carapace_absent
    When run real_carapace_e2e_case
    The status should be success
  End
End
