Describe 'cross-shell contract: Bash hooks'
  Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
  prompt_case() {
    [ -n "$PYTHON" ] || return 0
    cat > "$TEST_ROOT/bashrc" <<'EOF'
source "$MARKSHARC_ROOT/core/bash/hooks.bash"
PS1='prompt> '
trap ': DEBUG' DEBUG
foreign() { printf 'foreign:%s:%s\n' "$1" "$2" >> "$TEST_ROOT/log"; }
prompt_hook() { printf 'owned:%s:%s:%s\n' "$1" "$2" "$3" >> "$TEST_ROOT/log"; }
dir_hook() { printf 'dir:%s\n' "$PWD" >> "$TEST_ROOT/log"; }
PROMPT_COMMAND='foreign "$?" "${PIPESTATUS[*]}"'
_ms_bash_register_prompt prompt_hook
_ms_bash_register_prompt prompt_hook
_ms_bash_register_chpwd dir_hook
_ms_bash_hooks_install
EOF
    PTY_INPUT='false | true
! false | true
set -o pipefail; false | true
cd /
true
trap -p DEBUG
exit
' MARKSHARC_ROOT="$MARKSHARC_ROOT" TEST_ROOT="$TEST_ROOT" TERM=dumb \
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" --noprofile --rcfile "$TEST_ROOT/bashrc" -i > "$TEST_ROOT/out" 2>&1 || return 1
    grep -Fx 'owned:0:1:0' "$TEST_ROOT/log" >/dev/null || { cat "$TEST_ROOT/log"; return 2; }
    grep -Fx 'foreign:0:1 0' "$TEST_ROOT/log" >/dev/null || { cat "$TEST_ROOT/log"; return 3; }
    grep -Fx 'foreign:1:1 0' "$TEST_ROOT/log" >/dev/null || { cat "$TEST_ROOT/log"; return 5; }
    grep -Fx 'owned:1:1:0' "$TEST_ROOT/log" >/dev/null || { cat "$TEST_ROOT/log"; return 6; }
    [ "$(grep -c '^dir:' "$TEST_ROOT/log")" = 2 ] || { cat "$TEST_ROOT/log"; return 4; }
    grep -F "trap -- ': DEBUG' DEBUG" "$TEST_ROOT/out" >/dev/null
  }
  It 'preserves status and pipeline state for the foreign scalar hook and observes directory changes'
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run prompt_case
    The status should be success
  End

  array_case() {
    [ -n "$PYTHON" ] || return 0
    cat > "$TEST_ROOT/bashrc" <<'EOF'
source "$MARKSHARC_ROOT/core/bash/hooks.bash"
PS1='prompt> '
foreign() { printf 'first:%s:%s\n' "$1" "$2" >> "$TEST_ROOT/log"; }
second() { printf 'second\n' >> "$TEST_ROOT/log"; }
declare -a PROMPT_COMMAND
PROMPT_COMMAND[3]='foreign "$?" "${PIPESTATUS[*]}"'
PROMPT_COMMAND[8]=second
owned() { :; }
_ms_bash_register_prompt owned
_ms_bash_hooks_install
EOF
    PTY_INPUT='false | true
_ms_bash_hooks_reset; declare -p PROMPT_COMMAND
exit
' MARKSHARC_ROOT="$MARKSHARC_ROOT" TEST_ROOT="$TEST_ROOT" TERM=dumb \
      "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" --noprofile --rcfile "$TEST_ROOT/bashrc" -i > "$TEST_ROOT/out" 2>&1 || return 1
    grep -Fx 'first:0:1 0' "$TEST_ROOT/log" >/dev/null || { cat "$TEST_ROOT/log"; return 2; }
    grep -Fx second "$TEST_ROOT/log" >/dev/null || return 3
    grep -F '[3]="foreign ' "$TEST_ROOT/out" >/dev/null || { cat "$TEST_ROOT/out"; return 4; }
    grep -F '[8]="second"' "$TEST_ROOT/out" >/dev/null || return 5
  }
  It 'preserves sparse array prompt commands and restores their indices'
    Skip if 'selected Bash is older than 5.1' bash_prompt_array_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run array_case
    The status should be success
  End

  preexec_prompt_case() {
    MARKSHARC_ROOT="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_ROOT/core/bash/hooks.bash"
      bash_preexec_imported=defined
      __bp_precmd_invoke_cmd() { :; }
      precmd_functions=()
      foreign() { printf "%s:%s\n" "$1" "$2"; }
      PROMPT_COMMAND=$(printf "%s\n" '"'"'__bp_precmd_invoke_cmd "$_"'"'"' \
        '"'"'foreign "$?" "${PIPESTATUS[*]}"'"'"' __bp_interactive_mode)
      original=$PROMPT_COMMAND
      owned() { :; }
      _ms_bash_register_prompt owned
      _ms_bash_hooks_install
      BP_PIPESTATUS=(1 0)
      _ms_bash_prompt_return 1
      "${precmd_functions[0]}"
      eval "${PROMPT_COMMAND#*$'"'"'\n'"'"'}" 2>/dev/null
      _ms_bash_hooks_reset
      [[ $PROMPT_COMMAND == "$original" ]]
    '
  }
  It 'restores the pipeline snapshot for a foreign command on the bash-preexec transport'
    When run preexec_prompt_case
    The status should be success
    The output should equal '1:1 0'
  End

  backend_case() {
    MARKSHARC_ROOT="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_ROOT/core/bash/hooks.bash"
      seen=()
      blehook() { seen+=("$1"); }
      callback() { seen+=("command=$1"); }
      _ms_bash_register_preexec callback
      _ms_bash_hooks_install
      _ms_bash_preexec_dispatch "echo hi"
      _ms_bash_hooks_reset
      [[ ${seen[*]} == "PREEXEC!=_ms_bash_preexec_dispatch command=echo hi PREEXEC-=_ms_bash_preexec_dispatch" ]] || exit 1
      unset -f blehook
      preexec_functions=(foreign)
      _ms_bash_register_preexec callback
      _ms_bash_hooks_install
      [[ ${preexec_functions[*]} == "foreign _ms_bash_preexec_dispatch" ]] || exit 2
      preexec_functions+=(later)
      _ms_bash_hooks_reset
      [[ ${preexec_functions[*]} == "foreign later" ]] || exit 3
      PROMPT_COMMAND=original
      _ms_bash_register_prompt callback
      _ms_bash_hooks_install
      PROMPT_COMMAND=replaced
      _ms_bash_hooks_reset
      [[ $PROMPT_COMMAND == replaced ]] || exit 4
      unset PROMPT_COMMAND
      declare -a PROMPT_COMMAND=()
      _ms_bash_register_prompt callback
      _ms_bash_hooks_install
      _ms_bash_hooks_reset
      [[ ${#PROMPT_COMMAND[@]} == 0 ]] || exit 5
    '
  }
  It 'uses supported preexec backends and preserves later user replacements'
    When run backend_case
    The status should be success
  End
End
