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

  login_case() {
    # Capture the system profile's PATH before installing either user stub.
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb /bin/bash -lc \
      '[ "$HOME" = "$1" ] || exit 9; printf "%s\n" "$PATH"' bash "$HOME" \
      >"$TEST_ROOT/login-path" 2>"$TEST_ROOT/err" || return 1
    [ ! -s "$TEST_ROOT/err" ] || return 2
    login_path=$(cat "$TEST_ROOT/login-path")
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'env LOGIN_TEST "shell parity"' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    inst --home "$MARKSHARC_ROOT" --no-plugins || { cat "$TEST_ROOT/err"; return 3; }
    env -i HOME="$HOME" PATH="$login_path" TERM=dumb XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" \
      zsh -lc 'printf "%s\n%s\n" "$PATH" "$LOGIN_TEST"' >"$TEST_ROOT/zsh" 2>"$TEST_ROOT/err" || return 4
    [ ! -s "$TEST_ROOT/err" ] || return 5
    env -i HOME="$HOME" PATH="$login_path" TERM=dumb XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" \
      /bin/bash -lc 'printf "%s\n%s\n" "$PATH" "$LOGIN_TEST"' >"$TEST_ROOT/bash" 2>"$TEST_ROOT/err" || return 6
    [ ! -s "$TEST_ROOT/err" ] || return 7
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash" || { cat "$TEST_ROOT/zsh" "$TEST_ROOT/bash"; return 8; }
  }
  It 'matches zsh PATH and exports through the installed Bash login profile'
    When run login_case
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
    mkdir -p "$HOME/.bun" "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'set agent.bash_env on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
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

  git_worktree_options_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'set git-worktree.roots ~/repositories' 'set git-worktree.orgs alpha beta' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c \
      'env | grep -Fx "_ms_opt_git_worktree_roots=$HOME/repositories" >/dev/null && env | grep -Fx "_ms_opt_git_worktree_orgs=alpha beta" >/dev/null' \
      >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || return 1
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'exports git-worktree options to child commands from Bash'
    When run git_worktree_options_case
    The status should be success
  End

  bash_hook_toggle_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf '%s\n' 'set agent.bash_env on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    : > "$TEST_ROOT/foreign-hook"
    env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      TEST_ROOT="$TEST_ROOT" BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c '
        [ "$BASH_ENV" = "$MARKSHARC_HOME/core/bash/env.bash" ] || exit 1
        sleep 1
        printf "%s\n" "set agent.bash_env off" > "$XDG_CONFIG_HOME/marksharc/config.conf"
        source "$MARKSHARC_HOME/core/bash/env.bash"
        [ -z "${BASH_ENV+x}" ] || exit 2
        export BASH_ENV="$TEST_ROOT/foreign-hook"
        source "$MARKSHARC_HOME/core/bash/env.bash"
        [ "$BASH_ENV" = "$TEST_ROOT/foreign-hook" ] || exit 3
      ' >"$TEST_ROOT/out" 2>"$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'removes only the owned Bash hook when its option is switched off'
    When run bash_hook_toggle_case
    The status should be success
  End

  mise_contract_fixture() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/.nvm/alias" \
      "$HOME/.nvm/versions/node/v22.1.0/bin" "$HOME/.gvm/environments" \
      "$HOME/.gvm/gos/go1.23.0/bin" "$HOME/.pyenv/bin" "$HOME/.pyenv/shims" \
      "$TEST_ROOT/homebrew/bin"
    printf '22\n' > "$HOME/.nvm/alias/default"
    printf 'gvm_go_name=go1.23.0\n' > "$HOME/.gvm/environments/default"
    printf '#!/bin/sh\nexit 0\n' > "$HOME/.gvm/gos/go1.23.0/bin/go"
    printf '#!/bin/sh\nexit 0\n' > "$HOME/.pyenv/bin/pyenv"
    chmod +x "$HOME/.gvm/gos/go1.23.0/bin/go" "$HOME/.pyenv/bin/pyenv"
    MISE_DATA_DIR="$TEST_ROOT/mise data"
    export MISE_DATA_DIR GOPATH="$HOME/.gvm/pkgsets/go1.23.0/global" GVM_OVERLAY_PREFIX="$GOPATH/overlay" gvm_go_name=go1.23.0 gvm_pkgset_name=global
    mkdir -p "$MISE_DATA_DIR/shims"
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
module mise
module node-nvm
module go-gvm
module python
set mise.tools "node go python"
EOF
    printf 'path brew "%s"\n' "$TEST_ROOT/homebrew/bin" >> "$XDG_CONFIG_HOME/marksharc/config.conf"
    stub_command mise 'printf "unexpected %s\n" "$*" >> "$OPLOG"; exit 99'
    initial_path="$TEST_ROOT/bin:$HOME/.nvm/versions/node/v22.1.0/bin:$HOME/.gvm/gos/go1.23.0/bin:$HOME/.pyenv/shims:$PATH"
  }

  run_mise_zsh() {
    env -i HOME="$HOME" PATH="$initial_path" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      MISE_DATA_DIR="$MISE_DATA_DIR" GOPATH="$GOPATH" GVM_OVERLAY_PREFIX="$GVM_OVERLAY_PREFIX" gvm_go_name="$gvm_go_name" gvm_pkgset_name="$gvm_pkgset_name" MARKSHARC_HOME="$MARKSHARC_ROOT" OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT" \
      zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$PATH" "$MISE_NOT_FOUND_AUTO_INSTALL" "$MISE_GO_SET_GOBIN" "$MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS" "${PYENV_ROOT-unset}" "${GOPATH-unset}" "${GVM_OVERLAY_PREFIX-unset}"' \
      > "$TEST_ROOT/zsh" 2> "$TEST_ROOT/err"
  }

  run_mise_bash() {
    env -i HOME="$HOME" PATH="$initial_path" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      MISE_DATA_DIR="$MISE_DATA_DIR" GOPATH="$GOPATH" GVM_OVERLAY_PREFIX="$GVM_OVERLAY_PREFIX" gvm_go_name="$gvm_go_name" gvm_pkgset_name="$gvm_pkgset_name" MARKSHARC_HOME="$MARKSHARC_ROOT" OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" \
      /bin/bash -c 'printf "%s\n%s\n%s\n%s\n%s\n%s\n%s\n" "$PATH" "$MISE_NOT_FOUND_AUTO_INSTALL" "$MISE_GO_SET_GOBIN" "$MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS" "${PYENV_ROOT-unset}" "${GOPATH-unset}" "${GVM_OVERLAY_PREFIX-unset}"' \
      > "$TEST_ROOT/bash" 2> "$TEST_ROOT/err"
  }

  mise_case() {
    mise_contract_fixture
    run_mise_zsh || { cat "$TEST_ROOT/err"; return 1; }
    run_mise_bash || { cat "$TEST_ROOT/err"; return 2; }
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash" || { cat "$TEST_ROOT/zsh" "$TEST_ROOT/bash"; return 3; }
    grep -F "$MISE_DATA_DIR/shims" "$TEST_ROOT/bash" >/dev/null || return 4
    grep -F 'false' "$TEST_ROOT/bash" >/dev/null || return 5
    grep -F 'node,go,python' "$TEST_ROOT/bash" >/dev/null || return 6
    tail -n 2 "$TEST_ROOT/bash" | head -n 1 | grep -Fx 'unset' >/dev/null || return 7
    if grep -F "$HOME/.nvm" "$TEST_ROOT/bash" >/dev/null ||
       grep -F "$HOME/.gvm" "$TEST_ROOT/bash" >/dev/null ||
       grep -F "$HOME/.pyenv" "$TEST_ROOT/bash" >/dev/null; then
      cat "$TEST_ROOT/bash"; return 8
    fi
    [ ! -s "$OPLOG" ] || return 9
    GOPATH="$HOME/.gvm/pkgsets/go1.23.0/global:$TEST_ROOT/custom go"
    GVM_OVERLAY_PREFIX="$HOME/.gvm/pkgsets/go1.23.0/global/overlay"
    run_mise_zsh || { cat "$TEST_ROOT/err"; return 10; }
    run_mise_bash || { cat "$TEST_ROOT/err"; return 11; }
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash" || { cat "$TEST_ROOT/zsh" "$TEST_ROOT/bash"; return 12; }
    tail -n 2 "$TEST_ROOT/bash" | head -n 1 | grep -Fx "$TEST_ROOT/custom go" >/dev/null || return 13
    tail -n 1 "$TEST_ROOT/bash" | grep -Fx 'unset' >/dev/null || return 14
  }
  It 'matches zsh mise shims, safe exports, and owned-only legacy path removal in Bash'
    When run mise_case
    The status should be success
  End

  mise_fallback_case() {
    mise_contract_fixture
    rm "$TEST_ROOT/bin/mise"
    initial_path="$MISE_DATA_DIR/shims:$initial_path"
    run_mise_zsh || { cat "$TEST_ROOT/err"; return 1; }
    run_mise_bash || { cat "$TEST_ROOT/err"; return 2; }
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash" || { cat "$TEST_ROOT/zsh" "$TEST_ROOT/bash"; return 3; }
    grep -F "$HOME/.nvm/versions/node/v22.1.0/bin" "$TEST_ROOT/bash" >/dev/null || return 4
    grep -F "$HOME/.gvm/gos/go1.23.0/bin" "$TEST_ROOT/bash" >/dev/null || return 5
    grep -F "$HOME/.pyenv/shims" "$TEST_ROOT/bash" >/dev/null || return 6
    if grep -F "$MISE_DATA_DIR/shims" "$TEST_ROOT/bash" >/dev/null; then return 7; fi
  }
  It 'matches the complete legacy Bash fallback when configured mise is missing'
    When run mise_fallback_case
    The status should be success
  End

  mise_child_fallback_case() {
    mise_contract_fixture
    env -i HOME="$HOME" PATH="$initial_path" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" \
      XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      MISE_DATA_DIR="$MISE_DATA_DIR" MISE_SHELL=zsh MISE_NODE_VERSION=20 __MISE_ORIG_PATH=/stale __MISE_SESSION=stub __MISE_DIFF=stub MARKSHARC_HOME="$MARKSHARC_ROOT" OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" \
      zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "module path\nmodule mise\nmodule node-nvm\nmodule go-gvm\nmodule python\nset mise.tools \"\"\n" > "$XDG_CONFIG_HOME/marksharc/config.conf"; /bin/bash -c '\''printf "%s\n%s\n%s\n%s\n" "$PATH" "${MISE_NOT_FOUND_AUTO_INSTALL-unset}" "${MISE_SHELL-unset}" "${MISE_NODE_VERSION-unset}"'\' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    grep -F "$HOME/.nvm/versions/node/v22.1.0/bin" "$TEST_ROOT/out" >/dev/null || return 2
    grep -F "$HOME/.gvm/gos/go1.23.0/bin" "$TEST_ROOT/out" >/dev/null || return 3
    grep -F "$HOME/.pyenv/shims" "$TEST_ROOT/out" >/dev/null || return 4
    if grep -F "$MISE_DATA_DIR/shims" "$TEST_ROOT/out" >/dev/null; then return 5; fi
    tail -n 1 "$TEST_ROOT/out" | grep -Fx 'unset' >/dev/null || return 6
    tail -n 2 "$TEST_ROOT/out" | head -n 1 | grep -Fx 'unset' >/dev/null || return 7
    tail -n 3 "$TEST_ROOT/out" | head -n 1 | grep -Fx 'unset' >/dev/null
  }
  It 'drops inherited shims and settings when a Bash child has empty tools'
    When run mise_child_fallback_case
    The status should be success
  End

  first_inherited_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/first" "$HOME/virtualenv" "$HOME/manager"
    printf '%s\n' 'path first ~/first' 'path manager ~/manager' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    initial_path="$HOME/first:$HOME/virtualenv:/bin:/usr/bin"
    env -i HOME="$HOME" PATH="$initial_path" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; printf "%s\n" "$PATH"' >"$TEST_ROOT/zsh" || return 1
    env -i HOME="$HOME" PATH="$initial_path" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" /bin/bash -c 'printf "%s\n" "$PATH"' >"$TEST_ROOT/bash" || return 2
    case $(cat "$TEST_ROOT/bash") in "$HOME/first:$HOME/virtualenv:$HOME/manager:"*) ;; *) return 3 ;; esac
    cmp -s "$TEST_ROOT/zsh" "$TEST_ROOT/bash"
  }
  It 'keeps inherited virtualenv entries between first and manager tiers'
    When run first_inherited_case
    The status should be success
  End
End
