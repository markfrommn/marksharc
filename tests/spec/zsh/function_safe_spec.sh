# Module env.zsh/init.zsh files (and the core files, and the overlay hooks) are sourced at
# top level at startup and from the marksharc function on reload. A bare typeset there is
# global in the first case and function-local in the second, so file-scope declarations must
# say -g. tests/support/function-safe-check.py enforces it; the second half proves the
# reload from the function and the cs alias end in the same state.
Describe 'file-scope declarations are function-safe'
  checker="$MARKSHARC_ROOT/tests/support/function-safe-check.py"

  fixture_case() {
    emulate -L zsh
    local root=$TEST_ROOT/tree
    mkdir -p "$root/modules/a" "$root/templates/overlay/local"
    cat > "$root/modules/a/env.zsh" <<'EOF'
typeset -g ok1=1
typeset +x -g PS1
typeset -ga ok2=( one two )
typeset -gi ok3=3
integer -g ok4
typeset -p ok1 >/dev/null
typeset -f helper >/dev/null
f() { typeset in_fn; local x; integer n }
function g {
    typeset in_g
}
h()
{
    typeset in_h
}
() { typeset anon_local; }
() {
    local anon_multi
}
print "typeset not_a_command"
# typeset in_comment
cat <<TXT
typeset in_heredoc
TXT
x=( typeset local )
echo ${#path} typeset
typeset -g after_everything
EOF
    "$PYTHON" -I "$checker" "$root" > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
    cat > "$root/modules/a/init.zsh" <<'EOF'
typeset bare1
if true; then
    typeset bare2=1
    integer bare3
fi
{ local bare4 } always { :; }
float bare5
declare bare6
readonly bare7
f() { :; } && typeset bare8
EOF
    "$PYTHON" -I "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 2
    local n
    for n in 1 3 4 6 7 8 9 10; do
      grep -q "^modules/a/init.zsh:$n: " "$TEST_ROOT/out" || { echo "line $n not flagged"; cat "$TEST_ROOT/out"; return 3; }
    done
    [[ $(grep -c . "$TEST_ROOT/out") == 8 ]] || { cat "$TEST_ROOT/out"; return 4; }
    # the overlay hooks are checked as well
    rm "$root/modules/a/init.zsh"
    print -r -- 'typeset hook_var=1' > "$root/templates/overlay/local/post.zsh"
    "$PYTHON" -I "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 5
    grep -q '^templates/overlay/local/post.zsh:1: ' "$TEST_ROOT/out"
  }
  It 'flags file-scope declarations without -g and skips function bodies, strings, comments and queries'
    When run fixture_case
    The status should be success
  End

  ends_true_case() {
    emulate -L zsh
    local last
    last=$(grep -v -E '^[[:space:]]*(#|$)' "$MARKSHARC_ROOT/core/zsh/zshenv.zsh" | tail -n 1)
    [[ $last == true ]]
  }
  It 'ends the env phase with true so the stub can test its status'
    When run ends_true_case
    The status should be success
  End

  tree_case() {
    "$PYTHON" -I "$checker" "$MARKSHARC_ROOT" > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'holds for every module file, core file and overlay hook in the repository'
    When run tree_case
    The status should be success
  End
End

Describe 'reload from the marksharc function equals cs'
  # dump CODE NAME: a real-tree interactive shell runs CODE (a reload), then records the
  # module-owned globals under $TEST_ROOT/NAME.*
  dump() {
    emulate -L zsh
    ms_fixture_full
    mkdir -p "$MS_HOME/bin"
    ms_pty -dic "$1"'; typeset -p PS1 HISTSIZE SAVEHIST > $TEST_ROOT/dump.vars 2>&1; typeset +m "_ms_*" | grep -v "^_ms_mod_t0$" | sort > $TEST_ROOT/dump.names; typeset -p +m 2>/dev/null | grep -E "^typeset.* (_ms_[a-z0-9_]*)=" | grep -v -E "_ms_(env_id_value|mod_t0|now)" | sort > $TEST_ROOT/dump.values; exit' || return 1
    cp "$TEST_ROOT/dump.vars" "$TEST_ROOT/$2.vars"; cp "$TEST_ROOT/dump.names" "$TEST_ROOT/$2.names"; cp "$TEST_ROOT/dump.values" "$TEST_ROOT/$2.values"
  }
  equal_case() {
    emulate -L zsh
    dump 'cs >/dev/null 2>&1' cs || return 1
    dump 'marksharc reload' fn || return 2
    [[ -s $TEST_ROOT/fn.names && -s $TEST_ROOT/cs.names ]] || return 3
    diff "$TEST_ROOT/cs.names" "$TEST_ROOT/fn.names" || { echo "global names differ"; return 4; }
    diff "$TEST_ROOT/cs.vars" "$TEST_ROOT/fn.vars" || { echo "PS1 and history settings differ"; return 5; }
    diff "$TEST_ROOT/cs.values" "$TEST_ROOT/fn.values" || { echo "global values differ"; return 6; }
    # the module-scratch parameters survive the function reload
    grep -q '_ms_' "$TEST_ROOT/fn.names" || return 7
  }
  It 'leaves the same globals, PS1 and history settings as the cs alias'
    When run equal_case
    The status should be success
  End
End
