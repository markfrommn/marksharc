Describe 'tests/lint'
  lint_tree() {
    tree="$TEST_ROOT/tree"
    "$REAL_GIT" init -q "$tree"
    mkdir -p "$tree/core" "$tree/tests/spec"
    printf 'print ok\n' > "$tree/core/a.zsh"
    printf 'echo ok\n' > "$tree/b.sh"
    printf 'echo ok\n' > "$tree/c.bash"
    printf 'echo ok\n' > "$tree/d.fish"
    printf '#!/usr/bin/env zsh\nprint ok\n' > "$tree/tool"
    printf '#!/bin/sh -e\necho ok\n' > "$tree/script"
    printf '#!/usr/bin/env python3\n' > "$tree/helper"
    printf "Describe 'x'\nEnd\n" > "$tree/tests/spec/x_spec.sh"
    printf '# notes\n' > "$tree/README.md"
    "$REAL_GIT" -C "$tree" add -A
  }
  # Each checker stub logs its arguments and fails for any path containing "bad".
  stub_checkers() {
    for checker in zsh shellcheck fish; do
      stub_command "$checker" 'printf "%s\n" "'"$checker"' $*" >> "$OPLOG"; case "$*" in *bad*) exit 1;; esac'
    done
  }
  BeforeEach 'lint_tree' 'stub_checkers'

  It 'routes each shell file to its checker by extension or shebang'
    When run "$MARKSHARC_ROOT/tests/lint" "$tree"
    The status should be success
    The output should equal 'lint: ok (6 files)'
    The contents of file "$OPLOG" should equal "shellcheck -x -s sh b.sh
shellcheck -x -s bash c.bash
zsh -n core/a.zsh
fish --no-execute d.fish
shellcheck -x -s sh script
zsh -n tool"
  End
  It 'checks every file and fails when any checker fails'
    printf 'x\n' > "$tree/bad.zsh"
    printf 'x\n' > "$tree/bad.sh"
    When run "$MARKSHARC_ROOT/tests/lint" "$tree"
    The status should equal 1
    The output should equal ''
    The stderr should include 'lint: bad.sh: shellcheck failed'
    The stderr should include 'lint: bad.zsh: zsh -n failed'
  End
  It 'fails and names a checker that is not installed'
    rm "$TEST_ROOT/bin/shellcheck"
    mkdir "$TEST_ROOT/minbin"
    ln -s "$REAL_GIT" "$TEST_ROOT/minbin/git"
    ln -s "$(command -v mktemp)" "$TEST_ROOT/minbin/mktemp"
    ln -s "$(command -v rm)" "$TEST_ROOT/minbin/rm"
    When run command env PATH="$TEST_ROOT/bin:$TEST_ROOT/minbin" "$MARKSHARC_ROOT/tests/lint" "$tree"
    The status should equal 1
    The stderr should include 'lint: b.sh: shellcheck is required but not found'
  End
End
