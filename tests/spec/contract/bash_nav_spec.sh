Describe 'Bash directory navigation'
  nav_pty_case() {
    "$PYTHON" "$MARKSHARC_ROOT/tests/spec/contract/bash_nav_pty.py"
  }
  It 'navigates and redraws in a terminal while preserving bindings'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run nav_pty_case
    The status should be success
  End
End
