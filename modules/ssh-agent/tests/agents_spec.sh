Describe 'SSH agent state and cleanup'
  agent_case() {
    emulate -L zsh
    local mode=$1
    mkdir -p "$HOME/.ssh"
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HOME/agent space"
    export SSH_AUTH_SOCK="$HOME/agent space"
    local MARKSHARC_HOST=fixture state="$XDG_STATE_HOME/marksharc/ssh-agent"
    load_mfn ssh-agent
    local MARKSHARC_SESSION=batch
    ssh-add() { [[ $1 == -l ]] || { print ADD >> "$OPLOG"; return 9; }; return ${probe_status:-0}; }
    ssh-agent() { print START >> "$OPLOG"; return 8; }
    kill() { print -r -- "SIGNAL:$*" >> "$OPLOG"; }
    pssu() { print '123 ssh-agent'; }
    case $mode in
      forwarded|empty|wrong-pid|cached|cached-external|created-external)
        [[ $mode == empty ]] && local probe_status=1
        if [[ $mode == *external ]]; then
          unfunction ssh-add
          cat > "$TEST_ROOT/bin/ssh-add" <<'DATA'
#!/bin/sh
if [ "$1" = -l ] && [ "$SSH_AUTH_SOCK" = "$HOME/agent space" ]; then exit 0; else exit 2; fi
DATA
          chmod +x "$TEST_ROOT/bin/ssh-add"
        fi
        if [[ $mode == created-external ]]; then
          unset SSH_AUTH_SOCK
          ssh-agent() { print -r -- "SSH_AUTH_SOCK=${(q)HOME}/agent\ space; export SSH_AUTH_SOCK;"; }
        fi
        [[ $mode != wrong-pid ]] || SSH_AGENT_PID=999999999
        setup-ssh-agent > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
        [[ -z $(<"$OPLOG") && -z $SSH_AGENT_PID && $SSH_AUTH_SOCK == "$HOME/agent space" ]] || return 2
        [[ $(file_mode "$state/agent.fixture.sh") == 600 && $(file_mode "$state") == 700 && ! -e "$HOME/tmp" ]] || return 3
        if [[ $mode == cached* ]]; then
          unset SSH_AUTH_SOCK SSH_AGENT_PID
          setup-ssh-agent > "$TEST_ROOT/out" 2>&1 || return 9
          [[ $SSH_AUTH_SOCK == "$HOME/agent space" && -z $(<"$OPLOG") ]] || return 10
        fi;;
      missing-pid)
        clean-ssh-agents > "$TEST_ROOT/out" 2>&1
        [[ $? != 0 && -z $(<"$OPLOG") ]] || return 4;;
      verified-cleanup)
        "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HOME/other socket"
        SSH_AGENT_PID=123
        ps() {
          if [[ $1 == -u ]]; then print '123 ssh-agent'; print '456 ssh-agent'; print '789 launchd'; return; fi
          case $4 in uid=) print -r -- "$EUID";; comm=|args=) [[ $2 == 789 ]] && print launchd || print ssh-agent;; esac
        }
        lsof() { [[ $3 == 123 ]] && print -r -- "n$HOME/agent space" || print -r -- "n$HOME/other socket"; }
        clean-ssh-agents > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 7; }
        [[ $(<"$OPLOG") == 'SIGNAL:-- 456' ]] || { cat "$OPLOG"; return 8; };;
      bad-cache)
        unset SSH_AUTH_SOCK SSH_AGENT_PID
        mkdir -p -m 700 "$state"
        print -r -- 'SSH_AUTH_SOCK=$(touch "$HOME/INJECTED"); export SSH_AUTH_SOCK' > "$state/agent.fixture.sh"
        setup-ssh-agent > "$TEST_ROOT/out" 2>&1
        [[ ! -e "$HOME/INJECTED" && $(<"$OPLOG") == START ]] || return 5;;
      stale)
        local probe_status=2
        setup-ssh-agent > "$TEST_ROOT/out" 2>&1
        [[ $? != 0 && $(<"$OPLOG") == START ]] || return 6;;
    esac
  }
  state_dir_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/util.zsh"
    load_mfn ssh-agent _ms_agent_state_dir
    local base="$XDG_STATE_HOME" outside="$HOME/outside"
    mkdir -p "$outside"
    local before=$(file_mode "$outside")
    case $1 in
      symlinked-agent-dir)
        mkdir -p "$base/marksharc"; ln -s "$outside" "$base/marksharc/ssh-agent";;
      symlinked-marksharc)
        mkdir -p "$base"; ln -s "$outside" "$base/marksharc";;
      file-in-the-way)
        mkdir -p "$base/marksharc"; print x > "$base/marksharc/ssh-agent";;
      base-not-a-directory)
        mkdir -p "${base:h}"; print x > "$base";;
    esac
    _ms_agent_state_dir > "$TEST_ROOT/out" 2>&1
    [[ $? != 0 && $(file_mode "$outside") == $before && -z $(print -l "$outside"/*(N)) ]]
  }
  Describe 'state directory'
    Parameters:value symlinked-agent-dir symlinked-marksharc file-in-the-way base-not-a-directory
    It "refuses $1"
      When run state_dir_case "$1"
      The status should be success
    End
  End
  It 'creates the state directory private and idempotently'
    state_create_case() {
      emulate -L zsh
      load_mfn ssh-agent _ms_agent_state_dir
      _ms_agent_state_dir || return 1
      local dir=$REPLY
      [[ $dir == "$XDG_STATE_HOME/marksharc/ssh-agent" && $(file_mode "$dir") == 700 ]] || return 2
      chmod 755 "$dir"
      _ms_agent_state_dir || return 3
      [[ $(file_mode "$dir") == 700 ]]
    }
    When run state_create_case
    The status should be success
  End
  migrate_case() {
    emulate -L zsh
    local mode=$1 old="$HOME/tmp/private/agent.fixture.sh" state="$XDG_STATE_HOME/marksharc/ssh-agent"
    mkdir -p "$HOME/.ssh" "$HOME/tmp/private"
    chmod 700 "$HOME/tmp" "$HOME/tmp/private"
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HOME/agent space"
    print -r -- "SSH_AUTH_SOCK=${(q)HOME}/agent\\ space; export SSH_AUTH_SOCK" > "$old"
    chmod 600 "$old"
    local MARKSHARC_SESSION=batch MARKSHARC_HOST=fixture
    load_mfn ssh-agent
    ssh-add() { return 0; }
    ssh-agent() { print START >> "$OPLOG"; return 8; }
    case $mode in
      new-exists)
        mkdir -p -m 700 "$state"
        print -r -- "SSH_AUTH_SOCK=${(q)HOME}/agent\\ space; export SSH_AUTH_SOCK" > "$state/agent.fixture.sh"
        print -r -- '# newer' >> "$state/agent.fixture.sh";;
      symlinked-dir)
        mv "$HOME/tmp/private" "$HOME/tmp/real"; ln -s "$HOME/tmp/real" "$HOME/tmp/private"; old="$HOME/tmp/real/agent.fixture.sh";;
      writable-dir) chmod 770 "$HOME/tmp/private";;
      world-writable-dir) chmod 707 "$HOME/tmp/private";;
      symlinked-file)
        mv "$old" "$HOME/agent.real"; ln -s "$HOME/agent.real" "$old";;
    esac
    unset SSH_AUTH_SOCK SSH_AGENT_PID
    setup-ssh-agent > "$TEST_ROOT/out" 2>&1
    local rc=$?
    case $mode in
      success)
        [[ $rc == 0 && $SSH_AUTH_SOCK == "$HOME/agent space" && -z $(<"$OPLOG") ]] || { cat "$TEST_ROOT/out"; return 1; }
        [[ ! -e $old && -f "$state/agent.fixture.sh" && $(file_mode "$state/agent.fixture.sh") == 600 ]] || return 2
        # Once: a later run finds the new file and never looks at the old location again.
        print -r -- 'SSH_AUTH_SOCK=/elsewhere; export SSH_AUTH_SOCK' > "$old"
        unset SSH_AUTH_SOCK
        setup-ssh-agent > "$TEST_ROOT/out" 2>&1 || return 3
        [[ $SSH_AUTH_SOCK == "$HOME/agent space" && $(<"$old") == *elsewhere* ]] || return 4;;
      new-exists)
        [[ $rc == 0 && $SSH_AUTH_SOCK == "$HOME/agent space" && -z $(<"$OPLOG") ]] || return 5
        [[ -f $old && $(<"$old") == *agent* && -f "$state/agent.fixture.sh" ]] || return 6;;
      symlinked-dir|writable-dir|world-writable-dir|symlinked-file)
        # Nothing was taken from the untrusted location: the agent had to be started.
        [[ $(<"$OPLOG") == START && $rc != 0 && ! -e "$state/agent.fixture.sh" && -e $old ]] || { cat "$OPLOG" "$TEST_ROOT/out"; return 7; };;
    esac
  }
  Describe 'one-time migration from ~/tmp/private'
    Parameters:value success new-exists symlinked-dir writable-dir world-writable-dir symlinked-file
    It "handles $1 without clobbering or trusting unsafe parents"
      When run migrate_case "$1"
      The status should be success
    End
  End
  Describe sockets
  Parameters:value forwarded empty wrong-pid cached cached-external created-external missing-pid verified-cleanup bad-cache stale
  It "validates $1 without invoking real services"
    When run agent_case "$1"
    The status should be success
  End
  End
End
