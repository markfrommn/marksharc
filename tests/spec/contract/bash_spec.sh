Describe 'cross-shell contract: bash core'
  bash_artifact_case() {
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 1
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ] || return 2
    found=$(find "$XDG_CACHE_HOME/marksharc" -name env.bash -type f)
    [ -n "$found" ] || { printf 'missing rendered env.bash\n'; return 3; }
    /bin/bash -n "$found"
  }
  It 'renders a syntactically valid Bash environment silently'
    When run bash_artifact_case
    The status should be success
  End

  bash_parity_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/custom bin"
    printf '%s\n' 'env TEST_EXPORT "value with spaces"' 'path user "$HOME/custom bin"' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "%s\n%s\n" "$PATH" "$TEST_EXPORT"' >"$TEST_ROOT/zsh" 2>"$TEST_ROOT/err" || return 1
    [ ! -s "$TEST_ROOT/err" ] || return 2
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" \
      /bin/bash -c 'printf "%s\n%s\n" "$PATH" "$TEST_EXPORT"' >"$TEST_ROOT/bash" 2>"$TEST_ROOT/err" || return 3
    [ ! -s "$TEST_ROOT/err" ] || { cat "$TEST_ROOT/err"; return 4; }
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash" || { cat "$TEST_ROOT/zsh" "$TEST_ROOT/bash"; return 5; }
  }
  It 'applies the same ordered PATH and overlay exports to Bash and zsh'
    When run bash_parity_case
    The status should be success
  End

  custom_tier_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/custom-tier"
    printf '%s\n' 'tiers "user custom"' 'path custom ~/custom-tier' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "%s\n" "$PATH"' >"$TEST_ROOT/zsh" || return 1
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c 'printf "%s\n" "$PATH"' >"$TEST_ROOT/bash" || return 2
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash"
  }
  It 'preserves custom PATH tiers in the configured order'
    When run custom_tier_case
    The status should be success
  End

  late_guard_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'env LATE_VALUE ready when dir ~/late' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' || return 1
    mkdir "$HOME/late"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" \
      /bin/bash -c '[ "$LATE_VALUE" = ready ]' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 2
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'evaluates a directory guard after rendering without output'
    When run late_guard_case
    The status should be success
  End

  nvm_case() {
    mkdir -p "$HOME/.nvm/alias" "$HOME/.nvm/versions/node/v20.9.0/bin" "$HOME/.nvm/versions/node/v20.10.0/bin"
    printf '%s\n' 20 > "$HOME/.nvm/alias/default"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "%s\n" "$PATH"' >"$TEST_ROOT/zsh" 2>"$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" \
      /bin/bash -c 'printf "%s\n" "$PATH"' >"$TEST_ROOT/bash" || return 2
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash"
  }
  It 'selects the same numeric default nvm version as zsh'
    When run nvm_case
    The status should be success
  End

  gvm_case() {
    mkdir -p "$HOME/.gvm/environments" "$HOME/.gvm/gos/go1.23/bin"
    printf '%s\n' 'gvm_go_name=go1.23' > "$HOME/.gvm/environments/default"
    printf '%s\n' '#!/bin/sh' > "$HOME/.gvm/gos/go1.23/bin/go"
    chmod +x "$HOME/.gvm/gos/go1.23/bin/go"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "%s\n%s\n" "$PATH" "$GOROOT"' >"$TEST_ROOT/zsh" || return 1
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" \
      /bin/bash -c 'printf "%s\n%s\n" "$PATH" "$GOROOT"' >"$TEST_ROOT/bash" || return 2
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash"
  }
  It 'matches the selected gvm PATH and GOROOT'
    When run gvm_case
    The status should be success
  End

  interactive_gvm_case() {
    [ -n "$PYTHON" ] || return 0
    mkdir -p "$HOME/.gvm/environments" "$HOME/.gvm/gos/go1.23/bin"
    printf '%s\n' 'gvm_go_name=go1.23' > "$HOME/.gvm/environments/default"
    printf '%s\n' '#!/bin/sh' > "$HOME/.gvm/gos/go1.23/bin/go"
    chmod +x "$HOME/.gvm/gos/go1.23/bin/go"
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty \
      /bin/bash --noprofile --rcfile "$MARKSHARC_ROOT/core/bash/bashrc.bash" -ic \
      'printf "session=%s\npath=%s\n" "$MARKSHARC_SESSION" "$PATH"' >"$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
    grep -q 'session=interactive' "$TEST_ROOT/out" || return 2
    grep -Fq "$HOME/.gvm/pkgsets/go1.23/global/bin:$HOME/.gvm/gos/go1.23/bin:$HOME/.gvm/pkgsets/go1.23/global/overlay/bin" "$TEST_ROOT/out"
  }
  It 'keeps the interactive gvm entries in order even before the pkgset exists'
    When run interactive_gvm_case
    The status should be success
  End

  missing_cache_case() {
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" \
      /bin/bash -c 'command -v marksharc >/dev/null' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 1
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'recovers a missing rendered environment for a Bash child'
    When run missing_cache_case
    The status should be success
  End

  deleted_artifact_case() {
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' || return 1
    artifact=$(find "$XDG_CACHE_HOME/marksharc" -name env.bash -type f)
    rm "$artifact"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" \
      /bin/bash -c 'command -v marksharc >/dev/null' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 2
    [ -s "$artifact" ] && [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'recovers a deleted Bash artifact when the zsh cache still exists'
    When run deleted_artifact_case
    The status should be success
  End

  damaged_context_case() {
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' || return 1
    context=$(find "$XDG_CACHE_HOME/marksharc" -name bash-context -type f)
    printf 'incomplete\n' > "$context"
    render_id=$(cat "${context%/*}/render-id")
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_ENV="$render_id" BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c ':' || return 2
    [ "$(wc -l < "$context" | tr -d ' ')" = 4 ]
  }
  It 'recovers an incomplete Bash cache context'
    When run damaged_context_case
    The status should be success
  End

  mismatched_artifact_case() {
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' || return 1
    artifact=$(find "$XDG_CACHE_HOME/marksharc" -name env.bash -type f)
    printf '%s\n' '# Generated by marksharc render; do not edit.' '# render id: other' 'export WRONG_ARTIFACT=1' > "$artifact"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c '[ -z "${WRONG_ARTIFACT-}" ]' || return 2
    ! grep -q WRONG_ARTIFACT "$artifact"
  }
  It 'recovers an artifact whose render ID does not match its context'
    When run mismatched_artifact_case
    The status should be success
  End

  isolated_hook_case() {
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c \
      '[ "$MARKSHARC_HOME" = "$1" ] && command -v marksharc >/dev/null' bash "$MARKSHARC_ROOT" \
      >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 1
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'loads the hook without inherited MarkSharc variables'
    When run isolated_hook_case
    The status should be success
  End

  stale_config_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'env TEST_VERSION first' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' || return 1
    sleep 1
    printf '%s\n' 'env TEST_VERSION second-value' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c \
      '[ "$TEST_VERSION" = second-value ]' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 2
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'refreshes Bash environment after configuration changes'
    When run stale_config_case
    The status should be success
  End

  switched_config_case() {
    mkdir -p "$TEST_ROOT/overlay-one" "$TEST_ROOT/overlay-two"
    printf '%s\n' 'env TEST_VERSION one' > "$TEST_ROOT/overlay-one/config.conf"
    printf '%s\n' 'env TEST_VERSION two' > "$TEST_ROOT/overlay-two/config.conf"
    env -i HOME="$HOME" PATH="$PATH" MARKSHARC_CONFIG="$TEST_ROOT/overlay-one" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' || return 1
    env -i HOME="$HOME" PATH="$PATH" MARKSHARC_CONFIG="$TEST_ROOT/overlay-two" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c '[ "$TEST_VERSION" = two ]' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 2
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'refreshes when a different overlay is selected'
    When run switched_config_case
    The status should be success
  End

  failed_refresh_case() {
    mkdir -p "$TEST_ROOT/overlay-one" "$TEST_ROOT/overlay-two" "$TEST_ROOT/empty-bin"
    printf '%s\n' 'env TEST_VERSION one' > "$TEST_ROOT/overlay-one/config.conf"
    printf '%s\n' 'env TEST_VERSION two' > "$TEST_ROOT/overlay-two/config.conf"
    env -i HOME="$HOME" PATH="$PATH" MARKSHARC_CONFIG="$TEST_ROOT/overlay-one" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' || return 1
    env -i HOME="$HOME" PATH="$TEST_ROOT/empty-bin" MARKSHARC_CONFIG="$TEST_ROOT/overlay-two" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c '[ -z "${TEST_VERSION-}" ]' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 2
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'does not apply another overlay after cache refresh fails'
    When run failed_refresh_case
    The status should be success
  End

  pending_command_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/pre" "$XDG_CONFIG_HOME/marksharc/modules/dependent/bin" "$HOME/earlier"
    printf '%s\n' 'order 9' 'path user ~/earlier' > "$XDG_CONFIG_HOME/marksharc/modules/pre/module.conf"
    printf '%s\n' 'order 50' 'requires command fixture-command' > "$XDG_CONFIG_HOME/marksharc/modules/dependent/module.conf"
    printf '%s\n' '#!/bin/sh' > "$HOME/earlier/fixture-command"
    chmod +x "$HOME/earlier/fixture-command"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "%s\n" "$PATH"' >"$TEST_ROOT/zsh" || return 1
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c 'printf "%s\n" "$PATH"' >"$TEST_ROOT/bash" || return 2
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash"
  }
  It 'finds a required command in an earlier PATH tier'
    When run pending_command_case
    The status should be success
  End

  late_module_bin_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/early/bin" "$XDG_CONFIG_HOME/marksharc/modules/late" "$HOME/later"
    printf '%s\n' 'order 9' 'requires command late-command' > "$XDG_CONFIG_HOME/marksharc/modules/early/module.conf"
    printf '%s\n' 'order 50' 'path user ~/later' > "$XDG_CONFIG_HOME/marksharc/modules/late/module.conf"
    printf '%s\n' '#!/bin/sh' > "$HOME/later/late-command"
    chmod +x "$HOME/later/late-command"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "%s\n" "$PATH"' >"$TEST_ROOT/zsh" || return 1
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c 'printf "%s\n" "$PATH"' >"$TEST_ROOT/bash" || return 2
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash"
  }
  It 'rechecks module executable directories after later path contributions'
    When run late_module_bin_case
    The status should be success
  End

  native_module_case() {
    module=$XDG_CONFIG_HOME/marksharc/modules/private-example
    mkdir -p "$module" "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'order 40' 'option value default description' > "$module/module.conf"
    printf '%s\n' 'export PRIVATE_VALUE=$_ms_opt_private_example_value' > "$module/env.bash"
    printf '%s\n' 'set private-example.value configured' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c '[ "$PRIVATE_VALUE" = configured ]' || return 1
  }
  It 'loads a private native Bash environment module with its configured option'
    When run native_module_case
    The status should be success
  End

  overridden_module_case() {
    module=$XDG_CONFIG_HOME/marksharc/modules/node-nvm
    mkdir -p "$module"
    printf '%s\n' 'order 30' > "$module/module.conf"
    printf '%s\n' 'export CUSTOM_NODE=enabled' > "$module/env.bash"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c \
      '[ "$CUSTOM_NODE" = enabled ] && [ -z "${NVM_DIR-}" ]'
  }
  It 'uses the private module in place of the public native implementation'
    When run overridden_module_case
    The status should be success
  End

  agent_option_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'set agent.bash_env on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- ${BASH_ENV-unset}' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 1
    [ "$(cat "$TEST_ROOT/out")" = "$MARKSHARC_ROOT/core/bash/env.bash" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'exports the Bash hook from zsh when agent.bash_env is enabled'
    When run agent_option_case
    The status should be success
  End

  session_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'set agent.markers CUSTOM_AGENT' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      CUSTOM_AGENT=1 BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c \
      '[ "$MARKSHARC_SESSION" = agent ] && ! env | grep -q "^MARKSHARC_SESSION="' || return 1
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      CLAUDECODE=1 BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c \
      '[ "$MARKSHARC_SESSION" = batch ]' || return 2
  }
  It 'classifies configured agent markers as a shell-local fact'
    When run session_case
    The status should be success
  End

  inherited_case() {
    mkdir -p "$HOME/.bun"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c \
      'export PATH="$PATH:/manual"; export BUN_INSTALL=retained; CODEX_SESSION_ID=1 /bin/bash -c '\''[[ $PATH == *:/manual && $BUN_INSTALL == retained && $MARKSHARC_SESSION == agent ]]'\''' \
      >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 1
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'preserves inherited environment while reclassifying a nonlogin child'
    When run inherited_case
    The status should be success
  End
End
