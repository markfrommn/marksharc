# DEV-56: update (-y, --system), sync (--auto, --update, timer), hosts.conf inventory
# and picker, and push parallel SSH fan-out.
Describe 'update -y and --system'
  upd_fw() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- $'#!/usr/bin/env zsh\nexit 0' > "$MS_HOME/core/cli/sync"
    chmod +x "$MS_HOME/core/cli/sync"
    ms_env
  }

  yes_flag_case() {
    emulate -L zsh
    upd_fw
    ms_copy_module brew
    ms_copy_module mise
    ms_mod custom module.conf 'update custom-step custom-tool arg1'
    stub_command brew 'printf "brew:%s\n" "$*" >> "$OPLOG"'
    stub_command mise 'printf "mise:%s\n" "$*" >> "$OPLOG"'
    stub_command custom-tool 'printf "custom:%s|YES=%s\n" "$*" "$MARKSHARC_YES" >> "$OPLOG"'

    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 1; }
    local log1=$(<"$OPLOG")
    [[ $log1 == *'brew:update'* && $log1 == *'brew:upgrade'* && $log1 != *'brew:upgrade -y'* ]] || { print -r -- "$log1"; return 2; }
    [[ $log1 == *'mise:upgrade'* && $log1 != *'mise:upgrade -y'* ]] || { print -r -- "$log1"; return 3; }
    [[ $log1 == *'custom:arg1|YES=0'* ]] || { print -r -- "$log1"; return 4; }

    : > "$OPLOG"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update -y > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 5; }
    local log2=$(<"$OPLOG")
    [[ $log2 == *'brew:upgrade'* && $log2 != *'brew:upgrade -y'* ]] || { print -r -- "$log2"; return 6; }
    [[ $log2 == *'mise:upgrade -y'* ]] || { print -r -- "$log2"; return 7; }
    [[ $log2 == *'custom:arg1|YES=1'* ]] || { print -r -- "$log2"; return 8; }
  }
  It 'passes -y only to supported update commands and never to brew upgrade'
    When run yes_flag_case
    The status should be success
  End

  system_macos_case() {
    emulate -L zsh
    upd_fw
    stub_command sudo 'printf "sudo:%s\n" "$*" >> "$OPLOG"'
    stub_command apt 'exit 0'
    env -i "${MS_ENV[@]}" MARKSHARC_OS=darwin zsh -f "$MS_HOME/bin/marksharc" update --system --only system > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ ! -s $OPLOG && $(<"$TEST_ROOT/out") == *'no-op on macOS'* ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
    env -i "${MS_ENV[@]}" MARKSHARC_OS=darwin zsh -f "$MS_HOME/bin/marksharc" update --system --only system --dry-run > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [[ ! -s $OPLOG && $(<"$TEST_ROOT/out") == *'no-op (macOS)'* ]]
  }
  It 'treats --system as a no-op on macOS'
    When run system_macos_case
    The status should be success
  End

  system_apt_case() {
    emulate -L zsh
    upd_fw
    stub_command apt 'exit 0'
    stub_command sudo 'printf "%s\n" "$*" >> "$OPLOG"'
    env -i "${MS_ENV[@]}" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" update --system --only system > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$OPLOG") == $'apt update\napt upgrade' && $(<"$TEST_ROOT/out") == *'system: ok'* ]] || { cat "$OPLOG" "$TEST_ROOT/out"; return 2; }

    : > "$OPLOG"
    env -i "${MS_ENV[@]}" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" update --system -y --only system > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [[ $(<"$OPLOG") == $'apt update\napt upgrade -y' ]] || { cat "$OPLOG"; return 4; }

    : > "$OPLOG"
    env -i "${MS_ENV[@]}" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" update --system -y --only system --dry-run > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 5
    [[ ! -s $OPLOG && $(<"$TEST_ROOT/out") == *'sudo apt update && sudo apt upgrade -y'* ]] || { cat "$TEST_ROOT/out"; return 6; }

    # If apt update fails, apt upgrade must not run.
    : > "$OPLOG"
    stub_command sudo 'printf "%s\n" "$*" >> "$OPLOG"; [ "$2" = update ] && exit 1; exit 0'
    env -i "${MS_ENV[@]}" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" update --system --only system > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? != 0 && $(<"$OPLOG") == 'apt update' && $(<"$TEST_ROOT/out") == *'system: failed'* ]]
  }
  It 'runs sudo apt update && sudo apt upgrade on APT Linux systems and honors -y'
    When run system_apt_case
    The status should be success
  End

  system_dnf_yum_case() {
    emulate -L zsh
    upd_fw
    # Build a clean PATH without system apt/dnf/yum so stubs control package manager detection.
    local clean_bin=$TEST_ROOT/clean-bin
    mkdir -p "$clean_bin"
    ln -s "$(command -v zsh)" "$clean_bin/zsh"
    ln -s "$(command -v env)" "$clean_bin/env"
    stub_command dnf 'exit 0'
    stub_command yum 'exit 0'
    stub_command sudo 'printf "%s\n" "$*" >> "$OPLOG"'

    # When both dnf and yum exist (Fedora/RHEL), dnf wins.
    env -i "${MS_ENV[@]}" PATH="$TEST_ROOT/bin:$clean_bin" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" update --system -y --only system > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$OPLOG") == 'dnf upgrade --refresh -y' ]] || { cat "$OPLOG" "$TEST_ROOT/out"; return 2; }

    # Without dnf, yum runs update && upgrade with -y.
    rm -f "$TEST_ROOT/bin/dnf"
    : > "$OPLOG"
    env -i "${MS_ENV[@]}" PATH="$TEST_ROOT/bin:$clean_bin" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" update --system -y --only system > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [[ $(<"$OPLOG") == $'yum update -y\nyum upgrade -y' ]] || { cat "$OPLOG" "$TEST_ROOT/out"; return 4; }
  }
  It 'runs dnf upgrade --refresh on DNF systems and yum update && yum upgrade on YUM systems'
    When run system_dnf_yum_case
    The status should be success
  End
