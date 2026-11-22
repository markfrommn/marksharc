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
    # Clean file: every construct here must pass.
    cat > "$root/modules/a/env.zsh" <<'EOF'
typeset -g ok1=1
typeset +x -g PS1
typeset -ga ok2=( one two )
typeset -gi ok3=3
integer -g ok4
builtin typeset -g ok5
command typeset -g ok6
typeset -p ok1 >/dev/null
typeset -f helper >/dev/null
command -v typeset >/dev/null
f() { typeset in_fn; local x; integer n }
function g {
    typeset in_g
}
function h2() { local in_h2 }
function h3 () {
    local in_h3
}
function { local in_function_anon }
function {
    typeset in_function_anon_multi
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
read -r hs <<< "typeset in_here_string"
x=( typeset local )
echo §{#path} typeset
case $hs in
    a) typeset -g arm_ok1 ;;
    (b|c) typeset -g arm_ok2 ;;
esac
case $hs in a) typeset -g arm_ok3 ;; b) typeset -g arm_ok4 ;; esac
typeset -g after_everything
EOF
    "$PYTHON" -I "$checker" "$root" > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
    # Findings: every line marked BARE, and only those.
    cat > "$root/modules/a/init.zsh" <<'EOF'
typeset bare1                                  # BARE
if true; then
    typeset bare2=1                            # BARE
    integer bare3                              # BARE
fi
{ local bare4 } always { :; }                  # BARE
float bare5                                    # BARE
declare bare6                                  # BARE
readonly bare7                                 # BARE
f() { :; } && typeset bare8                    # BARE
read -r hs <<< "text"
typeset bare_after_here_string                 # BARE
builtin typeset bare_builtin                   # BARE
command typeset bare_command                   # BARE
noglob typeset bare_noglob                     # BARE
case $hs in a) typeset bare_arm1 ;; b) typeset -g ok_arm ;; esac   # BARE
case $hs in
    a) typeset bare_arm2 ;;                    # BARE
    (b|c)
        typeset bare_arm3 ;;                   # BARE
esac
function { :; }; typeset bare_after_function   # BARE
EOF
    "$PYTHON" -I "$checker" "$root" > "$TEST_ROOT/out" 2>&1 && return 2
    local want got
    want=$(grep -n '# BARE' "$root/modules/a/init.zsh" | cut -d: -f1 | tr '\n' ' ')
    got=$(sed -n 's/^modules\/a\/init.zsh:\([0-9]*\): .*/\1/p' "$TEST_ROOT/out" | tr '\n' ' ')
    [[ $got == $want ]] || { print -r -- "want: $want"; print -r -- "got:  $got"; return 3; }
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

  # Module scratch variables and PS1 are set to markers before the reload. A module that
  # declared them without -g would shadow them with function-locals during a reload from the
  # function, leaving the markers in place; a correct module rewrites or unsets them.
  poison() {
    emulate -L zsh
    ms_fixture_full
    mkdir -p "$MS_HOME/bin"
    ms_pty -dic 'export PS1=POISON; _ms_hosts=(POISON); _ms_hline=POISON; _ms_hwords=(POISON); _dirhistory_keymap=POISON; _dirhistory_sequence=POISON; _ms_gp=POISON; _ms_pd=POISON; '"$1"'; for v in PS1 _ms_hosts _ms_hline _ms_hwords _dirhistory_keymap _dirhistory_sequence _ms_gp _ms_pd; do print -r -- "STATE $(typeset -p $v 2>&1)"; done; exit' || return 1
  }
  poison_case() {
    emulate -L zsh
    local mode
    for mode in 'marksharc reload' 'cs >/dev/null 2>&1' 'marksharc reload --verbose >/dev/null 2>&1'; do
      poison "$mode" || return 1
      [[ $(grep -c '^STATE ' "$TEST_ROOT/out") == 8 ]] || { print -r -- "$mode: no state dump"; cat "$TEST_ROOT/out"; return 2; }
      # no scratch variable still holds a marker (PS1 keeps its value, but must be unexported)
      if grep '^STATE ' "$TEST_ROOT/out" | grep -v 'PS1' | grep -q POISON; then print -r -- "$mode: marker left behind"; grep '^STATE ' "$TEST_ROOT/out"; return 3; fi
      if grep '^STATE .*PS1' "$TEST_ROOT/out" | grep -q 'export'; then print -r -- "$mode: PS1 still exported"; return 4; fi
    done
  }
  It 'leaves no marker in the module scratch variables and unexports PS1 after any reload'
    When run poison_case
    The status should be success
  End
End
