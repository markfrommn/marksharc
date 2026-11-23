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
End
