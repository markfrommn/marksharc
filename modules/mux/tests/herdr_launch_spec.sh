Describe 'Herdr launch adapters'
  mux() { "$MARKSHARC_ROOT/modules/mux/bin/marksharc-mux" "$@"; }

  tui_stub() {
    stub_command herdr 'printf "%s\0" "$@" >> "$OPLOG"
case "$*" in
  "session list --json")
    echo '\''{"sessions":[{"name":"default","running":false},{"name":"work","running":true,"socket_path":"/tmp/herdr socket"}]} '\'' ;;
  "workspace list") test "$HERDR_SESSION" = work ;;
  "machine list --json")
    echo '\''[{"label":"build","target":"ops@build","enabled":true},{"label":"off","target":"off","enabled":false}]'\'' ;;
  *" create "*) echo '\''{"result":{"root_pane":{"pane_id":"w2:p3","workspace_id":"w2"}}}'\'' ;;
  *) exit 1 ;;
esac'
  }

  tui_discovery_case() {
    tui_stub
    [[ $(mux instances herdr) == $'work\t/tmp/herdr socket' ]] || return 1
    [[ $(mux machines herdr work) == $'build\tops@build\t' ]] || return 2
    export HERDR_ENV=1 HERDR_PANE_ID=w1:p1 HERDR_SESSION=work
    [[ $(mux current herdr) == work ]] || return 3
    HERDR_SESSION=stale mux current herdr && return 4
    mux supports herdr remote || return 5
    mux supports herdr argv && return 6
    mux supports herdr autostart && return 7
    mux supports wezterm launch && return 8
    ! mux supports plain launch
  }

  It 'discovers running TUI sessions and enabled machines and rejects a dead caller'
    When run tui_discovery_case
    The status should be success
  End

  tui_launch_case() {
    tui_stub
    local cwd=$'/some dir; $name\'\n' label='two words; $ "quoted"' selected=$1
    local -a request=( --instance work --place "$selected" --cwd "$cwd" --name "$label" --env EMPTY= --env "LITERAL=$label" )
    local -a command=( herdr ) args=()
    case $selected in
      workspace) command+=( --session work ); args=( workspace create --focus ) ;;
      tab)
        export HERDR_ENV=1 HERDR_SESSION=work HERDR_PANE_ID=w4:p2 HERDR_WORKSPACE_ID=w4
        args=( tab create --workspace w4 --focus ) ;;
      hidden)
        request+=( --machine 'remote box' )
        command+=( --machine 'remote box' )
        args=( workspace create --no-focus ) ;;
    esac
    local focus=$args[-1]
    args=( "${args[@]:0:$#args-1}" --cwd "$cwd" --label "$label" --env EMPTY= --env "LITERAL=$label" "$focus" )
    local -a quoted=()
    local word
    for word in "${command[@]}" "${args[@]}"; do
      if [[ $word == "$cwd" ]]; then quoted+=( "${(qqqq)word}" ); else quoted+=( "${(qq)word}" ); fi
    done
    [[ $(mux launch herdr "${request[@]}" --dry-run) == "${(j: :)quoted}" && ! -s $OPLOG ]] || return 1
    [[ $(mux launch herdr "${request[@]}" 2> "$TEST_ROOT/err") == $'work\tw2:p3' ]] || return 2
    if [[ $selected == hidden ]]; then
      [[ $(<"$TEST_ROOT/err") == *"'--machine' 'remote box' 'workspace' 'focus' 'w2'"* ]] || return 3
    fi
    printf '%s\0' "${command[@]:1}" "${args[@]}" > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG"
  }

  Context 'TUI placements'
    Parameters:value workspace tab hidden
    It 'previews the exact command and launches with literal arguments'
      When run tui_launch_case "$1"
      The status should be success
    End
  End

  tui_fallback_case() {
    tui_stub
    export HERDR_ENV=1 HERDR_PANE_ID=w4:p2 HERDR_SESSION=work HERDR_WORKSPACE_ID=w4
    [[ $(mux launch herdr --instance work --machine build --place tab --no-focus 2> "$TEST_ROOT/err") == $'work\tw2:p3' ]] || return 1
    [[ $(<"$TEST_ROOT/err") == *'uses a new workspace'* ]] || return 2
    printf '%s\0' --machine build workspace create --no-focus > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG" || return 3
    : > "$OPLOG"
    mux launch herdr --instance work -- /bin/echo 'not startup input' 2>/dev/null && return 4
    mux launch herdr --machine build --cwd '~/work' 2>/dev/null && return 5
    [[ ! -s $OPLOG ]]
  }

  It 'falls back across machines and refuses direct TUI argv'
    When run tui_fallback_case
    The status should be success
  End

  hc_stub() {
    stub_command hc 'printf "%s\0" "${HC_SOCKET-}" "${HC_SESSION-}" "$@" >> "$OPLOG"
case "$1" in
  machine) echo '\''{"machines":[{"name":"mac","target":"ops@mac","host":"mac.local"},{"name":"alias","target":"alias","host":null}]}'\'' ;;
  get) echo '\''{"labels":{"herdr.space":"sp1234567890abcdef1234567890abcdef"}}'\'' ;;
  run)
    for arg do if [ "$arg" = --on ]; then echo '\''{"address":"mac/t5"}'\''; exit; fi; done
    echo '\''{"address":"t5"}'\'' ;;
  *) exit 1 ;;
