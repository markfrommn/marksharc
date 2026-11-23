Describe 'ps helpers'
  # A stub ps records its arguments and prints a fixed listing, including its own
  # entry the way the real ps lists itself. grep and egrep must never run.
  ps_stub() {
    cat > "$TEST_ROOT/bin/ps" <<'DATA'
#!/bin/sh
printf 'ps %s\n' "$*" >> "$OPLOG"
printf '  PID  PPID USER STAT ELAPSED COMMAND\n'
printf '  101     1 me   S    01:00 /usr/bin/foo --serve\n'
printf '  102     1 me   S    01:00 /usr/bin/bar\n'
printf '  103     1 me   S    01:00 mypid-tool run\n'
printf '  104     1 me   S    01:00 /usr/bin/psql\n'
printf '  105   200 me   R+   00:00 ps %s\n' "$*"
DATA
    chmod +x "$TEST_ROOT/bin/ps"
    local tool
    for tool in grep egrep; do
      printf '#!/bin/sh\nprintf "FORBIDDEN %s\\n" >> "$OPLOG"\nexit 99\n' "$tool" > "$TEST_ROOT/bin/$tool"
      chmod +x "$TEST_ROOT/bin/$tool"
    done
    hash -r
    load_mfn ps
  }
  filter_case() {
    emulate -L zsh
    ps_stub
    local -a got
    # The header is kept and only matching lines follow: no PID-alternation false matches.
    got=( "${(@f)$(pss foo)}" )
    [[ $#got == 2 && $got[1] == *PID* && $got[2] == *'/usr/bin/foo'* ]] || { print -l -- $got; return 1; }
    got=( "${(@f)$(pss 'foo|bar')}" )
    [[ $#got == 3 ]] || { print -l -- $got; return 2; }
    got=( "${(@f)$(pss foo bar)}" )
    [[ $#got == 3 ]] || { print -l -- $got; return 3; }
    # No grep process exists to match itself, and ps's own line is dropped.
    got=( "${(@f)$(pss ps)}" )
    [[ $#got == 2 && $got[2] == *psql* ]] || { print -l -- $got; return 4; }
    got=( "${(@f)$(pss PID)}" )
    [[ $#got == 1 && $got[1] == *PID* ]] || { print -l -- $got; return 5; }
    got=( "${(@f)$(pss nosuchprocess)}" )
    [[ $#got == 1 ]] || { print -l -- $got; return 6; }
    [[ $(<"$OPLOG") != *FORBIDDEN* ]] || { cat "$OPLOG"; return 7; }
    pss '(' > /dev/null 2> "$TEST_ROOT/err"
    [[ $? == 2 && $(<"$TEST_ROOT/err") == *'invalid pattern'* ]] || return 8
  }
  It 'keeps the header, filters in the shell, and never matches itself'
    When run filter_case
    The status should be success
  End
  arguments_case() {
    emulate -L zsh
    ps_stub
    local name
    for name in pss pssj psj pssu pssuj psuj psju; do
      : > "$OPLOG"
      $name foo > /dev/null
      case $name in
        pss)   [[ $(<"$OPLOG") == 'ps ax -o pid,ppid,user,stat,etime,command' ]] ;;
        pssj)  [[ $(<"$OPLOG") == 'ps ax -o pid,ppid,pgid,tpgid,stat,tty,user,command' ]] ;;
        psj)   [[ $(<"$OPLOG") == 'ps ax -o pid,ppid,pgid,tpgid,stat,tty,user,command' ]] ;;
        pssu)  [[ $(<"$OPLOG") == 'ps x -o pid,ppid,user,stat,etime,command' ]] ;;
        pssuj|psuj|psju) [[ $(<"$OPLOG") == 'ps x -o pid,ppid,pgid,tpgid,stat,tty,user,command' ]] ;;
      esac || { print "$name: $(<"$OPLOG")"; return 1; }
    done
    # The unfiltered forms list everything, including the ps entry (ps itself decides).
    [[ $(psj | wc -l) -ge 5 && $(psuj | wc -l) -ge 5 ]] || return 2
    # No pattern lists everything for the filtered forms too.
    [[ $(pss | wc -l) -ge 5 ]]
  }
  It 'defines all seven helpers with the same portable flags on every OS'
    When run arguments_case
    The status should be success
  End
  same_everywhere_case() {
    emulate -L zsh
    ps_stub
    local os
    for os in Darwin Linux; do
      MARKSHARC_OS=${os:l}
      : > "$OPLOG"
      pss foo > /dev/null
      [[ $(<"$OPLOG") == 'ps ax -o pid,ppid,user,stat,etime,command' ]] || return 1
    done
  }
  It 'does not branch on the platform'
    When run same_everywhere_case
    The status should be success
  End
End
