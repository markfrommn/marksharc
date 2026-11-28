Describe 'documentation checks'
  generator="$MARKSHARC_ROOT/tests/support/gen-module-reference"
  links="$MARKSHARC_ROOT/tests/support/check-doc-links.py"

  Describe 'generated module reference'
    It 'matches the modules present in the repository'
      When run zsh -f "$generator" --check
      The status should be success
    End

    fixture_tree() {
      tree="$TEST_ROOT/ref"
      mkdir -p "$tree/modules/alpha/bin" "$tree/modules/alpha/functions/zsh" "$tree/modules/beta" "$tree/docs"
      cat > "$tree/modules/alpha/module.conf" <<'EOF'
describe "Alpha <tool> wrapper | with a pipe"
order 30
requires command alpha
option home "" "Directory of *.conf files"
option mode fast "How alpha runs"
path user ~/.alpha/bin when dir ~/.alpha/bin
env ALPHA_HOME "$HOME/.alpha"
package brew alpha
installer alpha installers/alpha
update alpha alpha self-update
EOF
      : > "$tree/modules/alpha/bin/alpha-run"
      : > "$tree/modules/alpha/functions/zsh/alpha-go"
      : > "$tree/modules/alpha/functions/zsh/_alpha_private"
      : > "$tree/modules/alpha/init.zsh"
      printf '%s\n' 'plugin alpha-plugin https://example.invalid/alpha.git 0123456789abcdef0123456789abcdef01234567 shell zsh kind source' \
        > "$tree/modules/alpha/zsh.plugins"
      printf '%s\n' 'describe "Beta, declarative only"' > "$tree/modules/beta/module.conf"
    }

    generate() { zsh -f "$generator" --root "$tree" "$@"; }

    content_case() {
      fixture_tree
      generate || return 1
      doc="$tree/docs/MODULES.md"
      grep -q 'lists the 2 public modules' "$doc" || return 2
      # Table cells escape the characters Markdown would interpret.
      grep -q '| \[`alpha`\](#alpha) | 30 | zsh | command `alpha` | Alpha \\<tool> wrapper \\| with a pipe |' "$doc" || return 3
      grep -q '| \[`beta`\](#beta) | 50 | — | — | Beta, declarative only |' "$doc" || return 4
      grep -q '| `alpha.home` | \*(empty)\* | Directory of \\\*.conf files |' "$doc" || return 5
      grep -q '| `alpha.mode` | `fast` | How alpha runs |' "$doc" || return 6
      grep -q '^- \*\*Executables:\*\* `alpha-run`$' "$doc" || return 7
      grep -q '^- \*\*Shell functions:\*\* `alpha-go` (zsh)$' "$doc" || return 8
      ! grep -q '_alpha_private' "$doc" || return 9
      grep -q '^- \*\*Pinned plugins:\*\* `alpha-plugin` at `0123456789ab` (zsh)$' "$doc" || return 10
      grep -q '^- \*\*Packages:\*\* brew `alpha`$' "$doc" || return 11
      grep -q '^- \*\*Installers:\*\* `alpha`$' "$doc" || return 12
      grep -q '^- \*\*Update steps:\*\* `alpha` (`alpha self-update`)$' "$doc" || return 13
      grep -q '^- \*\*Native code:\*\* none (declarative only)$' "$doc" || return 14
      # References are printed as written, never expanded for the host or user.
      grep -q '^env ALPHA_HOME "\$HOME/.alpha"$' "$doc" || return 15
      grep -q '^path user ~/.alpha/bin when dir ~/.alpha/bin$' "$doc" || return 16
      ! grep -q -F "$HOME" "$doc" || return 17
    }
    It 'renders metadata, options, commands and declared lines without expanding references'
      When call content_case
      The status should be success
    End

    stale_case() {
      fixture_tree
      generate || return 1
      generate --check || return 2
      mkdir -p "$tree/modules/gamma"
      printf '%s\n' 'describe "Gamma"' > "$tree/modules/gamma/module.conf"
      generate --check
    }
    It 'fails the check when a module is added without regenerating'
      When call stale_case
      The status should equal 1
      The error should include 'is out of date'
    End

    missing_case() {
      fixture_tree
      generate --check
    }
    It 'fails the check when the reference is missing'
      When call missing_case
      The status should equal 1
      The error should include 'is missing'
    End

    stdout_case() {
      fixture_tree
      generate --stdout > "$TEST_ROOT/stdout.md" || return 1
      [ ! -e "$tree/docs/MODULES.md" ] || return 2
      generate || return 3
      cmp -s "$TEST_ROOT/stdout.md" "$tree/docs/MODULES.md"
    }
    It 'prints the same document with --stdout and writes nothing'
      When call stdout_case
      The status should be success
    End
  End

  Describe 'relative links'
    It 'resolve in README.md, docs/, specs/ and the other tracked guides'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      When run "$PYTHON" "$links"
      The status should be success
      The output should include 'links: ok'
    End

    link_tree() {
      tree="$TEST_ROOT/links"
      mkdir -p "$tree/docs"
      cat > "$tree/docs/guide.md" <<'EOF'
# Guide

## Choosing `modules`, quickly?

## Repeat

## Repeat

```text
[not a link](missing-in-code-block.md)
```
EOF
    }
    check_links() { "$PYTHON" "$links" --root "$tree"; }

    good_case() {
      link_tree
      cat > "$tree/README.md" <<'EOF'
[guide](docs/guide.md) [section](docs/guide.md#choosing-modules-quickly)
[second repeat](docs/guide.md#repeat-1) [external](https://example.invalid/nowhere)
[self](#top-heading) `[code](nowhere.md)`

# Top heading
EOF
      check_links
    }
    It 'accepts existing files, heading anchors, repeated headings and external links'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      When call good_case
      The status should be success
      The output should include 'links: ok (4 relative links in 2 files)'
    End

    bad_case() {
      link_tree
      cat > "$tree/README.md" <<'EOF'
[gone](docs/gone.md)
[no such section](docs/guide.md#no-such-section)
[outside](../outside.md)
EOF
      check_links
    }
    It 'reports a missing file, a missing anchor and a link that leaves the repository'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      When call bad_case
      The status should equal 1
      The error should include 'README.md:1: missing file: docs/gone.md'
      The error should include 'README.md:2: missing anchor: docs/guide.md#no-such-section'
      The error should include 'README.md:3: link leaves the repository: ../outside.md'
      The error should include 'links: 3 broken link(s)'
    End
  End
End
