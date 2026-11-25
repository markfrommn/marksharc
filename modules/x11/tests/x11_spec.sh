Describe 'x11 DISPLAY bookkeeping'
  x11_case() {
    emulate -L zsh
    local MARKSHARC_HOME=$MARKSHARC_ROOT
    source "$MARKSHARC_HOME/core/zsh/lib/directives.zsh"
    local tool
    # Any probe or delay would be logged.
    for tool in sleep ping w tty; do
      printf '#!/bin/sh\nprintf "%%s\\n" "%s $*" >> "$OPLOG"\n' "$tool" > "$TEST_ROOT/bin/$tool"
      chmod +x "$TEST_ROOT/bin/$tool"
    done
    load_mfn x11
    case $1 in
      inherited)
        export DISPLAY=:7; unset DISPLAY_ORIG
        setup-x11-display
        [[ $DISPLAY == :7 && $(printenv DISPLAY_ORIG) == :7 && $(printenv DISPLAY) == :7 ]] || return 1;;
      empty)
        export DISPLAY= DISPLAY_ORIG=stale
        setup-x11-display
        (( ! ${+DISPLAY} && ! ${+DISPLAY_ORIG} )) || return 2;;
      unset)
        unset DISPLAY; export DISPLAY_ORIG=stale
        setup-x11-display
        (( ! ${+DISPLAY} && ! ${+DISPLAY_ORIG} )) || return 3;;
    esac
    [[ -z $(<"$OPLOG") ]] || { cat "$OPLOG"; return 4; }
  }
  Describe 'inherited display'
    Parameters:value inherited empty unset
    It "keeps the $1 DISPLAY contract without sleeping, probing or pinging"
      When run x11_case "$1"
      The status should be success
    End
  End
  launch_parent_display_case() {
    emulate -L zsh
    local MARKSHARC_HOME=$MARKSHARC_ROOT expected
    source "$MARKSHARC_HOME/core/zsh/lib/directives.zsh"
    load_mfn x11
    export DISPLAY=:7 MARKSHARC_HOST=fixture LAUNCH_PARENT_HOST=fixture LAUNCH_PARENT_DISPLAY=:8
    export TMUX=/tmp/fixture,1,0 TMUX_PANE=%7
    stub_command tmux 'case "$X11_TEST_MODE" in
  client) printf "%s\n" "DISPLAY=\"localhost:12.0\"; export DISPLAY;" ;;
  client-removed) printf "%s\n" "unset DISPLAY;" ;;
esac'
    stub_command xdpyinfo 'printf "PROBE\n" >> "$OPLOG"; exit 1'
    export X11_TEST_MODE=$1
    local -a args=( --startup )
    case $1 in
      usable) expected=:8 ;;
      shell-host) expected=:8; LAUNCH_PARENT_HOST=${HOST%%.*}; unset MARKSHARC_HOST ;;
      foreign) expected=:7; LAUNCH_PARENT_HOST=elsewhere ;;
      empty) expected=:7; LAUNCH_PARENT_DISPLAY='' ;;
      missing-host) expected=:7; unset LAUNCH_PARENT_HOST ;;
      client) expected=localhost:12.0 ;;
      client-removed) expected='' ;;
      manual) expected=:7; args=(); unset TMUX TMUX_PANE ;;
    esac
    setup-x11-display "${args[@]}" || return 1
    [[ ${DISPLAY-} == "$expected" && ${DISPLAY_ORIG-} == "$expected" && ! -s $OPLOG ]] || return 2
    [[ $1 != client-removed ]] || (( ! ${+DISPLAY} && ! ${+DISPLAY_ORIG} ))
  }
  Describe 'launch-parent display'
    Parameters:value usable shell-host foreign empty missing-host client client-removed manual
    It "handles $1 without probing"
      When run launch_parent_display_case "$1"
      The status should be success
    End
  End
  init_case() {
    module_run x11 'setup-x11-display() { print CALLED; }; source "$MOD_INIT"' || return 1
    [[ $(<"$TEST_ROOT/out") == CALLED ]]
  }
  It 'runs setup-x11-display from init'
    When run init_case
    The status should be success
  End
End
