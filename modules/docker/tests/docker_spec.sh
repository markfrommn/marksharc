Describe 'docker module'
  yolo_case() {
    emulate -L zsh
    local in=$1 sandcat=$2 code
    code='in_docker() { return '$in'; }; source "$MOD_INIT"; print -r -- "alias=${+aliases[claude-yolo]}"'
    if [[ $sandcat == yes ]]; then code='export SANDCAT_INSTANCE=1; '$code; fi
    module_run docker "$code" || return 1
    [[ $(<"$TEST_ROOT/out") == "alias=$3" ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  Describe 'claude-yolo'
    Parameters
      0 yes 1
      0 no 0
      1 yes 0
      1 no 0
    End
    It "is defined only in docker with SANDCAT (in_docker=$1 sandcat=$2)"
      When run yolo_case "$1" "$2" "$3"
      The status should be success
    End
  End
  cleanup_case() {
    emulate -L zsh
    cat > "$TEST_ROOT/bin/docker" <<'DATA'
#!/bin/sh
case "$1 $2" in
  'ps -a') printf 'CONTAINER ID  IMAGE\nccc  img\n';;
  'ps ') printf 'CONTAINER ID  IMAGE\naaa  img\n';;
  *) printf '%s\n' "$*" >> "$OPLOG";;
esac
DATA
    chmod +x "$TEST_ROOT/bin/docker"
    bash -c '"$MARKSHARC_ROOT/modules/docker/bin/cleanup-docker"' > "$TEST_ROOT/out" 2>&1 || return 1
    [[ $(<"$OPLOG") == $'kill aaa\nrm ccc' ]] || { cat "$OPLOG"; return 2; }
  }
  It 'cleanup-docker kills running and removes stopped containers through docker only'
    When run cleanup_case
    The status should be success
  End
  socket_case() {
    emulate -L zsh
    local script=$TEST_ROOT/fix-docker-socket
    sed "s|/var/run/docker.sock|$HOME/docker.sock|" "$MARKSHARC_ROOT/modules/docker/bin/fix-docker-socket" > "$script" || return 1
    chmod +x "$script"
    cat > "$TEST_ROOT/bin/sudo" <<'DATA'
#!/bin/sh
printf '%s\n' "$*" >> "$OPLOG"
DATA
    cat > "$TEST_ROOT/bin/stat" <<'DATA'
#!/bin/sh
printf '%s\n' other
DATA
    chmod +x "$TEST_ROOT/bin/sudo" "$TEST_ROOT/bin/stat"
    bash -c '"$1"' _ "$script" > "$TEST_ROOT/out" 2>&1
    [[ $? != 0 && $(<"$TEST_ROOT/out") == *'Docker socket missing'* && ! -s $OPLOG ]] || return 2
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$HOME/docker.sock" || return 3
    bash -c '"$1"' _ "$script" > "$TEST_ROOT/out" 2>&1 || return 4
    [[ $(<"$OPLOG") == "chgrp docker $HOME/docker.sock" ]]
  }
  It 'validates a disposable socket and delegates its group change through sudo'
    When run socket_case
    The status should be success
  End
End
