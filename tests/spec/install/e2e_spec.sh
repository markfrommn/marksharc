# The end-to-end install script on this checkout, and proof that tests/lint checks every file
# the installer unit adds (a missing shellcheck or zsh -n pass would not show up otherwise).
Describe 'install end to end'
  e2e_case() {
    # The sandbox PATH holds failing stubs for real services; the script wants the real tools.
    PATH="/usr/bin:/bin:/usr/sbin:/sbin:$(dirname "$REAL_GIT"):$(dirname "$PYTHON")" \
      "$MARKSHARC_ROOT/tests/e2e/install-e2e.sh" "$MARKSHARC_ROOT" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 1; }
    grep -q '^e2e: ok$' "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 2; }
    [ ! -s "$TEST_ROOT/err" ] || { cat "$TEST_ROOT/err"; return 3; }
  }
  It 'installs this checkout into a fresh HOME, starts login and interactive shells, and uninstalls'
    When run e2e_case
    The status should be success
  End

  usage_case() {
    "$MARKSHARC_ROOT/tests/e2e/install-e2e.sh" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [ $? -eq 2 ] || return 1
    "$MARKSHARC_ROOT/tests/e2e/install-e2e.sh" "$TEST_ROOT" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [ $? -eq 2 ] || return 2
    grep -q 'not a marksharc checkout' "$TEST_ROOT/err"
  }
  It 'rejects a missing or non-checkout argument'
    When run usage_case
    The status should be success
  End
End

Describe 'tests/lint coverage of the installer and CLI files'
  lint_case() {
    tree=$TEST_ROOT/tree
    "$REAL_GIT" init -q "$tree"
    for f in install.sh tests/e2e/install-e2e.sh bin/marksharc core/cli/module core/cli/uninstall core/cli/version core/cli/reload; do
      mkdir -p "$tree/$(dirname "$f")"
      cp "$MARKSHARC_ROOT/$f" "$tree/$f"
    done
    "$REAL_GIT" -C "$tree" add -A
    for checker in zsh shellcheck fish; do
      stub_command "$checker" 'printf "%s\n" "'"$checker"' $*" >> "$OPLOG"'
    done
    "$MARKSHARC_ROOT/tests/lint" "$tree" > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
    for want in 'shellcheck -x -s sh install.sh' 'shellcheck -x -s sh tests/e2e/install-e2e.sh' 'zsh -n bin/marksharc' \
      'zsh -n core/cli/module' 'zsh -n core/cli/uninstall' 'zsh -n core/cli/version' 'zsh -n core/cli/reload'; do
      grep -qx "$want" "$OPLOG" || { echo "not linted: $want"; cat "$OPLOG"; return 2; }
    done
  }
  It 'runs shellcheck on install.sh and the e2e script and zsh -n on bin/marksharc and core/cli'
    When run lint_case
    The status should be success
  End
End