esac'
  }

  hc_lock_setup() {
    local root=$XDG_STATE_HOME/herdr-core
    local socket=$TEST_ROOT/core.sock
    mkdir -p "$root/work" "$root/stale"
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" socket "$socket" || return 1
    print -rn -- "$socket" > "$root/work/core.lock"
    print -rn -- "$TEST_ROOT/stale.sock" > "$root/stale/core.lock"
    export HC_TERMINAL_ID=t4 HC_TERMINAL_SOCKET=$socket HC_SESSION=ignored
  }

  hc_discovery_case() {
    hc_stub
    hc_lock_setup || return 1
    [[ $(mux instances herdr-core) == $'work\t'"$HC_TERMINAL_SOCKET" ]] || return 2
    [[ $(mux current herdr-core) == work ]] || return 3
    HC_TERMINAL_SOCKET=$TEST_ROOT/stale.sock mux current herdr-core && return 4
    [[ -z $(mux machines herdr-core stale) && ! -s $OPLOG ]] || return 5
    [[ $(mux machines herdr-core work) == $'mac\tops@mac\tmac.local\nalias\talias\t' ]] || return 6
    printf '%s\0' "$HC_TERMINAL_SOCKET" ignored machine ls --json > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG" || return 7
    mux supports herdr-core autostart && mux supports herdr-core remote && mux supports herdr-core argv
  }

  It 'discovers Core instances by socket and reads machines only from the selected live core'
    When run hc_discovery_case
    The status should be success
  End

  hc_tab_case() {
    hc_stub
    hc_lock_setup || return 1
    local cwd=$'/work dir; $d\'\n' label='two words; $ "quoted"'
    local preview
    local -a request=( --instance work --cwd "$cwd" --name "$label" --place tab --no-focus --env EMPTY= -- /bin/echo "$label" )
    preview=$(mux launch herdr-core --dry-run "${request[@]}") || return 2
    [[ $preview == "'env' 'HC_SOCKET=$HC_TERMINAL_SOCKET' 'hc' 'get' 't4' '--json'"$'\n'* ]] || return 3
    [[ $preview == *"'--label' 'herdr.space=<caller-space-or-new-id>' '--cwd' ${(qqqq)cwd} '--' 'env' 'EMPTY=' '/bin/echo' ${(qq)label}" && ! -s $OPLOG ]] || return 4
    [[ $(mux launch herdr-core "${request[@]}") == $'work\tt5' ]] || return 5
    printf '%s\0' "$HC_TERMINAL_SOCKET" ignored get t4 --json \
      "$HC_TERMINAL_SOCKET" ignored run --bg --no-parent --no-notify --label "marksharc.name=$label" \
      --label herdr.space=sp1234567890abcdef1234567890abcdef --cwd "$cwd" -- env EMPTY= /bin/echo "$label" > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG"
  }

  It 'reuses the caller Core space and previews the lookup without running it'
    When run hc_tab_case
    The status should be success
  End

  hc_remote_case() {
    hc_stub
    local tail='work dir; $ "quoted"'
    local -a request=( --instance work --machine mac --cwd "~/$tail" --place hidden --env EMPTY= -- /bin/echo "$tail" )
    local wrapper='CDPATH= cd -- "$HOME/$1" && shift && exec "$@"'
    local preview
    preview=$(mux launch herdr-core --dry-run "${request[@]}") || return 1
    [[ $preview == "'env' 'HC_SOCKET=' 'HC_SESSION=work' 'hc' 'run' '--bg' '--no-parent' '--no-notify' '--on' 'mac' '--' 'env' 'EMPTY=' 'sh' '-c' ${(qq)wrapper} 'sh' ${(qq)tail} '/bin/echo' ${(qq)tail}" && ! -s $OPLOG ]] || return 2
    [[ $(mux launch herdr-core "${request[@]}" 2> "$TEST_ROOT/err") == $'work\tmac/t5' ]] || return 3
    [[ $(<"$TEST_ROOT/err") == *"'attach' 'mac/t5'"* ]] || return 4
    printf '%s\0' '' work run --bg --no-parent --no-notify --on mac -- env EMPTY= sh -c "$wrapper" sh "$tail" /bin/echo "$tail" > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG" || return 5
    mkdir -- "$HOME/$tail"
    [[ $(sh -c "$wrapper" sh "$tail" pwd) == "$HOME/$tail" ]]
  }

  It 'passes a remote-home directory as argv and reports how to attach to a hidden terminal'
    When run hc_remote_case
    The status should be success
  End

  hc_workspace_case() {
    hc_stub
    local preview space
    preview=$(mux launch herdr-core --dry-run --machine mac --place tab --cwd /remote/absolute --no-focus 2> "$TEST_ROOT/err") || return 1
    [[ $(<"$TEST_ROOT/err") == *'uses a new workspace'* && ! -s $OPLOG ]] || return 2
    [[ $preview =~ "^'env' 'HC_SOCKET=' 'HC_SESSION=default' 'hc' 'run' '--bg' '--no-parent' '--no-notify' '--on' 'mac' '--label' 'herdr.space=sp[0-9a-f]{32}' '--cwd' '/remote/absolute'$" ]] || return 3
    [[ $(mux launch herdr-core --place workspace --env EMPTY= --no-focus) == $'default\tt5' ]] || return 4
    local -a args=()
    # Read the NUL-delimited argument stream without collapsing empty arguments.
    while IFS='' read -r -d '' space; do args+=( "$space" ); done < "$OPLOG"
    [[ $args[8] =~ '^herdr.space=sp[0-9a-f]{32}$' && ${args[-3,-1]} == 'sh -c exec "${SHELL:-/bin/sh}" -l' ]]
  }

  It 'creates a fresh Core space and supplies a login shell when only environment is set'
    When run hc_workspace_case
    The status should be success
  End

  hc_focus_case() {
    hc_stub
    hc_lock_setup || return 1
    export APP_LOG="$TEST_ROOT/app.log" APP_SEEN="$TEST_ROOT/app.seen"
    stub_command herdr-app 'printf "%s\0" "$@" >> "$APP_LOG"
case "$1" in
  ls)
    if [ ! -e "$APP_SEEN" ]; then
      : > "$APP_SEEN"
      echo '\''{"spaces":[{"id":"other","tabs":[{"terminals":[{"terminal":"t5"}]}]}]}'\''
    else
      echo '\''{"spaces":[{"id":"other","tabs":[{"terminals":[{"terminal":"t5"}]}]},{"id":"viewer/sp1234567890abcdef1234567890abcdef","tabs":[{"terminals":[{"terminal":"viewer/t5"}]}]}]}'\''
    fi ;;
  do) echo "{\"ok\":true}" ;;
