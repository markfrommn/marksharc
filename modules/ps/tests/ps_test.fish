source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
ms_module ps

ms_stub ps 'printf "%s\n" "$*" >>"$TEST_ROOT/ps-args"
printf "  PID  PPID USER STAT ELAPSED COMMAND\n"
printf "    1     0 root Ss  01:00 /sbin/init\n"
printf "   42     1 me   S   00:10 sshd: me@pts/0\n"
printf "   77    42 me   R   00:00 ps $*\n"'

set -l out (pss sshd)
@test "pss keeps the header" "$out[1]" = "  PID  PPID USER STAT ELAPSED COMMAND"
@test "pss keeps the matching line only" (count $out) -eq 2
@test "pss matches the pattern" "$out[2]" = "   42     1 me   S   00:10 sshd: me@pts/0"

set out (pss init sshd)
@test "several patterns are alternatives" (count $out) -eq 3

set out (pss 'ps ax')
@test "the ps invocation's own line is dropped" (count $out) -eq 1

@test "an invalid pattern is reported" (pss '(' 2>&1) = "ps: invalid pattern: ("
pss '(' 2>/dev/null
@test "an invalid pattern returns 2" $status -eq 2

printf '' >"$TEST_ROOT/ps-args"
psj >/dev/null
@test "psj lists all processes in job columns" "$(cat "$TEST_ROOT/ps-args")" = "ax -o pid,ppid,pgid,tpgid,stat,tty,user,command"
printf '' >"$TEST_ROOT/ps-args"
psuj >/dev/null
@test "psuj lists your processes in job columns" "$(cat "$TEST_ROOT/ps-args")" = "x -o pid,ppid,pgid,tpgid,stat,tty,user,command"
printf '' >"$TEST_ROOT/ps-args"
pssu >/dev/null
@test "pssu without a pattern lists your processes" "$(cat "$TEST_ROOT/ps-args")" = "x -o pid,ppid,user,stat,etime,command"
@test "every helper is defined" (count (functions -q pss pssj psj pssu pssuj psuj psju; and echo yes)) -eq 1

ms_cleanup