End

Describe 'sync --auto, --update, and timer'
  auto_sync_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local remote=$TEST_ROOT/remote.git writer=$TEST_ROOT/writer dirty_repo=$TEST_ROOT/dirty
    "$REAL_GIT" init -q --bare "$remote" || return 1
    "$REAL_GIT" -C "$MS_HOME" init -q || return 2
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid add . || return 3
    "$REAL_GIT" -C "$MS_HOME" -c user.name=Fixture -c user.email=f@example.invalid commit -qm initial || return 4
    "$REAL_GIT" -C "$MS_HOME" remote add origin "$remote" || return 5
    "$REAL_GIT" -C "$MS_HOME" push -qu origin HEAD || return 6
    "$REAL_GIT" clone -q "$remote" "$writer" || return 7
    print -r -- from-remote > "$writer/remote-file"
    "$REAL_GIT" -C "$writer" add remote-file || return 8
    "$REAL_GIT" -C "$writer" -c user.name=Fixture -c user.email=f@example.invalid commit -qm change || return 9
    "$REAL_GIT" -C "$writer" push -q || return 10

    # Extra dirty repository that --auto must skip without failing.
    "$REAL_GIT" clone -q "$remote" "$dirty_repo" || return 11
    print -r -- local-work > "$dirty_repo/dirty.txt"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- "set sync.repos '$dirty_repo'" > "$XDG_CONFIG_HOME/marksharc/config.conf"

    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync --auto > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$XDG_STATE_HOME/marksharc/sync/auto.log"; return 12; }
    [[ ! -s $TEST_ROOT/out && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 13; }
    [[ $(<"$MS_HOME/remote-file") == from-remote ]] || return 14
    [[ $(<"$dirty_repo/dirty.txt") == local-work ]] || return 15
    local log=$XDG_STATE_HOME/marksharc/sync/auto.log
    [[ -r $log && $(<"$log") == *'sync: updated:'* && $(<"$log") == *'sync: skipped (dirty):'* ]] || { cat "$log"; return 16; }
    [[ -s $XDG_CACHE_HOME/marksharc/${HOST%%.*}/render-id ]]
  }
  It 'runs quietly in --auto mode, logs to state dir, fast-forwards clean repos and skips dirty trees'
    When run auto_sync_case
    The status should be success
  End

  auto_lock_case() {
    emulate -L zsh
    unsetopt bg_nice
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local lockdir=$XDG_STATE_HOME/marksharc/sync
    mkdir -p "$lockdir"
    : > "$lockdir/auto.lock"
    /bin/zsh -f -c 'zmodload zsh/system zsh/zselect; zsystem flock -t 0 -f fd "$1" || exit 1; print ready > "$2"; while :; do zselect -t 100; done' -- "$lockdir/auto.lock" "$TEST_ROOT/ready" </dev/null >/dev/null 2>&1 &
    local holder=$! i result=0
    for (( i=0; i<100; i++ )); do [[ -f $TEST_ROOT/ready ]] && break; sleep 0.05; done
    [[ -f $TEST_ROOT/ready ]] || result=1
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync --auto > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || result=2
    [[ ! -s $TEST_ROOT/out && ! -s $TEST_ROOT/err && ! -e $lockdir/auto.log ]] || result=3
    kill -KILL "$holder" 2>/dev/null
    wait "$holder" 2>/dev/null
    (( result == 0 )) || return $result
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync --auto > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 4
    [[ -s $lockdir/auto.log ]]
  }
  It 'skips overlapping sync --auto runs while locked and recovers after lock release'
    When run auto_lock_case
    The status should be success
  End

  sync_update_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    print -r -- $'#!/usr/bin/env zsh\nprint -r -- "update-args:$*"' > "$MS_HOME/core/cli/update"
    chmod +x "$MS_HOME/core/cli/update"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync --update --system -y > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/out") == 'update-args:--system -y' ]] || { cat "$TEST_ROOT/out"; return 2; }

    # Reject invalid flag combinations.
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync --system > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 2 ]] || return 3
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync --auto --update > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 2 ]] || return 4
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync timer on --update > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 2 ]] || return 5
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" sync timer on --system > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 2 ]]
  }
  It 'delegates sync --update --system -y to update and rejects --update/--system on --auto and timer'
    When run sync_update_case
    The status should be success
  End

  timer_darwin_golden_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    stub_command launchctl 'printf "launchctl:%s\n" "$*" >> "$OPLOG"; exit 0'
    ms_env
    env -i "${MS_ENV[@]}" MARKSHARC_OS=darwin zsh -f "$MS_HOME/bin/marksharc" sync timer on > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    local plist=$HOME/Library/LaunchAgents/com.marksharc.sync.plist
    [[ -f $plist ]] || return 2
    local norm=$(<"$plist")
    norm=${norm//"$MS_HOME"/__MS_HOME__}
    norm=${norm//"$XDG_STATE_HOME"/__XDG_STATE_HOME__}
    print -r -- "$norm" > "$TEST_ROOT/actual.plist"
    cmp "$TEST_ROOT/actual.plist" "$MARKSHARC_ROOT/tests/fixtures/sync/com.marksharc.sync.plist" || { diff -u "$MARKSHARC_ROOT/tests/fixtures/sync/com.marksharc.sync.plist" "$TEST_ROOT/actual.plist"; return 3; }
    [[ $(<"$OPLOG") == *"launchctl:bootstrap gui/"* ]] || { cat "$OPLOG"; return 4; }

    env -i "${MS_ENV[@]}" MARKSHARC_OS=darwin zsh -f "$MS_HOME/bin/marksharc" sync timer status > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 5
    [[ $(<"$TEST_ROOT/out") == *'enabled (launchd'* ]] || return 6

    env -i "${MS_ENV[@]}" MARKSHARC_OS=darwin zsh -f "$MS_HOME/bin/marksharc" sync timer off > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 7
    [[ ! -e $plist && $(<"$OPLOG") == *"launchctl:bootout gui/"* ]]
  }
  It 'writes the golden launchd plist on macOS and manages it with launchctl'
    When run timer_darwin_golden_case
    The status should be success
  End

  timer_linux_golden_case() {
    emulate -L zsh
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    stub_command systemctl 'printf "systemctl:%s\n" "$*" >> "$OPLOG"; exit 0'
    ms_env
    env -i "${MS_ENV[@]}" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" sync timer on > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    local udir=$XDG_CONFIG_HOME/systemd/user
    [[ -f $udir/marksharc-sync.service && -f $udir/marksharc-sync.timer ]] || return 2
    local svc=$(<"$udir/marksharc-sync.service")
    svc=${svc//"$MS_HOME"/__MS_HOME__}
    print -r -- "$svc" > "$TEST_ROOT/actual.service"
    cmp "$TEST_ROOT/actual.service" "$MARKSHARC_ROOT/tests/fixtures/sync/marksharc-sync.service" || { diff -u "$MARKSHARC_ROOT/tests/fixtures/sync/marksharc-sync.service" "$TEST_ROOT/actual.service"; return 3; }
    cmp "$udir/marksharc-sync.timer" "$MARKSHARC_ROOT/tests/fixtures/sync/marksharc-sync.timer" || { diff -u "$MARKSHARC_ROOT/tests/fixtures/sync/marksharc-sync.timer" "$udir/marksharc-sync.timer"; return 4; }
    [[ $(<"$OPLOG") == *'systemctl:--user daemon-reload'* && $(<"$OPLOG") == *'systemctl:--user enable --now marksharc-sync.timer'* ]] || { cat "$OPLOG"; return 5; }

    env -i "${MS_ENV[@]}" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" sync timer status > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 6
    [[ $(<"$TEST_ROOT/out") == *'enabled (systemd'* ]] || return 7

    env -i "${MS_ENV[@]}" MARKSHARC_OS=linux zsh -f "$MS_HOME/bin/marksharc" sync timer off > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 8
    [[ ! -e $udir/marksharc-sync.service && ! -e $udir/marksharc-sync.timer && $(<"$OPLOG") == *'systemctl:--user disable --now marksharc-sync.timer'* ]]
  }
  It 'writes the golden systemd user service and timer on Linux and manages them with systemctl'
    When run timer_linux_golden_case
    The status should be success
  End
End

Describe 'hosts inventory and populate picker'
  hosts_setup() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/.ssh/conf.d"
    # Use print rather than a heredoc so leading `Include` is not parsed as a ShellSpec directive.
    print -r -- $'Include conf.d/*.conf\n\nHost alpha beta\n  User ops\n\nHost *.wildcard !negated -badflag\n  ForwardAgent no' > "$HOME/.ssh/config"
    print -r -- $'Host=gamma\n  HostName 10.0.0.9' > "$HOME/.ssh/conf.d/extra.conf"
    stub_command hc 'if [ "$1" = machine ] && [ "$2" = ls ] && [ "$3" = --json ]; then
  printf '\''{"machines":[{"name":"delta","target":"ops@delta.example.net","via":false,"temporary":false},{"name":"alpha","target":"alpha.example.net","via":false,"temporary":false},{"name":"flybox","target":"fly ssh","via":true,"temporary":false},{"name":"ephemeral","target":"eph","via":false,"temporary":true}]}'\''
  exit 0
fi
exit 1'
    ms_env
  }

  populate_pickers_case() {
    emulate -L zsh
    hosts_setup
    # Prefer gum when both gum and fzf are available.
    stub_command gum 'printf "gum:%s\n" "$*" >> "$OPLOG"; grep -E "^(alpha|delta) "'
    stub_command fzf 'printf "fzf:%s\n" "$*" >> "$OPLOG"; cat'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" hosts populate > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    local hf=$XDG_CONFIG_HOME/marksharc/hosts.conf
    [[ $(<"$OPLOG") == gum:* && $(<"$OPLOG") != *fzf:* ]] || { cat "$OPLOG"; return 2; }
    [[ $(<"$hf") == *'host alpha alpha.example.net'* && $(<"$hf") == *'host delta ops@delta.example.net'* ]] || { cat "$hf"; return 3; }
    [[ $(<"$hf") != *wildcard* && $(<"$hf") != *flybox* && $(<"$hf") != *ephemeral* ]] || { cat "$hf"; return 4; }

    # Fall back to fzf when gum is absent; already-configured entries are not duplicated.
    rm -f "$TEST_ROOT/bin/gum"
    : > "$OPLOG"
    stub_command fzf 'printf "fzf:%s\n" "$*" >> "$OPLOG"; grep -E "^(alpha|gamma) "'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" hosts populate > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 5; }
    [[ $(<"$OPLOG") == fzf:* && $(<"$hf") == *'host gamma'* && $(grep -c 'host alpha' "$hf") == 1 ]] || { cat "$hf" "$OPLOG"; return 6; }

    # hosts list / add / remove and injection refusal.
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" hosts add epsilon admin@epsilon.example.net > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 7
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" hosts list > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 8
    [[ $(<"$TEST_ROOT/out") == *$'epsilon\tadmin@epsilon.example.net'* ]] || { cat "$TEST_ROOT/out"; return 9; }
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" hosts remove gamma > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 10
    [[ $(<"$hf") != *'host gamma'* ]] || return 11
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" hosts add -oProxyCommand=bad > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 2 ]]
  }
  It 'discovers hosts from ssh config and hc machine ls, prefers gum over fzf, and rejects option injection'
    When run populate_pickers_case
    The status should be success
  End
End

Describe 'marksharc push'
  push_fw() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    cat > "$XDG_CONFIG_HOME/marksharc/hosts.conf" <<'EOF'
host localbox
host web-1 ops@web-1.example.net
host web-2
host db-1
EOF
    ms_env
  }

  push_parallel_table_case() {
    emulate -L zsh
    push_fw
    stub_command ssh '
target=
while [ $# -gt 0 ]; do
  case "$1" in
    -o) shift 2 ;;
    -n) shift ;;
    --) shift; target=$1; shift; break ;;
    *) target=$1; shift; break ;;
  esac
