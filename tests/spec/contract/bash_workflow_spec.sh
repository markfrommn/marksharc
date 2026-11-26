Describe 'Bash workflow modules'
  Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable

  worktree_helpers() {
    mkdir -p "$TEST_ROOT/repo"
    git -C "$TEST_ROOT/repo" init -q || return
    touch "$TEST_ROOT/repo/tracked file" "$TEST_ROOT/repo/untracked file"
    git -C "$TEST_ROOT/repo" add -- 'tracked file' || return
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/modules/git-worktree/functions/bash/git_managed_arr_core.bash"
      source "$MARKSHARC_ROOT/modules/git-worktree/functions/bash/git-managed.bash"
      source "$MARKSHARC_ROOT/modules/git-worktree/functions/bash/git-unmanaged.bash"
      cd "$TEST_ROOT/repo" || exit 1
      git_managed_arr_core managed found "tracked file" "untracked file" || exit 2
      [[ ${#found[@]} == 1 && ${found[0]} == "tracked file" ]] || exit 3
      git_managed_arr_core unmanaged found "tracked file" "untracked file" || exit 4
      [[ ${#found[@]} == 1 && ${found[0]} == "untracked file" ]] || exit 5
      MARKSHARC_SESSION=interactive git-managed "tracked file"
      MARKSHARC_SESSION=interactive git-unmanaged "untracked file"
    '
  }
  It 'selects literal tracked and untracked paths'
    When run worktree_helpers
    The status should be success
    The output should include 'Git Managed: tracked file'
    The output should include 'Git Un-Managed: untracked file'
  End

  hooks_case() {
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/hooks.bash"
      refresh-env() { printf "%s\n" "$*" >> "$TEST_ROOT/refresh"; }
      setup-ssh-agent() { printf "ssh\n" >> "$TEST_ROOT/start"; }
      setup-x11-display() { printf "%s\n" "$*" >> "$TEST_ROOT/start"; }
      TMUX=1 TMUX_PANE=1
      source "$MARKSHARC_ROOT/modules/mux/init.bash"
      source "$MARKSHARC_ROOT/modules/ssh-agent/init.bash"
      source "$MARKSHARC_ROOT/modules/x11/init.bash"
      _ms_bash_prompt_dispatch
      _ms_bash_preexec_dispatch
      _ms_bash_reloading=1
      source "$MARKSHARC_ROOT/modules/ssh-agent/init.bash"
      [[ ${#_ms_bash_prompt_hooks[@]} == 1 && ${#_ms_bash_preexec_hooks[@]} == 1 ]]
    ' || return
    [ "$(cat "$TEST_ROOT/refresh")" = "$(printf 'auto\nauto\nauto')" ] &&
      [ "$(cat "$TEST_ROOT/start")" = "$(printf 'ssh\n--startup')" ]
  }
  It 'registers mux callbacks and performs guarded startup once'
    When run hooks_case
    The status should be success
  End

  brew_case() {
    cat > "$TEST_ROOT/bin/brew-stub" <<'DATA'
#!/bin/sh
printf '%s\n' 'export HOMEBREW_PREFIX=/brew' 'export PATH=/brew/bin:/usr/bin:/bin:/usr/sbin:/sbin'
DATA
    chmod +x "$TEST_ROOT/bin/brew-stub"
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/ownership.bash"
      source "$MARKSHARC_ROOT/core/bash/cache.bash"
      source "$MARKSHARC_ROOT/modules/brew/functions/bash/setup-homebrew.bash"
      old=$PATH
      setup-homebrew "$TEST_ROOT/bin/brew-stub" || exit 1
      [[ $PATH == "/brew/bin:$old" && $HOMEBREW_PREFIX == /brew ]] || exit 2
      _ms_bash_reset_effects
      _ms_bash_reset_path
      [[ $PATH == "$old" && ! ${HOMEBREW_PREFIX+x} ]]
    '
  }
  It 'caches brew shellenv and retires its owned exports and path'
    When run brew_case
    The status should be success
  End

  title_case() {
    mkdir -p "$TEST_ROOT/framework/modules/mux/bin" "$TEST_ROOT/one/two"
    cat > "$TEST_ROOT/framework/modules/mux/bin/marksharc-mux" <<'DATA'
#!/bin/sh
printf '%s\n' "$@" > "$TEST_ROOT/title"
DATA
    chmod +x "$TEST_ROOT/framework/modules/mux/bin/marksharc-mux"
    MARKSHARC_HOME="$TEST_ROOT/framework" "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      SHLVL=1
      source "$MARKSHARC_ROOT/core/bash/hooks.bash"
      source "$MARKSHARC_ROOT/modules/titles/functions/bash/chdir-set-title.bash"
      source "$MARKSHARC_ROOT/modules/titles/init.bash"
      _ms_bash_prompt_dispatch
      [[ ! -e $TEST_ROOT/title ]] || exit 1
      cd "$TEST_ROOT/one/two" || exit 2
      _ms_bash_prompt_dispatch
      [[ -s $TEST_ROOT/title ]]
    ' || return
    grep -q '^set_titles$' "$TEST_ROOT/title" && grep -q '^bash-chdir$' "$TEST_ROOT/title"
  }
  It 'updates titles only after a directory change'
    When run title_case
    The status should be success
  End
End
