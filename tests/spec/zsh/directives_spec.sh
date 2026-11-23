Describe 'caller-state directives'
  apply_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh" || return 1
    local file=$TEST_ROOT/directives
    print -r -- $'setenv\tSAFE_VALUE\t%25%09%0A$(touch hostile)\nunsetenv\tREMOVE_ME\nunknown\tvalue' > "$file"
    export REMOVE_ME=present
    _ms_apply_directives "$file" 2> "$TEST_ROOT/err" || return 2
    [[ $SAFE_VALUE == $'%\t\n$(touch hostile)' && ! ${+REMOVE_ME} -eq 1 && ! -e hostile ]] || return 3
    [[ $(<"$TEST_ROOT/err") == *unknown* ]]
  }
  It 'decodes literal values, unsets variables, and warns on unknown directives'
    When run apply_case
    The status should be success
  End
  roundtrip_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh" || return 1
    local MARKSHARC_DIRECTIVES=$TEST_ROOT/directives value=$'a%09\tline\n$(touch hostile)'
    _ms_directive_emit setenv ROUNDTRIP "$value" || return 2
    _ms_apply_directives "$MARKSHARC_DIRECTIVES" || return 3
    [[ $ROUNDTRIP == "$value" && ! -e hostile ]]
  }
  It 'round trips percent sequences, tabs, newlines and shell metacharacters'
    When run roundtrip_case
    The status should be success
  End
  wrapper_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh" || return 1
    mkdir -p "$TEST_ROOT/space dir"
    local before=$PWD
    helper() {
      _ms_directive_emit cd "$TEST_ROOT/space dir"
      _ms_directive_emit setenv WRAPPED 'literal $(false)'
      return 0
    }
    _ms_run_with_directives helper
    local rc=$?
    [[ $rc == 0 && $PWD == "$TEST_ROOT/space dir" && $WRAPPED == 'literal $(false)' ]] || { cd "$before"; return 2; }
    cd "$before"
  }
  It 'applies successful caller state changes'
    When run wrapper_case
    The status should be success
  End
  names_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    local file=$TEST_ROOT/directives
    print -r -- $'setenv\tREPLY\tnew\nsetenv\tname\tvalue\nsetenv\top\tsecond\nsetenv\tEMPTY\t\nunsetenv\tREMOVE' > "$file"
    export REPLY=old name=old op=old EMPTY=old REMOVE=yes
    _ms_apply_directives "$file" || return 1
    [[ $REPLY == new && $name == value && $op == second && $EMPTY == '' && ! ${+REMOVE} -eq 1 ]]
  }
  It 'updates caller-visible names even when they resemble implementation variables and accepts empty values'
    When run names_case
    The status should be success
  End
  directories_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    local before=$PWD MARKSHARC_DIRECTIVES=$TEST_ROOT/directives dir=$TEST_ROOT/$'-space\ttab\nline%'
    mkdir -p "$dir" || return 1
    _ms_directive_emit cd "$dir" || return 2
    _ms_directive_emit pushd "$before" || return 3
    _ms_apply_directives "$MARKSHARC_DIRECTIVES" || return 4
    [[ $PWD == "$before" && ${dirstack[1]} == "$dir" ]]
  }
  It 'changes directory and pushes encoded paths containing whitespace and punctuation'
    When run directories_case
    The status should be success
  End
  failure_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    helper_fail() { _ms_directive_emit setenv SHOULD_STAY old; return 7; }
    export SHOULD_STAY=original
    _ms_run_with_directives helper_fail
    local rc=$?
    [[ $rc == 7 && $SHOULD_STAY == old ]]
  }
  It 'applies completed state changes while preserving a command failure'
    When run failure_case
    The status should be success
  End
  malformed_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    local file=$TEST_ROOT/directives
    print -r -- $'setenv\tBAD-NAME\toops\nsetenv\tKEPT\nsetenv\tKEPT\tbad\textra\nunsetenv\tKEPT\textra' > "$file"
    export KEPT=original
    _ms_apply_directives "$file" || return 1
    [[ $KEPT == original ]]
  }
  It 'ignores malformed fields and invalid variable names'
    When run malformed_case
    The status should be success
  End
  typed_target_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    local directives=$TEST_ROOT/directives
    local -i TARGET=12
    local -a probe=(0)
    print -r -- 'setenv'$'\t''TARGET'$'\t''probe[$(touch "$HOME/INJECTED")]' > "$directives"
    _ms_apply_directives "$directives" 2> "$TEST_ROOT/err"
    local rc=$?
    [[ $rc != 0 && $TARGET == 12 && ! -e $HOME/INJECTED && -s $TEST_ROOT/err ]]
  }
  It 'rejects integer targets without evaluating directive data or changing caller state'
    When run typed_target_case
    The status should be success
  End
  scalar_special_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    local directives=$TEST_ROOT/directives PATH=/usr/bin:/bin
    local expected='$HOME/$(touch HACK):/tmp'
    print -r -- $'setenv\tPATH\t'"$expected" > "$directives"
    _ms_apply_directives "$directives" || return 1
    [[ $PATH == "$expected" && ! -e HACK ]]
  }
  It 'assigns scalar special variables as literal data'
    When run scalar_special_case
    The status should be success
  End
End
