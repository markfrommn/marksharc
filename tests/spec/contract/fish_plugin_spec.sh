Describe 'fish plugin loading'
  plugin_case() {
    root="$XDG_CACHE_HOME/marksharc/plugins/example@123"
    mkdir -p "$root/functions" "$root/completions" "$root/conf.d"
    printf 'set -g PLUGIN_LOADED yes\n' > "$root/conf.d/example.fish"
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/plugins.fish"
      _ms_fish_plugin_load example 123
      _ms_fish_plugin_load example 123
      _ms_fish_plugin_load missing 456
      test "$PLUGIN_LOADED" = yes
      and test (count (contains -i -- "$XDG_CACHE_HOME/marksharc/plugins/example@123/functions" $fish_function_path)) -eq 1
      and contains -- "$XDG_CACHE_HOME/marksharc/plugins/example@123/completions" $fish_complete_path
    '
  }
  It 'loads cached plugin paths and hooks idempotently and skips missing clones'
    When run plugin_case
    The status should be success
  End

  generated_plugin_case() {
    sha=85cadd56f71b11574566dbd6c32e0027e361d085
    root="$XDG_CACHE_HOME/marksharc/plugins/nvm.fish@$sha"
    mkdir -p "$root/conf.d" "$XDG_CONFIG_HOME/marksharc"
    printf 'set -g FISH_PLUGIN_ACTIVATED yes\n' > "$root/conf.d/test.fish"
    printf 'module path\nmodule node-nvm\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    host=$(hostname)
    host=${host%%.*}
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/path.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/modules.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/plugins.fish"
      set MARKSHARC_SESSION batch
      source "$argv[1]"
      not set -q FISH_PLUGIN_ACTIVATED; or exit 2
      set MARKSHARC_SESSION interactive
      source "$argv[1]"
      test "$FISH_PLUGIN_ACTIVATED" = yes
    ' "$XDG_CACHE_HOME/marksharc/$host/env.fish"
  }
  It 'loads enabled fish plugin pins only during an interactive session'
    When run generated_plugin_case
    The status should be success
  End

  module_init_case() {
    root="$XDG_CONFIG_HOME/marksharc"
    mkdir -p "$root/modules/demo/functions/fish" "$root/modules/demo/completions/fish" "$root/local"
    printf 'describe demo\n' > "$root/modules/demo/module.conf"
    printf 'set -g MODULE_INIT_VALUE yes\n' > "$root/modules/demo/init.fish"
    printf 'function example_hello; echo hello; end\n' > "$root/modules/demo/functions/fish/example_hello.fish"
    printf 'set -g POST_INIT_VALUE yes\n' > "$root/local/post.fish"
    printf 'module path\nmodule demo\n' > "$root/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    host=$(hostname)
    host=${host%%.*}
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/path.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/modules.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/plugins.fish"
      set MARKSHARC_SESSION interactive
      source "$argv[1]"
      test "$MODULE_INIT_VALUE" = yes
      and test "$POST_INIT_VALUE" = yes
      and test (example_hello) = hello
      and contains -- "$XDG_CONFIG_HOME/marksharc/modules/demo/completions/fish" $fish_complete_path
    ' "$XDG_CACHE_HOME/marksharc/$host/env.fish"
  }
  It 'loads enabled native fish module setup, functions, completions and post hook'
    When run module_init_case
    The status should be success
  End

  requirements_case() {
    root="$XDG_CONFIG_HOME/marksharc"
    mkdir -p "$root/modules/early" "$root/modules/ready/bin" "$root/modules/blocked/bin" "$HOME/toolbin"
    printf '#!/bin/sh\nexit 0\n' > "$HOME/toolbin/demo-ready"
    chmod +x "$HOME/toolbin/demo-ready"
    printf 'describe early\norder 20\npath user "$HOME/toolbin"\n' > "$root/modules/early/module.conf"
    printf 'describe ready\norder 30\nrequires command demo-ready\n' > "$root/modules/ready/module.conf"
    printf 'set -gx NATIVE_ENV_FISH yes\n' > "$root/modules/ready/env.fish"
    printf 'set -g READY_INIT yes\n' > "$root/modules/ready/init.fish"
    printf 'describe blocked\norder 40\nrequires command ms_missing_fixture_command\n' > "$root/modules/blocked/module.conf"
    printf 'set -g BLOCKED_INIT yes\n' > "$root/modules/blocked/init.fish"
    printf 'module path\nmodule early\nmodule ready\nmodule blocked\n' > "$root/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    host=$(hostname)
    host=${host%%.*}
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/path.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/modules.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/plugins.fish"
      set -g MARKSHARC_HOME "$MARKSHARC_ROOT"
      set -g MARKSHARC_SESSION interactive
      source "$argv[1]"
      test "$NATIVE_ENV_FISH" = yes; and test "$READY_INIT" = yes
      and not set -q BLOCKED_INIT
      and contains -- "$XDG_CONFIG_HOME/marksharc/modules/ready/bin" $PATH
      and not contains -- "$XDG_CONFIG_HOME/marksharc/modules/blocked/bin" $PATH
    ' "$XDG_CACHE_HOME/marksharc/$host/env.fish"
  }
  It 'honors command requirements and loads native fish environment at each module turn'
    When run requirements_case
    The status should be success
  End
End
