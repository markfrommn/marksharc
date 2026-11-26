Describe 'contract inventory check'
  checker="$MARKSHARC_ROOT/tests/support/check-inventory.py"

  It 'verifies the repository contract inventory has all files, modules and >= 90% coverage'
    Skip if 'Python is unavailable' test -z "$PYTHON"
    When run "$PYTHON" "$checker"
    The status should be success
    The output should include 'inventory: ok'
  End

  fixture_tree() {
    tree="$TEST_ROOT/inv"
    mkdir -p "$tree/modules/alpha" "$tree/modules/beta" "$tree/tests/spec"
    : > "$tree/tests/spec/alpha_spec.sh"
    : > "$tree/tests/spec/beta_spec.sh"
  }

  run_checker() {
    "$PYTHON" "$checker" \
      --readme "$tree/tests/README.md" \
      --modules-dir "$tree/modules" \
      --tests-dir "$tree/tests" \
      --repo-root "$tree"
  }

  Describe 'validation rules'
    BeforeEach 'fixture_tree'

    It 'accepts an inventory with >= 90% coverage and an explicit uncovered row'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      cat > "$tree/tests/README.md" <<'EOF'
# Tests

## Contract inventory

| Area | Behaviour | Spec |
| --- | --- | --- |
| alpha | b1 | `spec/alpha_spec.sh` |
| alpha | b2 | `spec/alpha_spec.sh` |
| alpha | b3 | `spec/alpha_spec.sh` |
| alpha | b4 | `spec/alpha_spec.sh` |
| alpha | b5 | `spec/alpha_spec.sh` |
| beta | b6 | `spec/beta_spec.sh` |
| beta | b7 | `spec/beta_spec.sh` |
| beta | b8 | `spec/beta_spec.sh` |
| beta | b9 | `spec/beta_spec.sh` |
| beta | b10 | — |
EOF
      When run run_checker
      The status should be success
      The output should include '9/10 behaviours covered, 90.0%'
    End

    It 'fails when a listed spec file is missing'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      cat > "$tree/tests/README.md" <<'EOF'
## Contract inventory

| Area | Behaviour | Spec |
| --- | --- | --- |
| alpha | b1 | `spec/missing_spec.sh` |
| beta | b2 | `spec/beta_spec.sh` |
EOF
      When run run_checker
      The status should equal 1
      The stderr should include 'missing spec file: spec/missing_spec.sh'
    End

    It 'fails on directory paths or wildcard placeholders'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      cat > "$tree/tests/README.md" <<'EOF'
## Contract inventory

| Area | Behaviour | Spec |
| --- | --- | --- |
| alpha | b1 | `spec/` |
| beta | b2 | `modules/<name>/tests/<name>_test.fish` |
EOF
      When run run_checker
      The status should equal 1
      The stderr should include 'path is a directory'
      The stderr should include 'wildcard/placeholder not allowed'
    End

    It 'fails when a public module is absent from the inventory'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      cat > "$tree/tests/README.md" <<'EOF'
## Contract inventory

| Area | Behaviour | Spec |
| --- | --- | --- |
| alpha | b1 | `spec/alpha_spec.sh` |
EOF
      When run run_checker
      The status should equal 1
      The stderr should include 'module not listed in contract inventory: beta'
    End

    It 'fails when coverage drops below 90%'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      cat > "$tree/tests/README.md" <<'EOF'
## Contract inventory

| Area | Behaviour | Spec |
| --- | --- | --- |
| alpha | b1 | `spec/alpha_spec.sh` |
| beta | b2 | — |
EOF
      When run run_checker
      The status should equal 1
      The stderr should include 'coverage 50.0% (1/2) is below required 90.0%'
    End

    It 'fails on unquoted trailing tokens in the Spec column'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      cat > "$tree/tests/README.md" <<'EOF'
## Contract inventory

| Area | Behaviour | Spec |
| --- | --- | --- |
| alpha | b1 | `spec/alpha_spec.sh`, spec/missing_spec.sh |
| beta | b2 | `spec/beta_spec.sh` |
EOF
      When run run_checker
      The status should equal 1
      The stderr should include 'unquoted text in spec column'
    End

    It 'fails when --modules-dir does not exist'
      Skip if 'Python is unavailable' test -z "$PYTHON"
      cat > "$tree/tests/README.md" <<'EOF'
## Contract inventory

| Area | Behaviour | Spec |
| --- | --- | --- |
| alpha | b1 | `spec/alpha_spec.sh` |
EOF
      When run "$PYTHON" "$checker" --readme "$tree/tests/README.md" --modules-dir "$tree/no-such-dir" --tests-dir "$tree/tests" --repo-root "$tree"
      The status should equal 1
      The stderr should include 'modules directory not found'
    End
  End
End
