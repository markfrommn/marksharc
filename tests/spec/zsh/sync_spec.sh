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
    "$REAL_GIT" -C "$MS_HOME" remote add origin "$remote" || return 5
    "$REAL_GIT" -C "$MS_HOME" push -qu origin HEAD || return 6
    "$REAL_GIT" clone -q "$remote" "$writer" || return 7
    print -r -- changed > "$writer/fixture-change"
    "$REAL_GIT" -C "$writer" add fixture-change || return 8
    "$REAL_GIT" -C "$writer" -c user.name=Fixture -c user.email=f@example.invalid commit -qm change || return 9
    "$REAL_GIT" -C "$writer" push -q || return 10
    before=$("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD)
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 11; }
    [[ $("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD) != "$before" && $(<"$MS_HOME/fixture-change") == changed ]]
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
End
