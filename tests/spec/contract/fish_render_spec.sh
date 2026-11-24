Describe 'fish rendered environment'
  rendered_env_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/guard dir"
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
env FISH_RENDER_VALUE 'literal $(touch hostile) \ backslash' when dir "$HOME/guard dir"
EOF
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    host=$(hostname)
    host=${host%%.*}
    cache="$XDG_CACHE_HOME/marksharc/$host"
    [ -r "$cache/env.fish" ] || return 2
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/path.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/modules.fish"
      source "$argv[1]"; or exit 5
      test "$FISH_RENDER_VALUE" = "$argv[2]"
      and not test -e hostile
    ' "$cache/env.fish" 'literal $(touch hostile) \ backslash' || { cat "$cache/env.fish"; return 3; }
  }
  It 'emits native fish for guarded literal environment values'
    When run rendered_env_case
    The status should be success
  End

  fish_startup_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf 'module path\nenv FISH_STARTUP yes\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 fish --no-config -c '
      source "$MARKSHARC_HOME/core/fish/marksharc.fish"
      test "$MARKSHARC_SESSION" = batch
      and test "$FISH_STARTUP" = yes
      or exit 3
      set -l before (string join : $PATH)
      source "$MARKSHARC_HOME/core/fish/marksharc.fish"
      test "$PATH" = "$before"; or begin; printf "before=%s\nafter=%s\n" "$before" "$PATH" >&2; exit 1; end
    ' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'loads the rendered environment quietly and idempotently in a batch shell'
    When run fish_startup_case
    The status should be success
  End

  inherited_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf 'module path\nenv INHERITED_VALUE rendered\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    printf '%s\n' 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"' 'test "$INHERITED_VALUE" = caller' > "$TEST_ROOT/child.fish"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c '
      source "$MARKSHARC_HOME/core/fish/marksharc.fish"
      set -gx INHERITED_VALUE caller
      fish --no-config "$TEST_ROOT/child.fish"
    ' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'keeps caller environment changes in a child with a matching render ID'
    When run inherited_case
    The status should be success
  End

  marker_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf 'module path\nset agent.markers MY_CUSTOM_AGENT\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MY_CUSTOM_AGENT=1 fish --no-config -c '
      source "$MARKSHARC_HOME/core/fish/marksharc.fish"
      test "$MARKSHARC_SESSION" = agent
    ' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 2
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'classifies agents using the configured marker list'
    When run marker_case
    The status should be success
  End

  alias_literal_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    stub_command capture-tool 'printf "%s\n" "$@" > "$TEST_ROOT/alias-args"'
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
module path
alias capture 'capture-tool "literal ; $()"'
EOF
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    host=$(hostname)
    host=${host%%.*}
    fish --no-config -c 'source "$MARKSHARC_ROOT/core/fish/lib/path.fish"; source "$MARKSHARC_ROOT/core/fish/lib/modules.fish"; set MARKSHARC_SESSION interactive; source "$argv[1]"; capture tail' "$XDG_CACHE_HOME/marksharc/$host/env.fish" >/dev/null 2>&1 || return 2
    printf 'literal ; $()\ntail\n' > "$TEST_ROOT/expected-args"
    cmp "$TEST_ROOT/expected-args" "$TEST_ROOT/alias-args" || { cat "$TEST_ROOT/alias-args" "$XDG_CACHE_HOME/marksharc/$host/env.fish"; return 4; }
  }
  It 'passes literal metacharacters and caller arguments to an alias command'
    When run alias_literal_case
    The status should be success
  End

  same_name_alias_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    stub_command capture-tool 'printf "%s\n" "$@" > "$TEST_ROOT/alias-args"'
    printf '%s\n' 'module path' "alias capture-tool 'capture-tool marker'" "alias cd 'cd'" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    host=$(hostname)
    host=${host%%.*}
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/path.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/modules.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/plugins.fish"
      set MARKSHARC_HOME "$MARKSHARC_ROOT"
      set MARKSHARC_SESSION interactive
      source "$argv[1]"; or exit 5
      capture-tool tail; or exit 2
      cd "$HOME"; or exit 3
      test "$PWD" = "$HOME"
    ' "$XDG_CACHE_HOME/marksharc/$host/env.fish" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    printf 'marker\ntail\n' > "$TEST_ROOT/expected-args"
    cmp "$TEST_ROOT/expected-args" "$TEST_ROOT/alias-args"
  }
  It 'calls external commands and builtins when aliases use the same name'
    When run same_name_alias_case
    The status should be success
  End

  empty_roots_case() {
    mkdir -p "$HOME/.config/marksharc" "$HOME/.cargo/bin" "$HOME/go/bin"
    printf 'module path\nmodule go\nmodule rust\nenv EMPTY_ROOT_VALUE correct\n' > "$HOME/.config/marksharc/config.conf"
    env XDG_CONFIG_HOME= XDG_CACHE_HOME= MARKSHARC_CONFIG= GOPATH= CARGO_HOME= MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env XDG_CONFIG_HOME= XDG_CACHE_HOME= MARKSHARC_CONFIG= GOPATH= CARGO_HOME= MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- "$PATH|$EMPTY_ROOT_VALUE"' > "$TEST_ROOT/zsh-path" 2> "$TEST_ROOT/err" || return 2
    env XDG_CONFIG_HOME= XDG_CACHE_HOME= MARKSHARC_CONFIG= GOPATH= CARGO_HOME= MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; printf "%s|%s\n" "$PATH" "$EMPTY_ROOT_VALUE"' > "$TEST_ROOT/fish-path" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    cmp "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path"
  }
  It 'uses the default directories for empty XDG and tool-root variables'
    When run empty_roots_case
    The status should be success
  End

  path_parity_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/local tool/bin"
    printf 'module path\npath user "$HOME/local tool/bin"\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- "$PATH"' > "$TEST_ROOT/zsh-path" 2> "$TEST_ROOT/err" || return 2
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 fish --no-config -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; string join : $PATH' > "$TEST_ROOT/fish-path" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    cmp "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path" || { cat "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path" "$TEST_ROOT/err"; return 4; }
  }
  It 'builds the same ordered PATH as zsh from the path module and overlay'
    When run path_parity_case
    The status should be success
  End

  path_tiers_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/first" "$HOME/last" "$HOME/suffix"
    PATH="$PATH:$HOME/suffix"; export PATH
    printf 'module path\npath first "$HOME/first"\npath last "$HOME/last"\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- "$PATH"' > "$TEST_ROOT/zsh-path" 2> "$TEST_ROOT/err" || return 2
    env MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; string join : $PATH' > "$TEST_ROOT/fish-path" 2> "$TEST_ROOT/err" || return 3
    cmp "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path" || { cat "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path"; return 4; }
  }
  It 'places first and last tiers around inherited PATH entries'
    When run path_tiers_case
    The status should be success
  End

  dot_path_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf 'module path\nset core.dot_in_path on\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- "$PATH"' > "$TEST_ROOT/zsh-path" 2> "$TEST_ROOT/err" || return 2
    env MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; string join : $PATH' > "$TEST_ROOT/fish-path" 2> "$TEST_ROOT/err" || return 3
    cmp "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path"
  }
  It 'respects the configured dot-in-PATH option'
    When run dot_path_case
    The status should be success
  End

  custom_tier_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/custom dir"
    printf 'module path\ntiers custom-tier\npath custom-tier "$HOME/custom dir"\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- "$PATH"' > "$TEST_ROOT/zsh-path" 2> "$TEST_ROOT/err" || return 2
    env MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; string join : $PATH' > "$TEST_ROOT/fish-path" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    cmp "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path" || { cat "$TEST_ROOT/err"; return 4; }
  }
  It 'supports custom tier names containing hyphens'
    When run custom_tier_case
    The status should be success
  End

  manager_parity_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/.nvm/alias" "$HOME/.nvm/versions/node/v20.3.0/bin" "$HOME/.cargo/bin" "$HOME/go/bin" "$HOME/.local/share/pnpm"
    printf 'v20\n' > "$HOME/.nvm/alias/default"
    printf 'module path\nmodule node-nvm\nmodule pnpm\nmodule rust\nmodule go\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- "$PATH|$NVM_DIR|$PNPM_HOME"' > "$TEST_ROOT/zsh-path" 2> "$TEST_ROOT/err" || return 2
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 fish --no-config -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; printf "%s|%s|%s\n" "$PATH" "$NVM_DIR" "$PNPM_HOME"' > "$TEST_ROOT/fish-path" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    cmp "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path" || { cat "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path"; return 4; }
  }
  It 'matches version-manager and tool paths and environment with zsh'
    When run manager_parity_case
    The status should be success
  End

  git_worktree_options_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/projects"
    printf 'module path\nmodule git-worktree\nset git-worktree.roots "%s/projects"\nset git-worktree.orgs fixture-org\n' "$HOME" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c '
      source "$MARKSHARC_HOME/core/fish/marksharc.fish"
      test "$_ms_opt_git_worktree_roots" = "$HOME/projects"; or exit 2
      test "$_ms_opt_git_worktree_orgs" = fixture-org; or exit 3
      repo-sync; or exit 4
      fish --no-config -c "repo-sync"; or exit 5
    ' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'exports git-worktree policy to commands and child shells'
    When run git_worktree_options_case
    The status should be success
  End

  pending_uv_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/early" "$HOME/toolbin" "$HOME/.pyenv/bin" "$HOME/.pyenv/shims"
    printf 'describe early\norder 20\npath user "$HOME/toolbin"\n' > "$XDG_CONFIG_HOME/marksharc/modules/early/module.conf"
    printf '#!/bin/sh\nexit 0\n' > "$HOME/toolbin/uv"
    chmod +x "$HOME/toolbin/uv"
    : > "$HOME/.pyenv/bin/pyenv"
    printf 'module path\nmodule early\nmodule python\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- "$PATH|${PYENV_ROOT-unset}"' > "$TEST_ROOT/zsh-path" 2> "$TEST_ROOT/err" || return 2
    env MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; set -q PYENV_ROOT; and set root "$PYENV_ROOT"; or set root unset; printf "%s|%s\n" "$PATH" "$root"' > "$TEST_ROOT/fish-path" 2> "$TEST_ROOT/err" || return 3
    cmp "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path"
  }
  It 'recognizes uv in a previously contributed PATH tier before considering pyenv'
    When run pending_uv_case
    The status should be success
  End

  gvm_parity_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/.gvm/environments" "$HOME/.gvm/gos/go1.23.1/bin"
    printf 'gvm_go_name="go1.23.1"\n' > "$HOME/.gvm/environments/default"
    printf '#!/bin/sh\nexit 0\n' > "$HOME/.gvm/gos/go1.23.1/bin/go"
    chmod +x "$HOME/.gvm/gos/go1.23.1/bin/go"
    printf 'module path\nmodule go-gvm\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 zsh -f -c 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -r -- "$PATH|$GOROOT"' > "$TEST_ROOT/zsh-path" 2> "$TEST_ROOT/err" || return 2
    env MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; printf "%s|%s\n" "$PATH" "$GOROOT"' > "$TEST_ROOT/fish-path" 2> "$TEST_ROOT/err" || return 3
    cmp "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path" || { cat "$TEST_ROOT/zsh-path" "$TEST_ROOT/fish-path" "$TEST_ROOT/err"; return 4; }
  }
  It 'matches the gvm-selected Go path and GOROOT'
    When run gvm_parity_case
    The status should be success
  End

  stale_case() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    printf 'module path\nenv FISH_REFRESH old\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    sleep 1
    printf 'module path\nenv FISH_REFRESH new\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" fish --no-config -c '
      source "$MARKSHARC_HOME/core/fish/marksharc.fish"
      test "$FISH_REFRESH" = new
    ' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    [ ! -s "$TEST_ROOT/out" ] && [ ! -s "$TEST_ROOT/err" ]
  }
  It 'refreshes stale configuration quietly before applying the environment'
    When run stale_case
    The status should be success
  End

  reload_case() {
    [ -n "$PYTHON" ] || return 0
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/demo/functions/fish"
    printf 'describe demo\n' > "$XDG_CONFIG_HOME/marksharc/modules/demo/module.conf"
    printf 'function demo_fn; echo demo; end\n' > "$XDG_CONFIG_HOME/marksharc/modules/demo/functions/fish/demo_fn.fish"
    printf 'function demo_hook --on-variable PWD; demo_fn; end\nbind alt-q demo_fn\n_ms_fish_track_functions fish_title\nfunction fish_title; end\n' > "$XDG_CONFIG_HOME/marksharc/modules/demo/init.fish"
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/keep"
    printf 'describe keep\n' > "$XDG_CONFIG_HOME/marksharc/modules/keep/module.conf"
    printf 'function keep_fn; echo keep; end\n' > "$XDG_CONFIG_HOME/marksharc/modules/keep/init.fish"
    printf 'module path\nmodule demo\nmodule keep\nmodule git-worktree\nset git-worktree.roots "%s"\nenv RELOAD_VALUE old\nenv REMOVED_VALUE keep\n' "$HOME" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 TERM=dumb fish --no-config -i -c '
      source "$MARKSHARC_HOME/core/fish/marksharc.fish"
      test "$MARKSHARC_SESSION" = interactive; or exit 2
      test "$_ms_opt_git_worktree_roots" = "$HOME"; or exit 7
      contains -- "$XDG_CONFIG_HOME/marksharc/modules/demo/functions/fish" $fish_function_path; or exit 5
      test (demo_fn) = demo; or exit 9
      functions -q demo_hook; and test -n "$(bind --user alt-q)"; or exit 11
      printf "module path\nmodule keep\nenv RELOAD_VALUE new\n" > "$XDG_CONFIG_HOME/marksharc/config.conf"
      marksharc reload; or exit 3
      test "$RELOAD_VALUE" = new; and not set -q REMOVED_VALUE; or exit 4
      not set -q _ms_opt_git_worktree_roots; or exit 8
      not contains -- "$XDG_CONFIG_HOME/marksharc/modules/demo/functions/fish" $fish_function_path; or exit 6
      not functions -q demo_fn; or exit 10
      not functions -q demo_hook; and test -z "$(bind --user alt-q)"; or exit 12
      cd /; or exit 13
      test (keep_fn) = keep; or exit 14
      not set -q _ms_fish_reloading; or exit 15
      functions -q fish_title; and not functions -D fish_title | string match -q "*/modules/demo/init.fish"; or exit 16
      echo reloaded
    ' > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 2; }
    grep -q '^reloaded$' "$TEST_ROOT/out"
  }
  It 'reloads changed configuration in the current interactive fish session'
    When run reload_case
    The status should be success
  End

  verbose_case() {
    [ -n "$PYTHON" ] || return 0
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/missing"
    printf 'describe missing\nrequires command never_available_fixture\n' > "$XDG_CONFIG_HOME/marksharc/modules/missing/module.conf"
    printf 'module path\nmodule missing\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env MARKSHARC_HOME="$MARKSHARC_ROOT" zsh -f "$MARKSHARC_ROOT/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    for action in 'marksharc reload' 'marksharc reload --verbose' cs li; do
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_NOTIFY=0 TERM=dumb fish --no-config -i -c "source \"\$MARKSHARC_HOME/core/fish/marksharc.fish\"; $action; echo done" > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 2; }
      grep -q '^done$' "$TEST_ROOT/out" || return 3
      if [ "$action" = 'marksharc reload' ]; then
        grep -q 'marksharc: module' "$TEST_ROOT/out" && return 4
      else
        grep -q 'marksharc: module path' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 5; }
        grep -q 'module missing: skipped.*never_available_fixture' "$TEST_ROOT/out" || return 6
        grep -q 'PATH tier' "$TEST_ROOT/out" || return 7
        grep -q 'Executed in' "$TEST_ROOT/out" || return 8
      fi
    done
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_VERBOSE=1 MARKSHARC_NOTIFY=0 TERM=dumb fish --no-config -i -c 'source "$MARKSHARC_HOME/core/fish/marksharc.fish"; echo done' > "$TEST_ROOT/out" 2>&1 || return 9
    grep -q 'marksharc: module path' "$TEST_ROOT/out" && grep -q 'Executed in' "$TEST_ROOT/out"
  }
  It 'reports module timing, skip reasons, and PATH tiers only when verbose'
    When run verbose_case
    The status should be success
  End
End
