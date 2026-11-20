Describe 'test sandbox'
  It 'gives each example a temporary HOME and XDG directories'
    When call print -r -- "$HOME $XDG_CONFIG_HOME $XDG_STATE_HOME"
    The output should equal "$TEST_ROOT/home $TEST_ROOT/home/config $TEST_ROOT/home/state"
  End
  It 'puts fixture stubs first on PATH'
    When call command -v curl
    The output should equal "$TEST_ROOT/bin/curl"
  End
  It 'makes forbidden commands fail and record the attempt'
    When run command curl https://example.invalid
    The status should equal 99
    The contents of file "$OPLOG" should equal 'FORBIDDEN curl https://example.invalid'
  End
  It 'runs zsh 5.9 or later with no startup files'
    When run command zsh -dfc 'autoload -Uz is-at-least && is-at-least 5.9'
    The status should be success
  End
End