done
printf "%s|%s\n" "$target" "$*" >> "$OPLOG"
case "$target" in
  ops@web-1.example.net) printf "sync: updated: /srv/marksharc\n"; exit 0 ;;
  web-2) printf "sync: current: /srv/marksharc\n"; exit 0 ;;
  db-1) printf "sync: dirty: /srv/marksharc\n"; exit 1 ;;
esac
exit 0'
    env -i "${MS_ENV[@]}" MARKSHARC_HOST=localbox zsh -f "$MS_HOME/bin/marksharc" push > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local rc=$?
    local out=$(<"$TEST_ROOT/out")
    [[ $rc == 1 ]] || { print -r -- "rc=$rc"; print -r -- "$out"; return 1; }
    # Local host is skipped when pushing to all hosts.
    [[ $(<"$OPLOG") != *localbox* ]] || { cat "$OPLOG"; return 2; }
    # First line must be the table header with no stray variable output.
    [[ $out == HOST*STATUS*DURATION*DETAIL* ]] || { print -r -- "$out"; return 3; }
    [[ $out == *'web-1'*'ok'*'updated'* && $out == *'web-2'*'ok'*'current'* && $out == *'db-1'*'failed'*'sync: dirty:'* ]] || { print -r -- "$out"; return 4; }
  }
  It 'fans out over ssh skipping the local host and prints a per-host result table'
    When run push_parallel_table_case
    The status should be success
  End

  push_regex_flags_case() {
    emulate -L zsh
    push_fw
    stub_command ssh '
while [ $# -gt 0 ]; do
  case "$1" in
    -o) shift 2 ;;
    -n) shift ;;
    --) shift; target=$1; shift; break ;;
    *) target=$1; shift; break ;;
  esac
