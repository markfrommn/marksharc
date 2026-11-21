# Cross-shell startup contract (spec 8), launched from POSIX sh. Today only the
# zsh core exists; the bash (P3.2) and fish (P4.1) phases add their own
# Describes here, launching core/bash and core/fish the same way.
Describe 'cross-shell contract: zsh core'
  # The suite drives the real tree: MARKSHARC_HOME is this checkout.
  zshenv_stub() {
    printf '%s\n' "export MARKSHARC_HOME=\"$MARKSHARC_ROOT\"" \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' > "$HOME/.zshenv"
  }
  # zsh_child [VAR=value ...] <zsh-args...>: hermetic child under the fixture
  # HOME; stdout lands in $TEST_ROOT/out, stderr in $TEST_ROOT/err.
  zsh_child() {
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      OPLOG="$OPLOG" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
  }

  same_env_case() {
    zshenv_stub
    ZSH=$(command -v zsh) || return 1
    last_env=
    for flags in -c -lc -ic; do
      zsh_child "$ZSH" "$flags" 'print -r -- "$MARKSHARC_ENV|$MARKSHARC_SESSION|$MARKSHARC_HOME"' || { cat "$TEST_ROOT/err"; return 1; }
      [ -s "$TEST_ROOT/err" ] && { cat "$TEST_ROOT/err"; return 2; }
      out=$(cat "$TEST_ROOT/out")
      env_id=${out%%|*}
      [ -n "$env_id" ] || { printf 'empty MARKSHARC_ENV in %s\n' "$out"; return 3; }
      [ "${out#*|}" = "batch|$MARKSHARC_ROOT" ] || { printf 'got %s\n' "$out"; return 4; }
      if [ -n "$last_env" ] && [ "$env_id" != "$last_env" ]; then
        printf 'env id changed across modes: %s then %s\n' "$last_env" "$env_id"
        return 5
      fi
      last_env=$env_id
    done
  }
  It 'keeps batch, login and non-tty interactive shells silent on the same environment'
    When run same_env_case
    The status should be success
  End

  agent_case() {
    zshenv_stub
    ZSH=$(command -v zsh) || return 1
    for marker in CLAUDECODE=1 AI_AGENT=claude; do
      for flags in -c -ic; do
        zsh_child "$marker" "$ZSH" "$flags" 'print -r -- "$MARKSHARC_SESSION"' || { cat "$TEST_ROOT/err"; return 1; }
        [ -s "$TEST_ROOT/err" ] && { cat "$TEST_ROOT/err"; return 2; }
        [ "$(cat "$TEST_ROOT/out")" = agent ] || { printf '%s %s: got %s\n' "$marker" "$flags" "$(cat "$TEST_ROOT/out")"; return 3; }
      done
    done
  }
  It 'keeps every agent-marked mode silent and classified agent'
    When run agent_case
    The status should be success
  End

  resource_case() {
    zshenv_stub
    ZSH=$(command -v zsh) || return 1
    zsh_child "$ZSH" -c 'before=$PATH; source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; [ "$PATH" = "$before" ] && print steady' || { cat "$TEST_ROOT/err"; return 1; }
    [ -s "$TEST_ROOT/err" ] && { cat "$TEST_ROOT/err"; return 2; }
    [ "$(cat "$TEST_ROOT/out")" = steady ] || { cat "$TEST_ROOT/out"; return 3; }
  }
  It 'changes nothing when the env phase is re-sourced'
    When run resource_case
    The status should be success
  End

  writes_case() {
    zshenv_stub
    ZSH=$(command -v zsh) || return 1
    stamp="$TEST_ROOT/stamp"
    : > "$stamp"
    sleep 1
    for flags in -c -lc -ic; do
      zsh_child "$ZSH" "$flags" ':' || { cat "$TEST_ROOT/err"; return 1; }
      [ -s "$TEST_ROOT/err" ] && { cat "$TEST_ROOT/err"; return 2; }
    done
    # The framework checkout is never written to at run time.
    newer=$(find "$MARKSHARC_ROOT" -newer "$stamp" -not -path '*/.git/*' -not -name .git -print)
    [ -z "$newer" ] || { printf 'repo writes:\n%s\n' "$newer"; return 3; }
    # Inside HOME the only files are the stub and the XDG cache/state content.
    stray=$(find "$HOME" -type f -not -name .zshenv \
      -not -path "$HOME/config/*" -not -path "$HOME/cache/*" \
      -not -path "$HOME/data/*" -not -path "$HOME/state/*" -print)
    [ -z "$stray" ] || { printf 'stray HOME writes:\n%s\n' "$stray"; return 4; }
    # The login/interactive runs generated the ZDOTDIR under the state dir.
    [ -f "$XDG_STATE_HOME/marksharc/zdot/.zshrc" ] || return 5
  }
  It 'writes only inside the cache and state directories'
    When run writes_case
    The status should be success
  End
End
