Describe 'Bash caller-state directives'
  Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
  literal_case() {
    printf 'setenv\tVALUE\t%%25%%09%%0A$(touch hostile)%%0A\nsetenv\tEMPTY\t\nunsetenv\tREMOVE_ME\nsetenv\tKEPT\tbad\textra\nsetenv\tKEPT\nsetenv\tBAD-NAME\tx\nsetenv\tLAST\tfinal' > "$TEST_ROOT/directives"
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/directives.bash"
      REMOVE_ME=present KEPT=original EMPTY=nonempty
      _ms_bash_apply_directives "$TEST_ROOT/directives" || exit 1
      [[ $VALUE == $'"'"'%\t\n$(touch hostile)\n'"'"' && $EMPTY == "" && $KEPT == original && $LAST == final ]] || exit 2
      [[ ! ${REMOVE_ME+x} && ! -e hostile ]]
    '
  }
  It 'preserves literal values, empty fields and a final line without newline'
    When run literal_case
    The status should be success
  End

  unsafe_case() {
    operation=${1%%:*}
    target=${1#*:}
    printf '%s\t%s\t%s\n' "$operation" "$target" changed > "$TEST_ROOT/directives"
    [ "$operation" != unsetenv ] || printf 'unsetenv\t%s\n' "$target" > "$TEST_ROOT/directives"
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/directives.bash"
      declare -i number=8
      declare -u uppercase=OLD
      declare -a indexed=(old)
      declare -A mapping=([old]=yes)
      readonly frozen=old
      target=old
      declare -n reference=target
      _ms_bash_apply_directives "$TEST_ROOT/directives"
      result=$?
      [[ $result -ne 0 && $number == 8 && $uppercase == OLD && ${indexed[0]} == old && ${mapping[old]} == yes && $frozen == old && $target == old ]]
    ' 2> "$TEST_ROOT/err" || return 1
    grep -q 'unsafe directive target' "$TEST_ROOT/err"
  }
  Context 'target attributes'
    Parameters:value setenv:number setenv:uppercase setenv:indexed setenv:mapping setenv:frozen setenv:reference unsetenv:reference unsetenv:frozen setenv:_ms_file
    It 'rejects unsafe target $1'
      When run unsafe_case "$1"
      The status should be success
    End
  End

  literal_directory_case() {
    mkdir -p "$TEST_ROOT/-/+1"
    printf 'cd\t-\npushd\t+1\n' > "$TEST_ROOT/directives"
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/directives.bash"
      cd "$TEST_ROOT" || exit 1
      _ms_bash_apply_directives "$TEST_ROOT/directives" || exit 2
      [[ $PWD == "$TEST_ROOT/-/+1" && ${DIRSTACK[1]} == "$TEST_ROOT/-" ]]
    '
  }
  It 'treats stack and previous-directory tokens as literal paths'
    When run literal_directory_case
    The status should be success
  End

  cleanup_after_caller_changes() {
    mkdir -p "$TEST_ROOT/tmp" "$TEST_ROOT/destination"
    stub_command change-caller 'printf "cd\t%s\nunsetenv\tPATH\n" "$TEST_ROOT/destination" > "$MARKSHARC_DIRECTIVES"'
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/directives.bash"
      cd "$TEST_ROOT" || exit 1
      TMPDIR=tmp _ms_bash_run_with_directives change-caller || exit 2
      [[ $PWD == "$TEST_ROOT/destination" && -z ${PATH+x} ]] || exit 3
    ' || return
    [ -z "$(find "$TEST_ROOT/tmp" -type f -print)" ]
  }
  It 'cleans up a relative TMPDIR after the caller changes directory and PATH'
    When run cleanup_after_caller_changes
    The status should be success
  End

  directory_case() {
    mkdir -p "$TEST_ROOT/a b"
    printf 'cd\t%s\npushd\t%s\n' "$TEST_ROOT/a b" "$TEST_ROOT" > "$TEST_ROOT/directives"
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/directives.bash"
      _ms_bash_apply_directives "$TEST_ROOT/directives" || exit 1
      [[ $PWD == "$TEST_ROOT" && ${DIRSTACK[1]} == "$TEST_ROOT/a b" ]]
    '
  }
  It 'changes the caller directory and directory stack'
    When run directory_case
    The status should be success
  End

  exit_case() {
    mkdir -p "$TEST_ROOT/tmp"
    cat > "$TEST_ROOT/bin/bash-exit-helper" <<'DATA'
#!/bin/sh
printf '%s' "$MARKSHARC_DIRECTIVES" > "$TEST_ROOT/directive-path"
case "$EXIT_MODE" in
  default) printf 'exit\n' ;;
  explicit) printf 'exit\t00042\n' ;;
  invalid) printf 'exit\t256\n' ;;
  *) printf 'exit\t0\n' ;;
