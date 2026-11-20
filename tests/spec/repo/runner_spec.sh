Describe 'tests/run-tests'
  # fake_shellspec VERSION: a stand-in runner that reports VERSION and echoes what it was given.
  fake_shellspec() {
    mkdir -p "$TEST_ROOT/fake"
    cat > "$TEST_ROOT/fake/shellspec" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then echo $1; exit 0; fi
printf '%s\n' "home=\$HOME" "root=\$MARKSHARC_ROOT" "args=\$*" "leak=\${LEAK:-}"
[ -d "\$HOME" ] && echo home-exists
EOF
    chmod +x "$TEST_ROOT/fake/shellspec"
  }
  run_tests() { env LEAK=1 SHELLSPEC_BIN="$TEST_ROOT/fake/shellspec" "$MARKSHARC_ROOT/tests/run-tests" "$@"; }

  It 'refuses to run without ShellSpec'
    When run command env SHELLSPEC_BIN="$TEST_ROOT/missing" "$MARKSHARC_ROOT/tests/run-tests"
    The status should equal 127
    The stderr should include 'ShellSpec 0.28.1 required'
  End
  It 'refuses a ShellSpec other than the pinned version'
    fake_shellspec 0.27.0
    When run run_tests spec/zsh
    The status should equal 127
    The stderr should include "reports '0.27.0'"
  End
  It 'runs the pinned ShellSpec with a scrubbed environment and its own HOME'
    fake_shellspec 0.28.1
    When run run_tests --shell zsh spec/zsh
    The status should be success
    The line 2 of output should equal "root=$MARKSHARC_ROOT"
    The line 3 of output should equal 'args=--shell zsh spec/zsh'
    The line 4 of output should equal 'leak='
    The line 5 of output should equal 'home-exists'
    The line 1 of output should not equal "home=$HOME"
  End
  workspace_after_run() {
    fake_shellspec 0.28.1
    home=$(run_tests | sed -n 's/^home=//p')
    [ -n "$home" ] || { echo 'no home reported'; return 1; }
    if [ -e "$home" ]; then echo "left behind: $home"; else echo removed; fi
  }
  It 'removes its throwaway HOME afterwards'
    When call workspace_after_run
    The output should equal removed
  End
End
