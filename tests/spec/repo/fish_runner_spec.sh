Describe 'tests/run-fish-units'
  # fake_fishtape VERSION: a stand-in fishtape function that reports VERSION and echoes what it was given.
  fake_fishtape() {
    mkdir -p "$TEST_ROOT/fake"
    cat > "$TEST_ROOT/fake/fishtape.fish" <<EOF
function fishtape
    if test "\$argv[1]" = --version
        echo 'fishtape, version $1'
        return 0
    end
    printf '%s\n' "home=\$HOME" "root=\$MARKSHARC_ROOT" "args=\$argv" "leak=\$LEAK"
    test -d "\$HOME"; and echo home-exists
    echo 'ok 1 fake'
end
EOF
  }
  run_units() { env LEAK=1 FISHTAPE_FUNC="$TEST_ROOT/fake/fishtape.fish" "$MARKSHARC_ROOT/tests/run-fish-units" "$@"; }

  It 'refuses to run without fishtape'
    When run command env FISHTAPE_FUNC="$TEST_ROOT/missing" "$MARKSHARC_ROOT/tests/run-fish-units"
    The status should equal 127
    The stderr should include 'fishtape 3.0.1 required'
  End
  It 'refuses a fishtape other than the pinned version'
    fake_fishtape 2.1.3
    When run run_units
    The status should equal 127
    The stderr should include "reports 'fishtape, version 2.1.3'"
  End
  It 'runs the pinned fishtape over the given files with a scrubbed environment and its own HOME'
    fake_fishtape 3.0.1
    When run run_units modules/ps/tests/ps_test.fish
    The status should be success
    The line 2 of output should equal "root=$MARKSHARC_ROOT"
    The line 3 of output should equal 'args=modules/ps/tests/ps_test.fish'
    The line 4 of output should equal 'leak='
    The line 5 of output should equal 'home-exists'
    The line 1 of output should not equal "home=$HOME"
  End
  It 'discovers module and core unit files by default'
    fake_fishtape 3.0.1
    When run run_units
    The status should be success
    The line 3 of output should include 'modules/ps/tests/ps_test.fish'
  End

  # fake_reporting_fishtape LINE: a pinned-version fishtape that prints LINE and exits 0.
  fake_reporting_fishtape() {
    mkdir -p "$TEST_ROOT/fake"
    cat > "$TEST_ROOT/fake/fishtape.fish" <<EOF
function fishtape
    if test "\$argv[1]" = --version
        echo 'fishtape, version 3.0.1'
        return 0
    end
    echo '$1'
end
EOF
  }
  It 'fails when an assertion reports not ok even if fishtape exits 0'
    fake_reporting_fishtape 'not ok 1 broken'
    When run run_units modules/ps/tests/ps_test.fish
    The status should be failure
    The output should include 'not ok 1 broken'
    The stderr should include 'an assertion failed'
  End
  It 'fails when fish reports an error, which fishtape does not count'
    fake_reporting_fishtape 'fish: Unknown command: cat'
    When run run_units modules/ps/tests/ps_test.fish
    The status should be failure
    The output should include 'Unknown command'
    The stderr should include 'fish reported an error'
  End
  It 'fails when no assertion ran'
    fake_reporting_fishtape '1..0'
    When run run_units modules/ps/tests/ps_test.fish
    The status should be failure
    The output should include '1..0'
    The stderr should include 'no assertion ran'
  End

  workspace_after_run() {
    fake_fishtape 3.0.1
    home=$(run_units | sed -n 's/^home=//p')
    [ -n "$home" ] || { echo 'no home reported'; return 1; }
    if [ -e "$home" ]; then echo "left behind: $home"; else echo removed; fi
  }
  It 'removes its throwaway HOME afterwards'
    When call workspace_after_run
    The output should equal removed
  End
End
