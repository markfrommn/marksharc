# Native Zsh PTY completion specs for rendered marksharc CLI completions
# (COMPLETION-SPEC sections 5.2, 7.1, 8).
Describe 'marksharc completion'
  marksharc_completion_case() {
    emulate -L zsh
    mkdir -p "$HOME/config/modules/custom-mod"
    cat > "$HOME/config/config.conf" <<'EOF'
module launch
module custom-mod
EOF
    cat > "$HOME/config/hosts.conf" <<'EOF'
host alpha ops@alpha
host beta ops@beta
EOF
    cat > "$HOME/config/modules/custom-mod/module.conf" <<'EOF'
describe "Custom overlay module"
installer demo-tool ./install.sh
update custom-step echo ok
EOF
    printf '#!/bin/sh\nexit 0\n' > "$HOME/config/modules/custom-mod/install.sh"
    chmod +x "$HOME/config/modules/custom-mod/install.sh"

    HOST=test MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" MARKSHARC_HOST=test \
      XDG_CACHE_HOME="$HOME/.cache" "$MARKSHARC_ROOT/bin/marksharc" render >/dev/null || return 1

    cat > "$HOME/.zshrc" <<'DATA'
fpath=( "$XDG_CACHE_HOME/marksharc/test/completions/zsh" $fpath )
autoload -Uz compinit
compinit -i -D
marksharc() { printf '%s\n' "$*" >> "$OPLOG"; }
DATA

    local typed=$'marksharc --ver\t\nmarksharc relo\t --ver\t\nmarksharc sync ti\t st\t\nmarksharc hosts po\t --source h\t\nmarksharc hosts re\t al\t\nmarksharc hosts he\t\nmarksharc module en\t custom-\t\nmarksharc inst\t demo-\t\nmarksharc upda\t --only custom-\t\nmarksharc push be\t\nmarksharc doctor --ver\t\nexit\n'
    PTY_INPUT=$typed ms_pty MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" \
      MARKSHARC_HOST=test XDG_CACHE_HOME="$HOME/.cache" -di || { cat "$TEST_ROOT/out"; return 1; }
    local expected=$'--version\nreload --verbose\nsync timer status\nhosts populate --source hc\nhosts remove alpha\nhosts help\nmodule enable custom-mod\ninstall demo-tool\nupdate --only custom-step\npush beta\ndoctor --ver'
    [[ $(<"$OPLOG") == "$expected" ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
  }
  It 'completes root flags, subcommand hierarchy, choices, and dynamic modules, hosts, installers, and update steps without leaking root flags'
    When run marksharc_completion_case
    The status should be success
  End
End
