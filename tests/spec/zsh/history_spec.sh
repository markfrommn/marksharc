Describe 'history policy and wrapper'
  history_env() {
    # The case functions use emulate -L, which sets localoptions; callees inherit
    # it and would undo the options the module sets before the case can read them.
    unsetopt localoptions
    have_command() { [[ -x "$TEST_ROOT/bin/$1" ]]; }
    # Both modules are sourced as the loader would: history-atuin only when atuin is
    # installed (requires command), history-native defers to it. A reload (cached init
    # skipped) keeps the sourcing quiet and free of atuin runs.
    _ms_reloading=1
    if have_command atuin; then . "$MARKSHARC_ROOT/modules/history-atuin/init.zsh" || return 99; fi
    . "$MARKSHARC_ROOT/modules/history-native/init.zsh" || return 99
  }
  stub_atuin() {
    cat > "$TEST_ROOT/bin/atuin" <<'DATA'
#!/bin/sh
printf 'atuin %s\n' "$*" >> "$OPLOG"
[ "$1" != uuid ] || { echo stub-uuid-1234; exit 0; }
[ "$1 $2" = "history list" ] || exit 0
printf 'session=%s\n' "${ATUIN_SESSION-unset}" >> "$OPLOG"
printf '2026-01-01 10:00:00  one\n2026-01-01 10:00:01  two\n2026-01-01 10:00:02  three\n2026-01-01 10:00:03  four\n'
DATA
    chmod +x "$TEST_ROOT/bin/atuin"
    PATH="$TEST_ROOT/bin:$PATH"
  }

  It 'lists everything pipe-friendly so egrep works'
    wrapper_all_case() {
      emulate -L zsh
      stub_atuin; history_env || return $?
      history | egrep 'two|four'
      grep -qx 'atuin history list --format {time}  {command}' "$OPLOG"
    }
    When run wrapper_all_case
    The status should be success
    The output should equal "2026-01-01 10:00:01  two
2026-01-01 10:00:03  four"
  End

  It 'gives atuin a session for the call only when ATUIN_SESSION is unset'
    wrapper_nosession_case() {
      emulate -L zsh
      stub_atuin; history_env || return $?
      unset ATUIN_SESSION
      history | egrep 'two|four'
      history -1 | grep -c four
      grep -qx 'session=stub-uuid-1234' "$OPLOG" || return 1
      (( ${+ATUIN_SESSION} == 0 )) || return 2
      [[ $(grep -c '^atuin uuid' "$OPLOG") == 2 ]] || return 3
    }
    When run wrapper_nosession_case
    The status should be success
    The output should equal "2026-01-01 10:00:01  two
2026-01-01 10:00:03  four
1"
    The stderr should equal ''
  End

  It 'passes an existing ATUIN_SESSION through unchanged'
    wrapper_session_case() {
      emulate -L zsh
      stub_atuin; history_env || return $?
      export ATUIN_SESSION=real-session-42
      history -1
      grep -qx 'session=real-session-42' "$OPLOG" || return 1
      ! grep -q '^atuin uuid' "$OPLOG" || return 2
      [[ $ATUIN_SESSION == real-session-42 ]]
    }
    When run wrapper_session_case
    The status should be success
    The output should equal "2026-01-01 10:00:03  four"
  End

  It 'history -N shows the last N lines and h the last 35'
    wrapper_last_case() {
      emulate -L zsh
      stub_atuin; history_env || return $?
      history -2; h | wc -l | tr -d ' '
    }
    When run wrapper_last_case
    The output should equal "2026-01-01 10:00:02  three