esac >> "$MARKSHARC_DIRECTIVES"
[ "$EXIT_MODE" != apply-fail ] || printf 'cd\t/nonexistent-marksharc-dir\n' >> "$MARKSHARC_DIRECTIVES"
printf 'setenv\tAFTER\tapplied\n' >> "$MARKSHARC_DIRECTIVES"
[ "$EXIT_MODE" != command-fail ]
DATA
    chmod +x "$TEST_ROOT/bin/bash-exit-helper"
    if [ "$1" = remove-fail ]; then
      printf '#!/bin/sh\nexit 9\n' > "$TEST_ROOT/bin/rm"
      chmod +x "$TEST_ROOT/bin/rm"
    fi
    TMPDIR="$TEST_ROOT/tmp" EXIT_MODE="$1" "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/directives.bash"
      trap '\''[[ -e $(cat "$TEST_ROOT/directive-path") ]] && remaining=1 || remaining=0; printf "%s|%s" "${AFTER-}" "$remaining" > "$TEST_ROOT/exit-state"'\'' EXIT
      _ms_bash_run_with_directives bash-exit-helper
      result=$?
      printf "continued:%s:%s\n" "$result" "${AFTER-}"
    ' > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    result=$?
    [ "$1" != remove-fail ] || /bin/rm -f "$TEST_ROOT/bin/rm"
    case "$1" in
      default) [ "$result" -eq 0 ] && [ ! -s "$TEST_ROOT/out" ] && [ "$(cat "$TEST_ROOT/exit-state")" = 'applied|0' ] ;;
      explicit) [ "$result" -eq 42 ] && [ ! -s "$TEST_ROOT/out" ] && [ "$(cat "$TEST_ROOT/exit-state")" = 'applied|0' ] ;;
      invalid) [ "$result" -eq 0 ] && grep -q 'continued:0:applied' "$TEST_ROOT/out" && grep -q 'invalid exit' "$TEST_ROOT/err" ;;
      command-fail) [ "$result" -eq 0 ] && grep -q 'continued:1:applied' "$TEST_ROOT/out" ;;
      apply-fail) [ "$result" -eq 0 ] && grep -q 'continued:1:' "$TEST_ROOT/out" ;;
      remove-fail) [ "$result" -eq 0 ] && grep -q 'continued:9:applied' "$TEST_ROOT/out" ;;
    esac
  }
  Context 'exit handling'
    Parameters:value default explicit invalid command-fail apply-fail remove-fail
    It 'defers exit until command, application and cleanup succeed ($1)'
      When run exit_case "$1"
      The status should be success
    End
  End

  wrapper_case() {
    stub_command cwf-new 'printf "%s\n" "$MARKSHARC_CWF_NEW_HOOKS" > "$TEST_ROOT/hooks"; printf "%s\n" "$MARKSHARC_CWF_NEW_COPY_EXCLUDE" > "$TEST_ROOT/excludes"; printf "%s\n" "$@" > "$TEST_ROOT/args"; printf "cd\t%s\n" "$TEST_ROOT" >> "$MARKSHARC_DIRECTIVES"; exit 7'
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/directives.bash"
      source "$MARKSHARC_ROOT/modules/cwf/functions/bash/cwf-new.bash"
      cwf_new_post_create_hooks=(first "second hook")
      cwf_new_copy_exclude=("r:*.key" "r:a b")
      cwf-new --flag "a b"
      result=$?
      [[ $result == 7 && $PWD == "$TEST_ROOT" ]]
    ' || return 1
    [ "$(cat "$TEST_ROOT/hooks")" = "$(printf 'first\nsecond hook')" ] &&
    [ "$(cat "$TEST_ROOT/excludes")" = "$(printf 'r:*.key\nr:a b')" ] &&
    [ "$(cat "$TEST_ROOT/args")" = "$(printf '%s\n' --flag 'a b')" ]
  }
  It 'passes hook arrays and arguments while preserving command status and caller changes'
    When run wrapper_case
    The status should be success
  End

  other_wrappers_case() {
    stub_command gwt-clean 'printf "%s\n" "$MARKSHARC_GWT_CLEAN_HOOKS" > "$TEST_ROOT/gwt-hooks"; printf "%s\n" "$@" > "$TEST_ROOT/gwt-args"'
    stub_command setup-ssh-agent 'printf "%s\n" "$MARKSHARC_SESSION" > "$TEST_ROOT/session"; printf "setenv\tSSH_AUTH_SOCK\tssh.sock\n" >> "$MARKSHARC_DIRECTIVES"'
    mkdir -p "$TEST_ROOT/framework/modules/mux/bin"
    cat > "$TEST_ROOT/framework/modules/mux/bin/marksharc-mux" <<'DATA'
#!/bin/sh
printf '%s\n' "$*" >> "$TEST_ROOT/mux-args"
printf 'setenv\tDISPLAY\t:99\n' >> "$MARKSHARC_DIRECTIVES"
DATA
    chmod +x "$TEST_ROOT/framework/modules/mux/bin/marksharc-mux"
    MARKSHARC_HOME="$TEST_ROOT/framework" "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/directives.bash"
      source "$MARKSHARC_ROOT/modules/git-worktree/functions/bash/gwt-clean.bash"
      source "$MARKSHARC_ROOT/modules/ssh-agent/functions/bash/setup-ssh-agent.bash"
      source "$MARKSHARC_ROOT/modules/x11/functions/bash/setup-x11-display.bash"
      source "$MARKSHARC_ROOT/modules/mux/functions/bash/refresh-env.bash"
      source "$MARKSHARC_ROOT/modules/mux/functions/bash/fix-tmux.bash"
      gwt_clean_pre_remove_hooks=(one "two hooks")
      MARKSHARC_SESSION=interactive
      gwt-clean --yes "branch name" || exit 1
      setup-ssh-agent || exit 2
      setup-x11-display --startup || exit 3
      refresh-env || exit 4
      TMUX=1 fix-tmux || exit 5
      [[ $SSH_AUTH_SOCK == ssh.sock && $DISPLAY == :99 ]]
    ' || return 1
    [ "$(cat "$TEST_ROOT/gwt-hooks")" = "$(printf 'one\ntwo hooks')" ] &&
    [ "$(cat "$TEST_ROOT/gwt-args")" = "$(printf '%s\n' --yes 'branch name')" ] &&
    [ "$(cat "$TEST_ROOT/session")" = interactive ] &&
    [ "$(cat "$TEST_ROOT/mux-args")" = "$(printf 'refresh_env display-startup\nrefresh_env all\nrefresh_env client')" ]
  }
  It 'transports worktree hooks, session class and mux wrapper modes'
    When run other_wrappers_case
    The status should be success
  End
End
