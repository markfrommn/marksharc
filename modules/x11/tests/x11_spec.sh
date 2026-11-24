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
  Parameters:value inherited empty unset
  It "keeps the $1 DISPLAY contract without sleeping, probing or pinging"
    When run x11_case "$1"
    The status should be success
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