2026-01-01 10:00:03  four
4"
  End

  It 'passes other arguments to the in-memory builtin'
    wrapper_builtin_case() {
      emulate -L zsh
      stub_atuin; history_env || return $?
      print -s 'recalled cmd'; history 1 | grep -c 'recalled cmd'
    }
    When run wrapper_builtin_case
    The output should equal 1
  End

  It 'falls back to the builtin when atuin disappears after startup'
    wrapper_gone_case() {
      emulate -L zsh
      stub_atuin; history_env || return $?
      rm -f "$TEST_ROOT/bin/atuin"; hash -r
      print -s 'still here'; history 1 | grep -c 'still here'
    }
    When run wrapper_gone_case
    The output should equal 1
  End

  It 'unsets HISTFILE and exports no HIST variable when atuin exists'
    policy_atuin_case() {
      emulate -L zsh
      stub_atuin; HISTFILE=$TEST_ROOT/old; export HISTFILE HISTSIZE=2000 SAVEHIST=1000; history_env || return $?
      [[ -z ${HISTFILE+x} && $SAVEHIST == 0 && $HISTSIZE == 5000 ]] || return 1
      [[ -o histignoredups && -o histreduceblanks && ! -o sharehistory && ! -o incappendhistory && ! -o appendhistory ]] || return 3
      local v
      for v in HISTSIZE SAVEHIST HISTFILE HISTORY_BASE HIST_STAMPS HISTTIMEFORMAT DIRHISTSIZE; do
        [[ ${(Pt)v} == *export* ]] && { print "exported: $v"; return 2; }
      done
      return 0
    }
    When run policy_atuin_case
    The status should be success
  End

  It 'uses one state-dir file and the builtin history without atuin'
    policy_native_case() {
      emulate -L zsh
      export XDG_STATE_HOME="$TEST_ROOT/state" HISTFILE=$TEST_ROOT/old HISTSIZE=2000 SAVEHIST=1000; history_env || return $?
      [[ $HISTFILE == "$XDG_STATE_HOME/marksharc/history" && -d ${HISTFILE:h} ]] || return 1
      [[ $(whence -w history) == 'history: builtin' ]] || return 2
      [[ -o extendedhistory && -o incappendhistory && ! -o sharehistory ]] || return 3
      [[ $HISTSIZE == 10000 && $SAVEHIST == 10000 ]] || return 4
      [[ ${(t)HISTFILE} != *export* && ${(t)HISTSIZE} != *export* && ${(t)SAVEHIST} != *export* ]] || return 5
    }
    When run policy_native_case
    The status should be success
  End

  It 'defaults the native file under HOME/.local/state without XDG_STATE_HOME'
    policy_native_default_case() {
      emulate -L zsh
      unset XDG_STATE_HOME; history_env || return $?
      [[ $HISTFILE == "$HOME/.local/state/marksharc/history" && -d ${HISTFILE:h} ]]
    }
    When run policy_native_default_case
    The status should be success
  End

  It 'prints nothing while sourcing'
    quiet_case() { emulate -L zsh; stub_atuin; history_env; }
    When run quiet_case
    The output should equal ''
    The stderr should equal ''
  End

  It 'runs no atuin command while sourcing'
    no_atuin_run_case() {
      emulate -L zsh
      stub_atuin; history_env || return $?
      [[ ! -s $OPLOG ]]
    }
    When run no_atuin_run_case
    The status should be success
  End
End

Describe 'removed legacy history setup'
  It 'has no old history options, exports, alias, or banner'
    legacy_history_gone_case() {
      emulate -L zsh
      local hits
      hits=$(git -C "$MARKSHARC_ROOT" grep -n -E \
        -e 'Clearing sharehistory' -e 'export (DIRHIST|HIST|SAVEHIST)' \
        -e 'HISTORY_BASE' -e 'HIST_STAMPS' -e 'HISTTIMEFORMAT' -e 'HISTORY_IGNORE' \
        -e 'HISTFILESIZE' -e 'INC_APPEND_HISTORY' -e 'histignoredups' \
        -e "alias h=" -e '^[[:space:]]*(setopt|unsetopt)[[:space:]]+[a-z]*history' \
        -- core modules \
        ':(exclude)modules/history-atuin' ':(exclude)modules/history-native')
      (( $? == 1 )) && return 0
      print -r -- "$hits"; return 1
    }
    When run legacy_history_gone_case
    The status should be success
  End

  It 'runs the atuin init before the policy and after starship'
    ordering_case() {
      local z="$MARKSHARC_ROOT/modules" a p
      a=$(grep -n '_ms_init_cached atuin atuin init zsh' "$z/history-atuin/init.zsh" | head -1 | cut -d: -f1)
      p=$(grep -n '^unset HISTFILE' "$z/history-atuin/init.zsh" | head -1 | cut -d: -f1)
      [[ -n $a && -n $p ]] && (( a < p )) || return 1
      # titles (order 90) re-asserts its cd . kick here when P2.3 lands it.
      local o_s o_a
      o_s=$(sed -n 's/^order //p' "$z/prompt-starship/module.conf")
      o_a=$(sed -n 's/^order //p' "$z/history-atuin/module.conf")
      (( o_s < o_a ))
    }
    When run ordering_case
    The status should be success
  End
End

