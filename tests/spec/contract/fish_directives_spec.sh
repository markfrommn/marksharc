Describe 'fish caller-state directives'
  exit_case() {
    mkdir -p "$TEST_ROOT/tmp"
    cat > "$TEST_ROOT/bin/exit-helper" <<'DATA'
#!/bin/sh
printf '%s' "$MARKSHARC_DIRECTIVES" > "$TEST_ROOT/directive-path"
case "$EXIT_MODE" in
  default) printf 'exit\n' ;;
  explicit) printf 'exit\t00042\n' ;;
  invalid) printf 'exit\t256\nexit\tnope\n' ;;
  command-fail|apply-fail|remove-fail) printf 'exit\t0\n' ;;
esac >> "$MARKSHARC_DIRECTIVES"
[ "$EXIT_MODE" != apply-fail ] || printf 'cd\t/nonexistent-marksharc-dir\n' >> "$MARKSHARC_DIRECTIVES"
printf 'setenv\tAFTER\tapplied\n' >> "$MARKSHARC_DIRECTIVES"
[ "$EXIT_MODE" != command-fail ]
DATA
    chmod +x "$TEST_ROOT/bin/exit-helper"
    if [ "$1" = remove-fail ]; then
      printf '#!/bin/sh\nexit 9\n' > "$TEST_ROOT/bin/rm"
      chmod +x "$TEST_ROOT/bin/rm"
    fi
    TMPDIR="$TEST_ROOT/tmp" EXIT_MODE="$1" fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      function on_exit --on-event fish_exit
        set -l remaining 0
        test -e (cat "$TEST_ROOT/directive-path"); and set remaining 1
        printf "%s|%s\n" "$AFTER" $remaining > "$TEST_ROOT/exit-state"
      end
      _ms_fish_run_with_directives exit-helper
      echo continued
    ' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    result=$?
    [ "$1" != remove-fail ] || /bin/rm -f "$TEST_ROOT/bin/rm"
    case "$1" in
      default) [ "$result" -eq 0 ] && [ ! -s "$TEST_ROOT/out" ] && [ "$(cat "$TEST_ROOT/exit-state")" = 'applied|0' ] ;;
      explicit) [ "$result" -eq 42 ] && [ ! -s "$TEST_ROOT/out" ] && [ "$(cat "$TEST_ROOT/exit-state")" = 'applied|0' ] ;;
      invalid) [ "$result" -eq 0 ] && grep -q continued "$TEST_ROOT/out" && grep -q 'invalid exit' "$TEST_ROOT/err" ;;
      command-fail|apply-fail|remove-fail) [ "$result" -eq 0 ] && grep -q continued "$TEST_ROOT/out" ;;
    esac
  }
  Parameters:value default explicit invalid command-fail apply-fail remove-fail
  It 'defers exit, removes the file and validates status: $1'
    When run exit_case "$1"
    The status should be success
  End
  apply_case() {
    printf 'setenv\tVALUE\t%%25%%09%%0A$(touch hostile)\nunsetenv\tREMOVE_ME\nunknown\tvalue\n' > "$TEST_ROOT/directives"
    fish -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      set -gx REMOVE_ME present
      _ms_apply_directives "$TEST_ROOT/directives"
      test "$VALUE" = (printf "%%\t\n\$(touch hostile)" | string collect -N)
      and not set -q REMOVE_ME
      and not test -e hostile
    ' 2> "$TEST_ROOT/err" || return 1
    grep -q 'unknown directive' "$TEST_ROOT/err"
  }
  It 'applies encoded values literally, removes variables and warns on unknown operations'
    When run apply_case
    The status should be success
  End

  malformed_case() {
    printf 'setenv\tBAD-NAME\toops\nsetenv\tKEPT\nsetenv\tKEPT\tbad\textra\nunsetenv\tKEPT\textra\nsetenv\tEMPTY\t\n' > "$TEST_ROOT/directives"
    fish -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      set -gx KEPT original
      set -gx EMPTY nonempty
      _ms_apply_directives "$TEST_ROOT/directives"
      test "$KEPT" = original
      and test "$EMPTY" = ""
    '
  }
  It 'ignores malformed records and accepts an empty value'
    When run malformed_case
    The status should be success
  End

  directory_case() {
    mkdir -p "$TEST_ROOT/a b"
    printf 'cd\t%s\npushd\t%s\n' "$TEST_ROOT/a b" "$HOME" > "$TEST_ROOT/directives"
    fish -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      _ms_apply_directives "$TEST_ROOT/directives"
      test "$PWD" = "$HOME"
      and test "$dirstack[1]" = "$TEST_ROOT/a b"
    '
  }
  It 'applies directory changes in the caller'
    When run directory_case
    The status should be success
  End

  trailing_newline_case() {
    printf 'setenv\tVALUE\tline%%0A%%0A\n' > "$TEST_ROOT/directives"
    fish -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      _ms_apply_directives "$TEST_ROOT/directives"
      test "$VALUE" = (printf "line\n\n" | string collect -N)
    '
  }
  It 'retains trailing newlines in encoded values'
    When run trailing_newline_case
    The status should be success
  End

  universal_case() {
    printf 'unsetenv\tPERSISTED\n' > "$TEST_ROOT/directives"
    fish -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      set -Ux PERSISTED existing
      _ms_apply_directives "$TEST_ROOT/directives"
      set -l result $status
      set -q -U PERSISTED
      or exit 2
      set -e -U PERSISTED
      test $result -ne 0
    ' 2> "$TEST_ROOT/err" || return 1
    grep -q 'unsafe directive target' "$TEST_ROOT/err"
  }
  It 'rejects unsetting a universal variable without changing persisted configuration'
    When run universal_case
    The status should be success
  End

  readonly_case() {
    printf 'setenv\tversion\tchanged\nsetenv\tAFTER_ERROR\tchanged\n' > "$TEST_ROOT/directives"
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      _ms_apply_directives "$TEST_ROOT/directives"
      test $status -ne 0; and not set -q AFTER_ERROR
    ' 2> "$TEST_ROOT/err"
  }
  It 'reports a failure when a target variable is read-only'
    When run readonly_case
    The status should be success
  End

  wrapper_case() {
    stub_command apply-state 'printf "setenv\tRESULT\tchanged\n" >> "$MARKSHARC_DIRECTIVES"; exit 7'
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      _ms_fish_run_with_directives apply-state
      set -l result $status
      test $result -eq 7; and test "$RESULT" = changed
    '
  }
  It 'applies completed directives and preserves a command failure'
    When run wrapper_case
    The status should be success
  End

  module_wrapper_case() {
    stub_command cwf-new 'printf "cd\t%s\n" "$TEST_ROOT" >> "$MARKSHARC_DIRECTIVES"'
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/modules.fish"
      _ms_fish_init_module "$MARKSHARC_ROOT/modules/cwf"
      cwf-new
      test "$PWD" = "$TEST_ROOT"
    '
  }
  It 'installs a fish caller-state wrapper for the enabled command module'
    When run module_wrapper_case
    The status should be success
  End

  wrapper_session_case() {
    stub_command setup-ssh-agent 'printf "setenv\tSEEN_SESSION\t%s\n" "${MARKSHARC_SESSION:-missing}" >> "$MARKSHARC_DIRECTIVES"'
    fish --no-config -c '
      source "$MARKSHARC_ROOT/core/fish/lib/directives.fish"
      source "$MARKSHARC_ROOT/core/fish/lib/modules.fish"
      set -g MARKSHARC_SESSION interactive
      _ms_fish_init_module "$MARKSHARC_ROOT/modules/ssh-agent"
      setup-ssh-agent
      test "$SEEN_SESSION" = interactive
    '
  }
  It 'passes the session class to the SSH-agent executable'
    When run wrapper_session_case
    The status should be success
  End
End
