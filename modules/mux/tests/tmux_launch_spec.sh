Describe 'tmux launch adapter'
  tmux_adapter() { source "$MARKSHARC_ROOT/modules/mux/adapters/tmux.zsh" "$@"; }
  _ms_mux_preview() { printf "'%s' " "$@"; print; }

  tmux_stub() {
    stub_command tmux 'printf "%s\0" "$@" >> "$OPLOG"
case "$*" in
  *display-message*) printf "\0443\n" ;;
  *list-sessions*) printf "\0443\twork\n" ;;
  *new-window*|*new-session*) printf "\0443\t\0443:@4.%%5\n" ;;
esac'
  }

  inventory_case() {
    emulate -L zsh
    tmux_stub
    export TMUX='/tmp/server,socket name,42,0' TMUX_PANE='%5'
    [[ $(tmux_adapter current) == '$3' ]] || return 1
    [[ $(tmux_adapter instances) == $'$3\twork' ]] || return 2
    [[ -z $(tmux_adapter machines) ]] || return 3
    tmux_adapter supports launch || return 4
    tmux_adapter supports place-hidden || return 5
    tmux_adapter supports remote && return 6
    stub_command tmux 'exit 1'
    tmux_adapter current && return 7
    TMUX_PANE=invalid
    tmux_adapter current && return 8
    return 0
  }
  It 'reports capabilities and running sessions and rejects a stale marker'
    When run inventory_case
    The status should be success
  End

  launch_case() {
    emulate -L zsh
    tmux_stub
    export TMUX='/tmp/server,socket name,42,0'
    local -A launch_req=( instance '$3' machine '' cwd '/tmp/#literal;' name 'name #{};' place tab focus 0 dry_run 0 )
    local -a launch_env=( 'EMPTY=' 'DATA=space; $";' )
    local -a launch_argv=( /bin/echo $'line one\nline two;' '$HOME' )
    [[ $(tmux_adapter launch) == $'$3\t$3:@4.%5' ]] || return 1
    printf '%s\0' -S '/tmp/server,socket name' new-window -t '$3:' -d -c '/tmp/##literal\;' -n 'name ##{}\;' -e 'EMPTY=' -e 'DATA=space; $"\;' -P -F $'#{session_id}\t#{session_id}:#{window_id}.#{pane_id}' -- /bin/echo $'line one\nline two'\\\; '$HOME' > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG"
  }
  It 'passes every launch value as one tmux argument'
    When run launch_case
    The status should be success
  End

  launch_modes_case() {
    emulate -L zsh
    tmux_stub
    local -A launch_req=( instance '' machine '' cwd '' name '' place workspace focus 1 dry_run 0 )
    local -a launch_env=() launch_argv=( 'a; $command' )
    [[ $(tmux_adapter launch 2> "$TEST_ROOT/err") == $'$3\t$3:@4.%5' ]] || return 1
    [[ $(<"$TEST_ROOT/err") == *'tmux attach -t marksharc'* ]] || return 2
    printf '%s\0' new-session -d -s marksharc -P -F $'#{session_id}\t#{session_id}:#{window_id}.#{pane_id}' -- /bin/sh -c 'exec "$@"' sh 'a; $command' > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG" || return 3
    : > "$OPLOG"
    launch_req[dry_run]=1
    [[ $(tmux_adapter launch) == *"'new-session' '-d' '-s' 'marksharc'"* ]] || return 4
    [[ ! -s $OPLOG ]] || return 5
    launch_req[machine]=remote
    tmux_adapter launch 2>/dev/null && return 6
    [[ ! -s $OPLOG ]]
  }
  It 'autostarts detached, treats a single program as data, and previews without execution'
    When run launch_modes_case
    The status should be success
  End
End
