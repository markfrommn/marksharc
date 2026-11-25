Describe 'SSH agent state and cleanup'
  executable_no_ssh_case() {
    emulate -L zsh
    rm -rf "$HOME/.ssh"
    bash -c '"$MARKSHARC_ROOT/modules/ssh-agent/bin/setup-ssh-agent"' > "$TEST_ROOT/out" 2>&1
    [[ $? == 0 && ! -s "$TEST_ROOT/out" && ! -s "$OPLOG" ]]
  }
  It 'skips discovery without an SSH directory when invoked from bash'
    When run executable_no_ssh_case
    The status should be success
  End
  bash_directive_case() {
    emulate -L zsh
    mkdir -p "$HOME/.ssh"
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HOME/agent % space"
    cat > "$TEST_ROOT/bin/ssh-add" <<'DATA'
#!/bin/sh
exit 0
DATA
    cat > "$TEST_ROOT/bin/ps" <<'DATA'
#!/bin/sh
exit 1
DATA
    chmod +x "$TEST_ROOT/bin/ssh-add" "$TEST_ROOT/bin/ps"
    local directives="$TEST_ROOT/directives"
    : > "$directives"
    SSH_AUTH_SOCK="$HOME/agent % space" SSH_AGENT_PID=999999999 MARKSHARC_HOST=fixture \
      MARKSHARC_DIRECTIVES="$directives" bash -c '"$1"' _ "$MARKSHARC_ROOT/modules/ssh-agent/bin/setup-ssh-agent" || return 1
    [[ $(<"$directives") == "setenv"$'\t'"SSH_AUTH_SOCK"$'\t'"$HOME/agent %25 space"$'\nunsetenv\tSSH_AGENT_PID' ]]
  }
  It 'emits safe directives for a verified socket from bash'
    When run bash_directive_case
    The status should be success
  End
  interactive_case() {
    emulate -L zsh
    mkdir -p "$HOME/.ssh"
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HOME/agent space"
    cat > "$TEST_ROOT/bin/ssh-add" <<'DATA'
#!/bin/sh
if [ "$1" = -l ]; then exit 1; fi
echo ADD >> "$OPLOG"
exit "${ADD_STATUS:-0}"
DATA
    cat > "$TEST_ROOT/bin/ps" <<'DATA'
#!/bin/sh
exit 1
DATA
    chmod +x "$TEST_ROOT/bin/ssh-add" "$TEST_ROOT/bin/ps"
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    load_mfn ssh-agent setup-ssh-agent
    PATH="$MARKSHARC_ROOT/modules/ssh-agent/bin:$PATH"
    export SSH_AUTH_SOCK="$HOME/agent space" SSH_AGENT_PID=999999999 MARKSHARC_HOST=fixture ADD_STATUS="$1"
    local MARKSHARC_SESSION=interactive
    typeset +x MARKSHARC_SESSION
    setup-ssh-agent > "$TEST_ROOT/out" 2>&1
    local rc=$?
    [[ $rc == "$1" && $(<"$OPLOG") == ADD && $SSH_AUTH_SOCK == "$HOME/agent space" && -z ${SSH_AGENT_PID-} ]]
  }
  It 'passes unexported interactive session context to key loading'
    When run interactive_case 0
    The status should be success
  End
  It 'applies completed discovery even when key loading fails'
    When run interactive_case 17
    The status should be success
  End
  launch_parent_case() {
    emulate -L zsh
    local mode=$1 expected cache_host=fixture state="$XDG_STATE_HOME/marksharc/ssh-agent"
    local socket
    mkdir -p "$HOME/.ssh" "$state"
    chmod 700 "$state"
    for socket in inherited parent cached; do
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HOME/$socket agent" || return 1
    done
    export SSH_AUTH_SOCK="$HOME/inherited agent" MARKSHARC_HOST=fixture SSH_TEST_MODE=$mode
    export LAUNCH_PARENT_HOST=fixture LAUNCH_PARENT_SSH_AUTH_SOCK="$HOME/parent agent"
    case $mode in
      inherited) expected=inherited ;;
      usable) expected=parent ;;
      shell-host) expected=parent; cache_host=${HOST%%.*}; LAUNCH_PARENT_HOST=$cache_host; unset MARKSHARC_HOST ;;
      dead) expected=cached ;;
      foreign) expected=cached; LAUNCH_PARENT_HOST=elsewhere ;;
      missing-host) expected=cached; unset LAUNCH_PARENT_HOST ;;
    esac
    printf 'SSH_AUTH_SOCK=%s; export SSH_AUTH_SOCK;\n' "${(q):-"$HOME/cached agent"}" > "$state/agent.$cache_host.sh"
    chmod 600 "$state/agent.$cache_host.sh"
    stub_command ssh-add 'printf "%s\n" "${SSH_AUTH_SOCK##*/}" >> "$OPLOG"
case "$SSH_AUTH_SOCK:$SSH_TEST_MODE" in
  "$HOME/inherited agent:inherited"|"$HOME/parent agent:usable"|"$HOME/parent agent:shell-host"|"$HOME/cached agent:"*) exit 0 ;;
  *) exit 2 ;;