Describe 'no history file is written by a session'
  # A PTY interactive session through the real core: a copy of the whole zsh
  # tree reached by the ~/.zshenv stub. HISTFILE, HISTSIZE and SAVEHIST are
  # inherited the way /etc/zshrc supplies them on macOS, so a session that did
  # not neutralise them would save history at exit.
  history_session() {
    local with_atuin=$1 tool
    ms_fixture_full
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    # Without atuin the real binary must stay invisible, wherever PATH assembly puts it:
    # the atuin module is removed and have_command hides atuin from history-native.
    if [[ $with_atuin != yes ]]; then
      rm -rf "$MS_HOME/modules/history-atuin"
      print 'have_command() { [[ $1 != atuin ]] && command -v "$1" >/dev/null 2>&1; }' >> "$MS_HOME/core/zsh/lib/util.zsh"
    fi
    for tool in zoxide starship; do
      printf '#!/bin/sh\nprintf "%%s\\n" "starship_precmd() { :; }"\n' > "$TEST_ROOT/bin/$tool"
      chmod +x "$TEST_ROOT/bin/$tool"
    done
    if [[ $with_atuin == yes ]]; then
      printf '#!/bin/sh\nprintf "%%s\\n" "print atuin >> \\"\\$OPLOG\\""\n' > "$TEST_ROOT/bin/atuin"
      chmod +x "$TEST_ROOT/bin/atuin"
    fi
    printf '#!/bin/sh\nexit 1\n' > "$TEST_ROOT/bin/go"
    printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/fortune"
    printf '#!/bin/sh\nexit 99\n' > "$TEST_ROOT/bin/git"
    chmod +x "$TEST_ROOT"/bin/{go,fortune,git}
    local script='print -s "echo hi"; history >/dev/null; h >/dev/null; print READY'
    ms_pty HISTFILE="$HOME/.zsh_history" HISTSIZE=2000 SAVEHIST=1000 -dic "$script"
    [[ $? == 0 && $(<"$TEST_ROOT/out") == *READY* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  history_files() {
    find "$HOME" \( -iname '*hist*' -o -name '.zsh_sessions' \) ! -path '*/modules/history-*' 2>/dev/null | sort
    find "$MARKSHARC_ROOT/core" "$MARKSHARC_ROOT/modules" "$MS_HOME" \( -iname '*hist*' -o -name '.zsh_sessions' \) ! -path '*/modules/history-*' 2>/dev/null | sort
  }
  no_history_written_case() {
    emulate -L zsh
    local repo_before repo_after found
    repo_before=$("$REAL_GIT" -C "$MARKSHARC_ROOT" status --porcelain)
    history_session yes || return 1
    found=$(history_files)
    [[ -z $found ]] || { print -r -- "$found"; return 2; }
    [[ ! -e $XDG_STATE_HOME/marksharc/history ]] || return 3
    repo_after=$("$REAL_GIT" -C "$MARKSHARC_ROOT" status --porcelain)
    [[ $repo_before == $repo_after ]] || return 4
  }
  native_history_only_case() {
    emulate -L zsh
    local repo_before repo_after found
    repo_before=$("$REAL_GIT" -C "$MARKSHARC_ROOT" status --porcelain)
    history_session no || return 1
    found=$(history_files)
    [[ $found == "$XDG_STATE_HOME/marksharc/history" ]] || { print -r -- "found: $found"; return 2; }
    grep -q 'echo hi' "$XDG_STATE_HOME/marksharc/history" || return 3
    repo_after=$("$REAL_GIT" -C "$MARKSHARC_ROOT" status --porcelain)
    [[ $repo_before == $repo_after ]] || return 4
  }
  It 'writes no history file anywhere with atuin'
    When run no_history_written_case
    The status should be success
  End
  It 'writes exactly one state-dir history file without atuin'
    When run native_history_only_case
    The status should be success
  End
End

Describe 'macOS Terminal session files'
  no_apple_terminal() { [ ! -r /etc/zshrc_Apple_Terminal ]; }
  # /etc/zshrc (read before any user file) sets HISTFILE and, under Terminal,
  # saves per-session history. The module must leave none of it behind.
  apple_terminal_case() {
    emulate -L zsh
    print -r -- 'have_command() { [[ $1 == atuin ]]; }
_ms_reloading=1
source "'"$MARKSHARC_ROOT"'/modules/history-atuin/init.zsh"
print -s "echo hi"' > "$ZDOTDIR/.zshrc"
    env -i PATH=/usr/bin:/bin HOME="$HOME" ZDOTDIR="$ZDOTDIR" TERM=xterm \
      TERM_PROGRAM=Apple_Terminal TERM_SESSION_ID=FIXTURE-1 \
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty /bin/zsh -i -c 'print READY' > "$TEST_ROOT/out" 2>&1
    [[ $? == 0 && $(<"$TEST_ROOT/out") == *READY* ]] || { cat "$TEST_ROOT/out"; return 1; }
    local found
    found=$(find "$HOME" -iname '*hist*' 2>/dev/null)
    [[ -z $found ]] || { print -r -- "$found"; return 2; }
  }
  Skip if 'Apple Terminal support file is absent' no_apple_terminal
  It 'writes no history file, with or without per-session history'
    When run apple_terminal_case
    The status should be success
  End
End
