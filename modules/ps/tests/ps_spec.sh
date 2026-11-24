Describe 'ps helpers backed by procs (P3.6)'
  ps_stub() {
    stub_command ps 'printf "%s\n" "$*" >> "$TEST_ROOT/ps-args"
printf "  PID  PPID USER STAT ELAPSED COMMAND\n"
printf "    1     0 root Ss  01:00 /sbin/init\n"
printf "   42     1 me   S   00:10 sshd: me@pts/0\n"
printf "   43     1 me   S   00:10 sshd: me@pts/1\n"
printf "   77    42 me   R   00:00 ps $*\n"'
  }
  procs_stub() { stub_command procs 'printf "procs %s\n" "$*" >> "$OPLOG"; echo PROCS'; }
  helpers() {
    emulate -L zsh
    local PATH="$TEST_ROOT/bin:/usr/bin:/bin"
    rehash
    load_mfn ps
    "$@"
  }
  fallback_case() {
    emulate -L zsh
    ps_stub
    # No procs on PATH: the native helpers, unchanged.
    helpers pss sshd > "$TEST_ROOT/out" || return 1
    [[ $(<"$TEST_ROOT/out") == $'  PID  PPID USER STAT ELAPSED COMMAND\n   42     1 me   S   00:10 sshd: me@pts/0\n   43     1 me   S   00:10 sshd: me@pts/1' ]] || { cat "$TEST_ROOT/out"; return 2; }
    helpers psj > "$TEST_ROOT/out" || return 3
    [[ $(tail -n 1 "$TEST_ROOT/ps-args") == 'ax -o pid,ppid,pgid,tpgid,stat,tty,user,command' ]] || return 4
    [[ ! -s $OPLOG ]] || return 5
    # procs installed but switched off: still native.
    procs_stub
    _ms_opt_ps_procs=off helpers pss sshd > "$TEST_ROOT/out" || return 6
    [[ $(<"$TEST_ROOT/out") == *'sshd: me@pts/1' && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 7; }
  }
  It 'keeps the native helpers when procs is missing or switched off'
    When run fallback_case
    The status should be success
  End
  procs_case() {
    emulate -L zsh
    ps_stub; procs_stub
    # ps selects with the pattern; procs draws the selected PIDs.
    helpers pss sshd > "$TEST_ROOT/out" || return 1
    [[ $(<"$TEST_ROOT/out") == PROCS && $(<"$OPLOG") == 'procs --or 42 43' ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
    [[ $(<"$TEST_ROOT/ps-args") == 'ax -o pid,ppid,user,stat,etime,command' ]] || return 3
    # The job view inserts the parent, process group and state columns.
    : > "$OPLOG"
    helpers pssuj init > /dev/null || return 4
    [[ $(<"$OPLOG") == 'procs --insert Ppid --insert Pgid --insert State --or 1' ]] || { cat "$OPLOG"; return 5; }
    # All processes with no pattern is plain procs; ps is not run.
    : > "$OPLOG"; : > "$TEST_ROOT/ps-args"
    helpers pss > /dev/null && helpers psj > /dev/null || return 6
    [[ $(<"$OPLOG") == $'procs \nprocs --insert Ppid --insert Pgid --insert State' && ! -s $TEST_ROOT/ps-args ]] || { cat "$OPLOG"; return 7; }
    # Your processes with no pattern: every PID ps selected, minus the ps line itself.
    : > "$OPLOG"
    helpers psuj > /dev/null || return 8
    [[ $(<"$OPLOG") == 'procs --insert Ppid --insert Pgid --insert State --or 1 42 43' ]] || { cat "$OPLOG"; return 9; }
    # Nothing selected prints nothing and does not call procs; a bad pattern is still refused.
    : > "$OPLOG"
    helpers pss nomatch > "$TEST_ROOT/out" || return 10
    [[ ! -s $TEST_ROOT/out && ! -s $OPLOG ]] || return 11
    helpers pss '(' 2> "$TEST_ROOT/err"
    [[ $? == 2 && $(<"$TEST_ROOT/err") == 'ps: invalid pattern: (' ]] || return 12
  }
  It 'selects with ps and draws the selection with procs'
    When run procs_case
    The status should be success
  End
  bare_case() {
    emulate -L zsh
    # Bare ps is never redefined by the module.
    ! grep -rqE '(^|[[:space:]])(alias ps=|ps *\(\) *\{|function ps( |$))' --exclude-dir=tests "$MARKSHARC_ROOT/modules/ps" || return 1
    [[ ! -e $MARKSHARC_ROOT/modules/ps/functions/zsh/ps && ! -e $MARKSHARC_ROOT/modules/ps/functions/fish/ps.fish ]]
  }
  It 'leaves bare ps untouched'
    When run bare_case
    The status should be success
  End
End