esac'
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    load_mfn ssh-agent setup-ssh-agent
    PATH="$MARKSHARC_ROOT/modules/ssh-agent/bin:$PATH"
    setup-ssh-agent || return 2
    [[ $SSH_AUTH_SOCK == "$HOME/$expected agent" ]] || return 3
    case $mode in
      inherited) [[ $(<"$OPLOG") == $'inherited agent\ninherited agent' ]] ;;
      usable|shell-host) [[ $(<"$OPLOG") == $'inherited agent\nparent agent\nparent agent' ]] ;;
      dead) [[ $(<"$OPLOG") == $'inherited agent\nparent agent\ncached agent\ncached agent' ]] ;;
      foreign|missing-host) [[ $(<"$OPLOG") == $'inherited agent\ncached agent\ncached agent' ]] ;;
    esac
  }
  Describe 'launch-parent sockets'
    Parameters:value inherited usable shell-host dead foreign missing-host
    It "handles a $1 socket before discovery"
      When run launch_parent_case "$1"
      The status should be success
    End
  End
  agent_case() {
    emulate -L zsh
    local mode=$1
    mkdir -p "$HOME/.ssh"
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HOME/agent space"
    export SSH_AUTH_SOCK="$HOME/agent space"
    local MARKSHARC_HOST=fixture state="$XDG_STATE_HOME/marksharc/ssh-agent"
    load_mfn ssh-agent setup-ssh-agent
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    PATH="$MARKSHARC_ROOT/modules/ssh-agent/bin:$PATH"
    export MARKSHARC_HOST MARKSHARC_SESSION SSH_AUTH_SOCK SSH_AGENT_PID
    export MARKSHARC_SESSION=batch
    export SSH_TEST_MODE=$mode
    cat > "$TEST_ROOT/bin/ssh-add" <<'DATA'
#!/bin/sh
if [ "$1" != -l ]; then echo ADD >> "$OPLOG"; exit 9; fi
[ "$SSH_AUTH_SOCK" = "$HOME/agent space" ] || exit 2
case "$SSH_TEST_MODE" in stale) exit 2;; empty) exit 1;; esac
exit 0
DATA
    cat > "$TEST_ROOT/bin/ssh-agent" <<'DATA'
#!/bin/sh
if [ "$SSH_TEST_MODE" = created-external ]; then
  printf 'SSH_AUTH_SOCK="%s/agent space"; export SSH_AUTH_SOCK;\n' "$HOME"
  exit 0
fi
echo START >> "$OPLOG"
exit 8
DATA
    cat > "$TEST_ROOT/bin/ps" <<'DATA'
#!/bin/sh
if [ "$1" = -u ]; then printf '123 ssh-agent\n456 ssh-agent\n789 launchd\n'; exit; fi
case "$4" in uid=) id -u;; comm=|args=) if [ "$2" = 789 ]; then echo launchd; else echo ssh-agent; fi;; esac
DATA
    cat > "$TEST_ROOT/bin/lsof" <<'DATA'
#!/bin/sh
if [ "$3" = 123 ]; then printf 'n%s/agent space\n' "$HOME"; else printf 'n%s/other socket\n' "$HOME"; fi
DATA
    cat > "$TEST_ROOT/bin/kill" <<'DATA'
#!/bin/sh
printf 'SIGNAL:%s\n' "$*" >> "$OPLOG"
DATA
    chmod +x "$TEST_ROOT/bin/ssh-add" "$TEST_ROOT/bin/ssh-agent" "$TEST_ROOT/bin/ps" "$TEST_ROOT/bin/lsof" "$TEST_ROOT/bin/kill"
    case $mode in
      forwarded|empty|wrong-pid|cached|cached-external|created-external)
        if [[ $mode == *external ]]; then
          cat > "$TEST_ROOT/bin/ssh-add" <<'DATA'
#!/bin/sh
if [ "$1" = -l ] && [ "$SSH_AUTH_SOCK" = "$HOME/agent space" ]; then exit 0; else exit 2; fi
DATA
          chmod +x "$TEST_ROOT/bin/ssh-add"
        fi
        if [[ $mode == created-external ]]; then
          unset SSH_AUTH_SOCK
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
        bash -c 'clean-ssh-agents' > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 7; }
        [[ $(<"$OPLOG") == 'SIGNAL:456' ]] || { cat "$OPLOG"; return 8; };;
      bad-cache)
        unset SSH_AUTH_SOCK SSH_AGENT_PID
        mkdir -p -m 700 "$state"
        print -r -- 'SSH_AUTH_SOCK=$(touch "$HOME/INJECTED"); export SSH_AUTH_SOCK' > "$state/agent.fixture.sh"
        setup-ssh-agent > "$TEST_ROOT/out" 2>&1
        [[ ! -e "$HOME/INJECTED" && $(<"$OPLOG") == START ]] || return 5;;
      stale)
        setup-ssh-agent > "$TEST_ROOT/out" 2>&1
        [[ $? != 0 && $(<"$OPLOG") == START ]] || return 6;;
    esac
  }
  state_dir_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/util.zsh"
    fpath=( "$MARKSHARC_ROOT/modules/ssh-agent/lib" $fpath ); autoload -Uz _ms_agent_state_dir
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
      fpath=( "$MARKSHARC_ROOT/modules/ssh-agent/lib" $fpath ); autoload -Uz _ms_agent_state_dir
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
    export MARKSHARC_SESSION=batch MARKSHARC_HOST=fixture
    load_mfn ssh-agent setup-ssh-agent
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    PATH="$MARKSHARC_ROOT/modules/ssh-agent/bin:$PATH"
    export MARKSHARC_HOST MARKSHARC_SESSION SSH_AUTH_SOCK SSH_AGENT_PID
    cat > "$TEST_ROOT/bin/ssh-add" <<'DATA'
#!/bin/sh
[ "$SSH_AUTH_SOCK" = "$HOME/agent space" ] || exit 2
DATA
    cat > "$TEST_ROOT/bin/ssh-agent" <<'DATA'
#!/bin/sh
echo START >> "$OPLOG"
exit 8
DATA
    chmod +x "$TEST_ROOT/bin/ssh-add" "$TEST_ROOT/bin/ssh-agent"
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
