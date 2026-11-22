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
End
