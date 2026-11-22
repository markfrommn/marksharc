Describe 'marksharc sync'
  sync_fast_forward_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local remote=$TEST_ROOT/remote.git writer=$TEST_ROOT/writer before
    "$REAL_GIT" init -q --bare "$remote" || return 1
    "$REAL_GIT" -C "$MS_HOME" init -q || return 2
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid add . || return 3
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm initial || return 4
    "$REAL_GIT" -C "$MS_HOME" remote add upstream "$remote" || return 5
    "$REAL_GIT" -C "$MS_HOME" push -qu upstream HEAD || return 6
    "$REAL_GIT" clone -q "$remote" "$writer" || return 7
    print -r -- changed > "$writer/fixture-change"
    "$REAL_GIT" -C "$writer" add fixture-change || return 8
    "$REAL_GIT" -C "$writer" -c user.name=Fixture -c user.email=f@example.invalid commit -qm change || return 9
    "$REAL_GIT" -C "$writer" push -q || return 10
    before=$("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD)
    local status_dir=$XDG_CACHE_HOME/marksharc/${HOST%%.*}/sync
    mkdir -p "$status_dir"
    print -r -- behind > "$status_dir/status"
    mkdir -p "$status_dir/../init"
    print -r -- stale > "$status_dir/../init/stale.zsh"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 11; }
    [[ $("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD) != "$before" && $(<"$MS_HOME/fixture-change") == changed && $(<"$status_dir/status") != behind && ! -e $status_dir/../init/stale.zsh && $(<"$TEST_ROOT/out") == *doctor:* ]]
  }
  It 'fast-forwards a clean framework checkout from its configured upstream'
    When run sync_fast_forward_case
    The status should be success
  End

  extra_repo_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local remote=$TEST_ROOT/extra.git checkout="$TEST_ROOT/extra checkout" writer=$TEST_ROOT/writer
    "$REAL_GIT" init -q --bare "$remote" || return 1
    "$REAL_GIT" clone -q "$remote" "$checkout" 2>/dev/null || return 2
    print -r -- one > "$checkout/file"
    "$REAL_GIT" -C "$checkout" add file || return 3
    "$REAL_GIT" -C "$checkout" -c user.name=Fixture -c user.email=f@example.invalid commit -qm initial || return 4
    "$REAL_GIT" -C "$checkout" push -qu origin HEAD || return 5
    "$REAL_GIT" clone -q "$remote" "$writer" || return 6
    print -r -- two > "$writer/file"
    "$REAL_GIT" -C "$writer" -c user.name=Fixture -c user.email=f@example.invalid commit -qam change || return 7
    "$REAL_GIT" -C "$writer" push -q || return 8
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- "set sync.repos '$checkout'" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 9; }
    [[ $(<"$checkout/file") == two ]]
  }
  It 'fast-forwards configured extra checkout paths containing spaces'
    When run extra_repo_case
    The status should be success
  End

  missing_repo_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- "set sync.repos '$TEST_ROOT/missing'" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? != 0 && $(<"$TEST_ROOT/out") == *"$TEST_ROOT/missing"* ]]
  }
  It 'reports a configured repository that does not exist'
    When run missing_repo_case
    The status should be success
  End

  status_failure_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    "$REAL_GIT" -C "$MS_HOME" init -q || return 1
    stub_command git "if [ \"\$3\" = status ]; then exit 77; fi; exec '$REAL_GIT' \"\$@\""
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? != 0 && $(<"$TEST_ROOT/out") == *'status failed'* ]]
  }
  It 'fails closed when git cannot inspect the worktree'
    When run status_failure_case
    The status should be success
  End

  plugin_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_copy_module completion-fzf-tab
    local repo=$TEST_ROOT/plugin sha
    "$REAL_GIT" init -q "$repo" || return 1
    print -r -- fixture > "$repo/fixture.plugin.zsh"
    "$REAL_GIT" -C "$repo" add . || return 2
    "$REAL_GIT" -C "$repo" -c user.name=Fixture -c user.email=f@example.invalid commit -qm init || return 3
    sha=$("$REAL_GIT" -C "$repo" rev-parse HEAD)
    print -r -- "plugin fixture '$repo' $sha shell zsh kind source" > "$MS_HOME/modules/completion-fzf-tab/zsh.plugins"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 4; }
    [[ $("$REAL_GIT" -C "$XDG_CACHE_HOME/marksharc/plugins/fixture@$sha" rev-parse HEAD) == "$sha" ]]
  }
  It 'fetches configured plugin pins into the cache'
    When run plugin_case
    The status should be success
  End
  overlay_plugin_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_copy_module completion-fzf-tab
    rm "$MS_HOME/modules/completion-fzf-tab/zsh.plugins"
    local repo=$TEST_ROOT/plugin sha dir=$XDG_CONFIG_HOME/marksharc/modules/private
    "$REAL_GIT" init -q "$repo" || return 1
    print -r -- fixture > "$repo/private.plugin.zsh"
    "$REAL_GIT" -C "$repo" add . || return 2
    "$REAL_GIT" -C "$repo" -c user.name=Fixture -c user.email=f@example.invalid commit -qm init || return 3
    sha=$("$REAL_GIT" -C "$repo" rev-parse HEAD)
    mkdir -p "$dir"
    print -r -- 'describe private' > "$dir/module.conf"
    print -r -- "plugin private '$repo' $sha shell zsh kind source" > "$dir/zsh.plugins"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 4
    [[ -f $XDG_CACHE_HOME/marksharc/plugins/private@$sha/private.plugin.zsh ]]
  }
  It 'fetches plugin pins declared by overlay modules'
    When run overlay_plugin_case
    The status should be success
  End

  update_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    print -r -- $'#!/usr/bin/env zsh\nprint -r -- sync-ran' > "$MS_HOME/core/cli/sync"
    chmod +x "$MS_HOME/core/cli/sync"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/out") == sync-ran ]]
  }
  It 'runs the sync and pin updater through the minimal update command'
    When run update_case
    The status should be success
  End

  unsafe_setup() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    REMOTE=$TEST_ROOT/remote.git
    "$REAL_GIT" init -q --bare "$REMOTE" || return 1
    "$REAL_GIT" -C "$MS_HOME" init -q || return 2
    "$REAL_GIT" -C "$MS_HOME" add . || return 3
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm initial || return 4
    "$REAL_GIT" -C "$MS_HOME" remote add origin "$REMOTE" || return 5
    "$REAL_GIT" -C "$MS_HOME" push -qu origin HEAD || return 6
    "$REAL_GIT" clone -q "$REMOTE" "$TEST_ROOT/writer" || return 7
  }
  unsafe_run() {
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
  }
  dirty_case() {
    unsafe_setup || return 1
    print -r -- precious > "$MS_HOME/untracked"
    local before=$("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD)
    unsafe_run; [[ $? != 0 ]] || return 2
    [[ $(<"$TEST_ROOT/out") == *'dirty:'* && $(<"$MS_HOME/untracked") == precious && $("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD) == "$before" ]] || return 3
    rm "$MS_HOME/untracked"
    print -r -- '# fixture edit' >> "$MS_HOME/core/cli/version"
    unsafe_run; [[ $? != 0 && $(<"$TEST_ROOT/out") == *'dirty:'* ]] || return 4
    "$REAL_GIT" -C "$MS_HOME" add core/cli/version || return 5
    unsafe_run; [[ $? != 0 && $(<"$TEST_ROOT/out") == *'dirty:'* ]] || return 6
    [[ $("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD) == "$before" ]]
  }
  It 'reports untracked, unstaged and staged changes without touching them'
    When run dirty_case
    The status should be success
  End
  ahead_case() {
    unsafe_setup || return 1
    print -r -- local > "$MS_HOME/local"
    "$REAL_GIT" -C "$MS_HOME" add local || return 2
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm local || return 3
    local before=$("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD)
    unsafe_run; [[ $? != 0 ]] || return 4
    [[ $(<"$TEST_ROOT/out") == *'ahead:'* && $("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD) == "$before" ]]
  }
  It 'reports an ahead checkout without moving it'
    When run ahead_case
    The status should be success
  End
  diverged_case() {
    unsafe_setup || return 1
    print -r -- local > "$MS_HOME/local"
    "$REAL_GIT" -C "$MS_HOME" add local || return 2
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm local || return 3
    print -r -- remote > "$TEST_ROOT/writer/remote"
    "$REAL_GIT" -C "$TEST_ROOT/writer" add remote || return 4
    "$REAL_GIT" -C "$TEST_ROOT/writer" -c user.name=Fixture -c user.email=f@example.invalid commit -qm remote || return 5
    "$REAL_GIT" -C "$TEST_ROOT/writer" push -q || return 6
    local before=$("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD)
    unsafe_run; [[ $? != 0 ]] || return 7
    [[ $(<"$TEST_ROOT/out") == *'diverged:'* && $("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD) == "$before" ]]
  }
  It 'reports a diverged checkout without merging'
    When run diverged_case
    The status should be success
  End
  offline_case() {
    unsafe_setup || return 1
    "$REAL_GIT" -C "$MS_HOME" remote set-url origin "$TEST_ROOT/missing-remote"
    local before=$("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD)
    unsafe_run; [[ $? != 0 ]] || return 2
    [[ $(<"$TEST_ROOT/out") == *'fetch failed:'* && $("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD) == "$before" ]]
  }
  It 'reports an unavailable remote without moving the checkout'
    When run offline_case
    The status should be success
  End
  overlay_owner_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local remote=$TEST_ROOT/overlay.git overlay=$TEST_ROOT/overlay writer=$TEST_ROOT/writer
    "$REAL_GIT" init -q --bare "$remote" || return 1
    "$REAL_GIT" clone -q "$remote" "$overlay" 2>/dev/null || return 2
    mkdir -p "$overlay/marksharc" "$XDG_CONFIG_HOME"
    print -r -- "set sync.repos '$overlay'" > "$overlay/marksharc/config.conf"
    "$REAL_GIT" -C "$overlay" add . || return 3
    "$REAL_GIT" -C "$overlay" -c user.name=Fixture -c user.email=f@example.invalid commit -qm init || return 4
    "$REAL_GIT" -C "$overlay" push -qu origin HEAD || return 5
    ln -s "$overlay/marksharc" "$XDG_CONFIG_HOME/marksharc"
    "$REAL_GIT" clone -q "$remote" "$writer" || return 6
    print -r -- new > "$writer/other"
    "$REAL_GIT" -C "$writer" add other || return 7
    "$REAL_GIT" -C "$writer" -c user.name=Fixture -c user.email=f@example.invalid commit -qm change || return 8
    "$REAL_GIT" -C "$writer" push -q || return 9
    unsafe_run || { cat "$TEST_ROOT/err"; return 10; }
    [[ $(<"$overlay/other") == new && $(grep -c 'sync: updated:' "$TEST_ROOT/out") == 1 ]]
  }
  It 'updates the owning checkout of a linked overlay subdirectory once'
    When run overlay_owner_case
    The status should be success
  End
End
