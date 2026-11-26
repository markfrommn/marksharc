Describe 'advisory startup-time check'
  bench="$MARKSHARC_ROOT/tests/bench-startup"

  fallback_case() {
    json="$TEST_ROOT/bench.json"
    summary="$TEST_ROOT/summary.md"
    # Force fallback path with a nonexistent HYPERFINE_BIN so both environments test it.
    HYPERFINE_BIN="$TEST_ROOT/no-hyperfine" GITHUB_STEP_SUMMARY="$summary" \
      "$bench" --runs 1 --warmup 0 --batch-budget-ms 0 --interactive-budget-ms 0 --json "$json" "$MARKSHARC_ROOT" \
      > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 1; }
    grep -q 'using python3 timing fallback' "$TEST_ROOT/out" || return 2
    grep -q 'bench: zsh batch: median=' "$TEST_ROOT/out" || return 3
    grep -q 'bench: zsh interactive (PTY): median=' "$TEST_ROOT/out" || return 4
    grep -q 'status=advisory-over' "$TEST_ROOT/out" || return 5
    [ -s "$json" ] && grep -q '"zsh interactive (PTY)"' "$json" || return 6
    [ -s "$summary" ] && grep -q 'Advisory startup-time check' "$summary" || return 7
  }
  It 'measures batch and interactive PTY startup with fallback and stays advisory when over budget'
    Skip if 'Python is unavailable' test -z "$PYTHON"
    When run fallback_case
    The status should be success
  End

  hyperfine_stub_case() {
    stub_command hyperfine '
json=
while [ $# -gt 0 ]; do
  case $1 in
    --export-json) json=$2; shift 2 ;;
    *) shift ;;
  esac
done
printf "%s\n" "{\"results\":[{\"command\":\"zsh batch\",\"mean\":0.02,\"median\":0.02,\"min\":0.01,\"max\":0.03},{\"command\":\"zsh interactive (PTY)\",\"mean\":0.05,\"median\":0.05,\"min\":0.04,\"max\":0.06}]}" > "$json"
printf "hyperfine ran\n"
'
    HYPERFINE_BIN="$TEST_ROOT/bin/hyperfine" \
      "$bench" --runs 2 --warmup 1 --strict "$MARKSHARC_ROOT" \
      > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 1; }
    grep -q 'hyperfine ran' "$TEST_ROOT/out" || return 2
    grep -q 'bench: zsh batch: median=20.0ms' "$TEST_ROOT/out" || return 3
    grep -q 'status=ok' "$TEST_ROOT/out" || return 4
    # Strict mode fails when median exceeds budget.
    if HYPERFINE_BIN="$TEST_ROOT/bin/hyperfine" \
      "$bench" --runs 1 --warmup 0 --batch-budget-ms 10 --strict "$MARKSHARC_ROOT" \
      > "$TEST_ROOT/out2" 2> "$TEST_ROOT/err2"; then
      return 5
    fi
    return 0
  }
  It 'uses hyperfine when available and honours --strict over budget'
    Skip if 'Python is unavailable' test -z "$PYTHON"
    When run hyperfine_stub_case
    The status should be success
  End
End