esac'
    local preview
    preview=$(mux launch herdr-core --place tab --dry-run) || return 2
    [[ $preview == *$'\n'"'herdr-app' 'ls'"$'\n'"'herdr-app' 'do' 'agent.focus' '--terminal' '<app-terminal-address>'" ]] || return 3
    [[ ! -s $OPLOG && ! -e $APP_LOG ]] || return 4
    [[ $(mux launch herdr-core --place tab) == $'work\tt5' ]] || return 5
    printf '%s\0' ls ls do agent.focus --terminal viewer/t5 > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$APP_LOG" || return 6
    : > "$APP_LOG"
    mux launch herdr-core --place tab --no-focus >/dev/null || return 7
    mux launch herdr-core --place hidden >/dev/null 2>&1 || return 8
    [[ ! -s $APP_LOG ]]
  }

  It 'focuses the terminal in the app by its visible space and app address'
    When run hc_focus_case
    The status should be success
  End

  hc_no_app_case() {
    hc_stub
    hc_lock_setup || return 1
    stub_command herdr-app 'if [ "$1" = ls ]; then exit 1; fi; echo unexpected-focus >&2; exit 2'
    [[ $(mux launch herdr-core --place tab) == $'work\tt5' ]]
  }

  It 'returns the terminal address when there is no app window'
    When run hc_no_app_case
    The status should be success
  End

  failed_creation_case() {
    local outcome=$1 tool kind
    for tool in herdr hc; do
      kind=$tool
      [[ $tool != hc ]] || kind=herdr-core
      case $outcome in
        cli) stub_command "$tool" 'echo provider-error >&2; exit 7' ;;
        malformed) stub_command "$tool" 'echo "[not JSON]"' ;;
        missing) stub_command "$tool" 'echo "{}"' ;;
      esac
      mux launch "$kind" --instance work --place workspace > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
      [[ $? == 1 && ! -s $TEST_ROOT/out ]] || return 1
      case $outcome in
        cli) [[ $(<"$TEST_ROOT/err") == provider-error ]] || return 2 ;;
        malformed) [[ $(<"$TEST_ROOT/err") == *'invalid JSON' ]] || return 3 ;;
        missing) [[ $(<"$TEST_ROOT/err") == *'did not return'* ]] || return 4 ;;
      esac
    done
  }

  Context 'failed creation replies'
    Parameters:value cli malformed missing
    It 'reports provider errors and invalid results without printing a success address'
      When run failed_creation_case "$1"
      The status should be success
    End
  End
End
