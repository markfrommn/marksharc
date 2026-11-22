Describe 'sync notification'
  behind_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local remote=$TEST_ROOT/remote.git writer=$TEST_ROOT/writer
    "$REAL_GIT" init -q --bare "$remote" || return 1
    "$REAL_GIT" -C "$MS_HOME" init -q || return 2
    "$REAL_GIT" -C "$MS_HOME" add . || return 3
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm initial || return 4
    "$REAL_GIT" -C "$MS_HOME" remote add origin "$remote" || return 5
    "$REAL_GIT" -C "$MS_HOME" push -qu origin HEAD || return 6
    "$REAL_GIT" clone -q "$remote" "$writer" || return 7
    print -r -- changed > "$writer/change"
    "$REAL_GIT" -C "$writer" add change || return 8
    "$REAL_GIT" -C "$writer" -c user.name=Fixture -c user.email=f@example.invalid commit -qm change || return 9
    "$REAL_GIT" -C "$writer" push -q || return 10
    local before=$("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD)
    ms_env
    mkdir -p "$TEST_ROOT/empty-zdot"
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_HOST=testhost "$MS_HOME/bin/marksharc" notify --check || return 11
    [[ -f $XDG_CACHE_HOME/marksharc/testhost/sync/status ]] || { find "$XDG_CACHE_HOME" -type f; return 12; }
    [[ $(<"$XDG_CACHE_HOME/marksharc/testhost/sync/status") == behind && $("$REAL_GIT" -C "$MS_HOME" rev-parse HEAD) == "$before" ]]
  }
  It 'records behind status after a fetch without changing the checkout'
    When run behind_case
    The status should be success
  End

  notice_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local dir=$XDG_CACHE_HOME/marksharc/${HOST%%.*}/sync
    mkdir -p "$dir"
    print -r -- behind > "$dir/status"
    date +%s > "$dir/checked"
    ms_pty MARKSHARC_NOTIFY=1 -dic 'exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'marksharc: updates available'* ]]
  }
  It 'prints a cached behind notice in a subsequent interactive shell'
    When run notice_case
    The status should be success
  End

  failed_throttle_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    "$REAL_GIT" -C "$MS_HOME" init -q || return 1
    print -r -- content > "$MS_HOME/file"
    "$REAL_GIT" -C "$MS_HOME" add file || return 2
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm init || return 3
    "$REAL_GIT" -C "$MS_HOME" remote add origin "$TEST_ROOT/no-remote" || return 4
    "$REAL_GIT" -C "$MS_HOME" config branch.$("$REAL_GIT" -C "$MS_HOME" branch --show-current).remote origin
    stub_command git "if [ \"\$3\" = fetch ]; then print=unused; printf 'fetch\\n' >> '$OPLOG'; exit 1; fi; exec '$REAL_GIT' \"\$@\""
    mkdir -p "$TEST_ROOT/empty-zdot"
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_HOST=testhost "$MS_HOME/bin/marksharc" notify --check || return 5
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_HOST=testhost "$MS_HOME/bin/marksharc" notify --check || return 6
    [[ $(<"$OPLOG") == fetch && $(<"$XDG_CACHE_HOME/marksharc/testhost/sync/status") == unknown ]]
  }
  It 'throttles repeated checks after an offline fetch'
    When run failed_throttle_case
    The status should be success
  End

  killed_lock_case() {
    unsetopt bg_nice
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local dir=$XDG_CACHE_HOME/marksharc/testhost/sync
    mkdir -p "$dir" "$TEST_ROOT/empty-zdot"
    : > "$dir/notify.lock"
    /bin/zsh -f -c 'zmodload zsh/system zsh/zselect; zsystem flock -t 0 -f fd "$1" || exit 1; print ready > "$2"; while :; do zselect -t 100; done' -- "$dir/notify.lock" "$TEST_ROOT/ready" </dev/null >/dev/null 2>&1 &
    local holder=$! i result=0
    for (( i=0; i<100; i++ )); do [[ -f $TEST_ROOT/ready ]] && break; sleep 0.05; done
    [[ -f $TEST_ROOT/ready ]] || result=1
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_HOST=testhost "$MS_HOME/bin/marksharc" notify --check || result=2
    [[ ! -e $dir/status ]] || result=3
    kill -KILL "$holder" 2>/dev/null
    wait "$holder" 2>/dev/null
    (( result == 0 )) || return $result
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_HOST=testhost "$MS_HOME/bin/marksharc" notify --check || return 4
    [[ -f $dir/status ]]
  }
  It 'excludes a live lock holder and recovers after it is killed'
    When run killed_lock_case
    The status should be success
  End
  stale_notice_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local dir=$XDG_CACHE_HOME/marksharc/${HOST%%.*}/sync
    mkdir -p "$dir"
    print -r -- behind > "$dir/status"
    print -r -- newer-sync > "$dir/generation"
    date +%s > "$dir/checked"
    ms_pty MARKSHARC_NOTIFY=1 -dic 'exit' || return 1
    [[ $(<"$TEST_ROOT/out") != *'marksharc: updates available'* ]]
  }
  It 'ignores a cached result superseded by a completed sync'
    When run stale_notice_case
    The status should be success
  End
  concurrent_case() {
    emulate -L zsh
    unsetopt bg_nice
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    "$REAL_GIT" -C "$MS_HOME" init -q || return 1
    print -r -- content > "$MS_HOME/file"
    "$REAL_GIT" -C "$MS_HOME" add file || return 2
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm init || return 3
    "$REAL_GIT" -C "$MS_HOME" remote add origin "$TEST_ROOT/no-remote" || return 4
    "$REAL_GIT" -C "$MS_HOME" config branch.$("$REAL_GIT" -C "$MS_HOME" branch --show-current).remote origin
    stub_command git "if [ \"\$3\" = fetch ]; then printf 'fetch\\n' >> '$OPLOG'; sleep 1; exit 1; fi; exec '$REAL_GIT' \"\$@\""
    mkdir -p "$TEST_ROOT/empty-zdot"
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_HOST=testhost "$MS_HOME/bin/marksharc" notify --check &
    local one=$!
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_HOST=testhost "$MS_HOME/bin/marksharc" notify --check &
    local two=$!
    wait "$one" || return 5
    wait "$two" || return 6
    [[ $(<"$OPLOG") == fetch ]]
  }
  It 'allows only one simultaneous detached fetch'
    When run concurrent_case
    The status should be success
  End
  ineligible_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local dir=$XDG_CACHE_HOME/marksharc/${HOST%%.*}/sync
    mkdir -p "$dir"
    print -r -- behind > "$dir/status"
    ms_pty MARKSHARC_NOTIFY=1 CLAUDECODE=1 -ic 'exit' || return 1
    [[ $(<"$TEST_ROOT/out") != *'updates available'* && ! -e $dir/checked ]] || return 2
    ms_run MARKSHARC_NOTIFY=1 -c 'exit' || return 3
    [[ ! -s $TEST_ROOT/out && ! -e $dir/checked ]]
  }
  It 'does not notify or fetch in agent and batch shells'
    When run ineligible_case
    The status should be success
  End
  shell_roundtrip_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local remote=$TEST_ROOT/remote.git writer=$TEST_ROOT/writer dir=$XDG_CACHE_HOME/marksharc/${HOST%%.*}/sync
    "$REAL_GIT" init -q --bare "$remote" || return 1
    "$REAL_GIT" -C "$MS_HOME" init -q || return 2
    "$REAL_GIT" -C "$MS_HOME" add . || return 3
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm initial || return 4
    "$REAL_GIT" -C "$MS_HOME" remote add origin "$remote" || return 5
    "$REAL_GIT" -C "$MS_HOME" push -qu origin HEAD || return 6
    "$REAL_GIT" clone -q "$remote" "$writer" || return 7
    print -r -- change > "$writer/change"
    "$REAL_GIT" -C "$writer" add change || return 8
    "$REAL_GIT" -C "$writer" -c user.name=Fixture -c user.email=f@example.invalid commit -qm change || return 9
    "$REAL_GIT" -C "$writer" push -q || return 10
    ms_pty MARKSHARC_NOTIFY=1 -ic 'exit' || return 11
    local i
    for (( i=0; i<100; i++ )); do
        [[ -f $dir/status && ! -d $dir/lock ]] && break
        sleep 0.1
    done
    [[ -f $dir/status && $(<"$dir/status") == behind ]] || return 12
    ms_pty MARKSHARC_NOTIFY=1 -ic 'exit' || return 13
    [[ $(<"$TEST_ROOT/out") == *'marksharc: updates available'* ]] || return 14
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 15
    [[ $(<"$MS_HOME/change") == change ]] || return 16
    ms_pty MARKSHARC_NOTIFY=1 -ic 'exit' || return 17
    [[ $(<"$TEST_ROOT/out") != *'marksharc: updates available'* ]]
  }
  It 'fetches in a detached first shell and notifies in the subsequent shell'
    When run shell_roundtrip_case
    The status should be success
  End
End
