Describe 'portable tree personal-value lint'
  lint_case() {
    emulate -L zsh
    local root="$TEST_ROOT/candidate" checker="$MARKSHARC_ROOT/tests/support/personal-values-check.py"
    mkdir -p "$root/core/lib" "$root/modules/neutral/functions/zsh" "$root/modules/neutral/tests"
    print 'host=generic' > "$root/core/lib/neutral.zsh"
    "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 || return 1
    print '/Users/Mark/private' > "$root/modules/neutral/functions/zsh/example"
    "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 2
    [[ $(<"$TEST_ROOT/out") == *'functions/zsh/example'* && $(<"$TEST_ROOT/out") != *'/Users/Mark/private'* ]] || return 3
    rm "$root/modules/neutral/functions/zsh/example"
    print 'CONVOYAI' > "$root/modules/neutral/tests/nested.sh"
    "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 4
    [[ $(<"$TEST_ROOT/out") == *'tests/nested.sh'* ]] || return 5
    rm "$root/modules/neutral/tests/nested.sh"
    touch "$root/modules/neutral/plesk-file"
    "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 6
    [[ $(<"$TEST_ROOT/out") == *'plesk-file'* ]] || return 7
    rm "$root/modules/neutral/plesk-file"
    ln -s "$TEST_ROOT/outside" "$root/core/lib/alias.zsh"
    "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 8
    [[ $(<"$TEST_ROOT/out") == *'alias.zsh'* ]] || return 9
    rm "$root/core/lib/alias.zsh"
    print SOL > "$root/core/lib/host.zsh"
    "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 10
    [[ $(<"$TEST_ROOT/out") == *'host.zsh'* ]] || return 11
    print 'Mark Gooderum' > "$root/core/lib/host.zsh"
    "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 12
    print mark > "$root/core/lib/host.zsh"
    "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 13
    local literal
    for literal in jumpweb.net powderhorns.biz bacweb bacuser; do
      print -r -- "dname=$literal" > "$root/core/lib/host.zsh"
      "$PYTHON" "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 14
      [[ $(<"$TEST_ROOT/out") == *'host.zsh'* ]] || return 15
    done
    return 0
  }
  It 'rejects personal paths, mixed-case values and filenames while allowing neutral words'
    When run lint_case
    The status should be success
  End
  real_case() { "$PYTHON" "$MARKSHARC_ROOT/tests/support/personal-values-check.py" "$MARKSHARC_ROOT"; }
  It 'accepts the complete portable zsh tree'
    When run real_case
    The status should be success
  End
End
