Describe 'launch foundation JSON'
  json_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/json.zsh" || return 1
    local -A json_values=() json_types=()
    _ms_json_parse '{"machines":[{"name":"a\"b","target":"host","enabled":true},{"name":"c","empty":"","n":null}],"nested":{"x/y":"v"}}' || return 2
    [[ ${json_values[/machines]} == 2 && ${json_types[/machines]} == array ]] || return 3
    [[ ${json_values[/machines/0/name]} == 'a"b' && ${json_types[/machines/0/enabled]} == boolean ]] || return 4
    [[ ${json_values[/machines/1/empty]} == '' && ${json_types[/machines/1/n]} == null ]] || return 5
    [[ ${json_values[/nested/x~1y]} == v ]] || return 6
    ! _ms_json_parse '{"x": [1,]}' || return 7
    _ms_json_parse '["\u00e9","\uD83D\uDE00",-1.5e+2]' || return 8
    local root=''
    [[ ${json_values[$root]} == 3 && ${json_values[/0]} == é && ${json_values[/1]} == 😀 && ${json_types[/2]} == number ]] || return 9
    ! _ms_json_parse '["\uD83Dx"]' || return 10
    ! _ms_json_parse 'true garbage' || return 11
    _ms_json_parse '["\u0000"]' || return 12
    (( ${#json_values[/0]} == 1 )) || return 13
  }
  It 'reads nested replies, escapes and scalars and rejects malformed JSON'
    When run json_case
    The status should be success
  End
End

Describe 'launch picker'
  picker_no_tty() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/pick.zsh"
    local output rc
    output=$(print -r -- $'one\tOne' | _ms_pick --flag --host 2>"$TEST_ROOT/error")
    rc=$?
    [[ $rc == 3 && -z $output && $(<"$TEST_ROOT/error") == *--host* ]]
  }
  It 'requires a terminal and explains the flag for noninteractive use'
    When run picker_no_tty
    The status should be success
  End

  picker_pty() {
    emulate -L zsh
    mkdir -p "$TEST_ROOT/pick-bin"
    cat > "$TEST_ROOT/pick-bin/gum" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$PICK_LOG"
cat
EOF
    chmod +x "$TEST_ROOT/pick-bin/gum"
    local script='source "$MARKSHARC_ROOT/core/zsh/lib/pick.zsh"; exec {fd}<&0; print -r -l -- $'"'"'a\tAlpha'"'"' $'"'"'b\tBeta'"'"' | _ms_pick --multi --header Choose --terminal-fd $fd'
    PATH="$TEST_ROOT/pick-bin:/bin:/usr/bin" PICK_LOG="$TEST_ROOT/log" "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty zsh -fc "$script" > "$TEST_ROOT/out" || return 1
    [[ $(<"$TEST_ROOT/log") == 'choose --no-limit --header Choose' ]] || return 2
    [[ $(<"$TEST_ROOT/out") == $'a\nb' ]] || return 3
    cat > "$TEST_ROOT/pick-bin/gum" <<'EOF'
#!/bin/sh
tail -n 1
EOF
    local duplicate_script=${script/Beta/Alpha}
    PATH="$TEST_ROOT/pick-bin:/bin:/usr/bin" "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty zsh -fc "$duplicate_script" > "$TEST_ROOT/out" || return 4
    [[ $(<"$TEST_ROOT/out") == b ]] || return 5
    rm "$TEST_ROOT/pick-bin/gum"
    cat > "$TEST_ROOT/pick-bin/fzf" <<'EOF'
#!/bin/sh
printf '%s\n' "$*" > "$PICK_LOG"
/bin/cat
EOF
    chmod +x "$TEST_ROOT/pick-bin/fzf"
    PATH="$TEST_ROOT/pick-bin" PICK_LOG="$TEST_ROOT/log" "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty /bin/zsh -fc "$script" > "$TEST_ROOT/out" || return 4
    [[ $(<"$TEST_ROOT/log") == '--multi --header Choose' && $(<"$TEST_ROOT/out") == $'a\nb' ]] || return 5
    rm "$TEST_ROOT/pick-bin/fzf"
    PATH="$TEST_ROOT/pick-bin" PICK_LOG="$TEST_ROOT/log" "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty /bin/zsh -fc "$script" > "$TEST_ROOT/out"
    [[ $? == 3 && $(<"$TEST_ROOT/out") == *'gum or fzf'* ]] || return 6
    cat > "$TEST_ROOT/pick-bin/gum" <<'EOF'
#!/bin/sh
exit 1
EOF
    chmod +x "$TEST_ROOT/pick-bin/gum"
    PATH="$TEST_ROOT/pick-bin:/bin:/usr/bin" PICK_LOG="$TEST_ROOT/log" "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty zsh -fc "$script" > "$TEST_ROOT/out"
    [[ $? == 1 && ! -s $TEST_ROOT/out ]]
  }
  It 'presents labels on a terminal, returns values and reports cancellation'
    When run picker_pty
    The status should be success
  End
End

Describe 'launch host resolution'
  hosts_case() {
    emulate -L zsh
    MARKSHARC_HOME=$MARKSHARC_ROOT
    source "$MARKSHARC_ROOT/core/cli/hosts-lib.zsh"
    typeset -A _ms_host_targets=( [alias]=ops@box [named]=somewhere )
    local REPLY
    _ms_launch_host_kind local && [[ $REPLY == local ]] || return 1
    _ms_launch_host_kind remote && [[ $REPLY == prompt ]] || return 2
    _ms_launch_host_kind alias && [[ $REPLY == remote ]] || return 3
    _ms_launch_host_target alias && [[ $REPLY == ops@box ]] || return 4
    local rows=$'named\tother\thostname\npeer\tops@box\talias\nthird\talias\t'
    _ms_launch_machine herdr-core named "$rows" && [[ $REPLY == named ]] || return 5
    _ms_launch_machine herdr-core alias "$rows" && [[ $REPLY == peer ]] || return 6
    rows=$'peer\tops@box\tother\nthird\talias\t'
    _ms_launch_machine herdr-core alias "$rows" 2>/dev/null && return 7
    rows=$'peer\tops@box\tother'
    _ms_launch_machine herdr-core alias "$rows" && [[ $REPLY == peer ]] || return 8
    _ms_launch_machine herdr-core missing "$rows" 2>/dev/null && return 9
    return 0
  }
  It 'classifies hosts and matches machine name, hostname and target in order'
    When run hosts_case
    The status should be success
  End

  candidates_case() {
    emulate -L zsh
    MARKSHARC_HOME=$MARKSHARC_ROOT MARKSHARC_HOST=own
    source "$MARKSHARC_ROOT/core/cli/hosts-lib.zsh"
    typeset -a _ms_host_names=( own alias disconnected )
    typeset -A _ms_host_targets=( [own]=own [alias]=ops@box [disconnected]=dead )
    local rows=$'herdr-core/one\tpeer\tops@box\tother\nherdr-core/two\tpeer\tops@box\tother\nherdr\twork\twork\t'
    local all='' filtered=''
    all=$(print -r -- "$rows" | _ms_launch_host_candidates) || return 1
    [[ $all == *$'alias\talias (ops@box) [herdr-core]'* && $all == *$'disconnected\tdisconnected (dead) []'* && $all == *$'work\twork (work) [herdr]'* ]] || { print -r -- "$all"; return 2; }
    [[ $all != *$'own\t'* ]] || return 3
    filtered=$(print -r -- "$rows" | _ms_launch_host_candidates herdr) || return 4
    [[ $filtered == *$'work\t'* && $filtered != *$'alias\t'* && $filtered != *$'disconnected\t'* ]]
  }
  It 'combines host and machine inventories and filters by reachable kind'
    When run candidates_case
    The status should be success
  End

  discovery_case() {
    emulate -L zsh
    MARKSHARC_HOME=$MARKSHARC_ROOT
    source "$MARKSHARC_ROOT/core/cli/hosts-lib.zsh"
    typeset -a _ms_disc_names=()
    typeset -A _ms_disc_targets=() _ms_disc_sources=()
    _ms_hosts_parse_hc_json '{"machines":[{"name":"one","target":null,"via":false,"temporary":false},{"name":"two","target":"two.host","via":"true","temporary":false},{"name":"skip","temporary":true}]}' || return 1
    [[ ${_ms_disc_targets[one]} == one && ${_ms_disc_targets[two]} == two.host && -z ${_ms_disc_targets[skip]-} ]]
  }
  It 'preserves discovery behavior for null fields and nonboolean values'
    When run discovery_case
    The status should be success
  End
End