done
printf "%s|%s\n" "$target" "$*" >> "$OPLOG"
printf "render: ok\n"
exit 0'
    env -i "${MS_ENV[@]}" MARKSHARC_HOST=localbox zsh -f "$MS_HOME/bin/marksharc" push --update --system -y '^web-[0-9]+$' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 1; }
    local log=$(<"$OPLOG")
    [[ $(<"$TEST_ROOT/out") == HOST* ]] || { cat "$TEST_ROOT/out"; return 10; }
    [[ $log == *'ops@web-1.example.net|marksharc sync --update --system -y'* && $log == *'web-2|marksharc sync --update --system -y'* && $log != *db-1* ]] || { print -r -- "$log"; return 2; }

    # Multiple positional patterns produce clean table output without stray stdout.
    : > "$OPLOG"
    env -i "${MS_ENV[@]}" MARKSHARC_HOST=localbox zsh -f "$MS_HOME/bin/marksharc" push web-1 db-1 > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 11; }
    [[ $(<"$TEST_ROOT/out") == HOST* && $(<"$OPLOG") == *'ops@web-1.example.net|marksharc sync'* && $(<"$OPLOG") == *'db-1|marksharc sync'* ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 12; }

    # Invalid regex returns 2; unmatched regex returns 1; -y without --update returns 2.
    env -i "${MS_ENV[@]}" MARKSHARC_HOST=localbox zsh -f "$MS_HOME/bin/marksharc" push '[' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 2 ]] || return 3
    env -i "${MS_ENV[@]}" MARKSHARC_HOST=localbox zsh -f "$MS_HOME/bin/marksharc" push '^nomatch-[0-9]+$' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 1 ]] || return 4
    env -i "${MS_ENV[@]}" MARKSHARC_HOST=localbox zsh -f "$MS_HOME/bin/marksharc" push -y web-1 > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 2 ]]
  }
  It 'filters hosts by regex and passes --update --system -y over ssh'
    When run push_regex_flags_case
    The status should be success
  End

  push_timeout_case() {
    emulate -L zsh
    push_fw
    stub_command ssh '
while [ $# -gt 0 ]; do
  case "$1" in
    -o) shift 2 ;;
    -n) shift ;;
    --) shift; target=$1; shift; break ;;
    *) target=$1; shift; break ;;
  esac
done
if [ "$target" = web-2 ]; then
  sleep 10
  exit 0
fi
printf "sync: current: /srv/marksharc\n"
exit 0'
    env -i "${MS_ENV[@]}" MARKSHARC_HOST=localbox zsh -f "$MS_HOME/bin/marksharc" push --timeout 1 '^web-' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local rc=$?
    local out=$(<"$TEST_ROOT/out")
    [[ $rc == 1 && $out == *'web-1'*'ok'* && $out == *'web-2'*'timeout'*'timed out after 1s'* ]] || { print -r -- "rc=$rc"; print -r -- "$out"; return 1; }
  }
  It 'enforces per-host timeouts without blocking fast hosts'
    When run push_timeout_case
    The status should be success
  End
End
