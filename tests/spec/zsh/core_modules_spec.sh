Describe 'core module loader'
  mod_log() {
    local nl=$'\n'
    ms_mod "$1" module.conf "describe \"$1\"${2:+${nl}order $2}${3:+${nl}$3}"
    ms_mod "$1" env.zsh "print -r -- ${1}:env >> \"\$OPLOG\""
    ms_mod "$1" init.zsh "print -r -- ${1}:init >> \"\$OPLOG\""
  }
  os_now() { [[ $(uname -s) == Darwin ]] && print darwin || print linux; }
  order_case() {
    emulate -L zsh
    ms_fixture
    mod_log c; mod_log a; mod_log b 10; mod_log d 0; mod_log e 99
    ms_run -c ':' || return 1
    [[ $(<"$OPLOG") == $'d:env\nb:env\na:env\nc:env\ne:env' ]] || { cat "$OPLOG"; return 2; }
    [[ ! -s $TEST_ROOT/err && ! -s $TEST_ROOT/out ]] || return 3
    : > "$OPLOG"
    ms_pty -dic 'exit' || return 4
    [[ $(<"$OPLOG") == $'d:env\nb:env\na:env\nc:env\ne:env\nd:init\nb:init\na:init\nc:init\ne:init' ]] || { cat "$OPLOG"; return 5; }
  }
  It 'loads env.zsh in every shell and init.zsh interactively, ordered by order then name'
    When run order_case
    The status should be success
  End
  requires_case() {
    emulate -L zsh
    ms_fixture
    local here other
    here=$(os_now); [[ $here == darwin ]] && other=linux || other=darwin
    mod_log cmdmissing 50 'requires command sh definitely-not-installed-xyz'
    mod_log cmdpresent 50 'requires command sh ls'
    mod_log oshere 50 "requires os $here"
    mod_log osother 50 "requires os $other"
    mod_log osboth 50 "requires os darwin linux"
    ms_run MARKSHARC_VERBOSE=1 -c ':' || return 1
    [[ $(<"$OPLOG") == $'cmdpresent:env\nosboth:env\noshere:env' ]] || { cat "$OPLOG"; return 2; }
    [[ $(<"$TEST_ROOT/err") == *'module cmdmissing: skipped (requires command definitely-not-installed-xyz)'* && $(<"$TEST_ROOT/err") == *"module osother: skipped (requires os $other)"* ]] || { cat "$TEST_ROOT/err"; return 3; }
    : > "$OPLOG"
    ms_run -c ':' || return 4
    [[ ! -s $TEST_ROOT/err && ! -s $TEST_ROOT/out ]]
  }
  It 'silently skips modules whose requires are unmet and traces the reason when verbose'
    When run requires_case
    The status should be success
  End
  options_case() {
    emulate -L zsh
    ms_fixture
    ms_mod go-gvm module.conf 'describe "opts"'$'\n''option color blue "Pick a colour"'$'\n''option dir ~/dflt "A directory"'$'\n''option list "a b" "Quoted default"'
    ms_mod go-gvm env.zsh 'print -r -- "color=$_ms_opt_go_gvm_color dir=$_ms_opt_go_gvm_dir list=$_ms_opt_go_gvm_list undeclared=${_ms_opt_go_gvm_nope-unset}" >> "$OPLOG"'
    ms_run -c ':' || return 1
    [[ $(<"$OPLOG") == "color=blue dir=$HOME/dflt list=a b undeclared=unset" ]] || { cat "$OPLOG"; return 2; }
    : > "$OPLOG"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'DATA'
# comment line
set go-gvm.color red   # trailing comment
set go-gvm.dir ~/from-config
set go-gvm.list 'two words'
set go-gvm.nope ignored
set go-gvm.color red
DATA
    ms_run -c ':' || return 3
    [[ $(<"$OPLOG") == "color=red dir=$HOME/from-config list=two words undeclared=unset" ]] || { cat "$OPLOG"; return 4; }
    : > "$OPLOG"
    # MARKSHARC_CONFIG relocates the overlay; $NAME references expand, command substitution does not run.
    mkdir -p "$TEST_ROOT/overlay"
    cat > "$TEST_ROOT/overlay/config.conf" <<'DATA'
set go-gvm.color $HOME/c
set go-gvm.dir '$(touch $TEST_ROOT/pwned)'
set go-gvm.list "$(touch $TEST_ROOT/pwned2) ${HOME}x `touch $TEST_ROOT/pwned3`"
DATA
    ms_run MARKSHARC_CONFIG="$TEST_ROOT/overlay" -c ':' || return 5
    [[ ! -e $TEST_ROOT/pwned && ! -e $TEST_ROOT/pwned2 && ! -e $TEST_ROOT/pwned3 ]] || return 6
    local want="color=$HOME/c dir=\$(touch \$TEST_ROOT/pwned) list=\$(touch $TEST_ROOT/pwned2) ${HOME}x \`touch $TEST_ROOT/pwned3\` undeclared=unset"
    want=${want//'${HOME}x'/${HOME}x}
    [[ $(<"$OPLOG") == "$want" ]] || { cat "$OPLOG"; print -r -- "WANT=$want"; return 7; }
  }
  It 'reads declared options from module.conf and config.conf set lines without evaluating values'
    When run options_case
    The status should be success
  End
  select_case() {
    emulate -L zsh
    ms_fixture
    mod_log a; mod_log b; mod_log c
    mkdir -p "$TEST_ROOT/dirnoconf"; mkdir -p "$MS_HOME/modules/noconf"; print -r -- 'print -r -- noconf:env >> "$OPLOG"' > "$MS_HOME/modules/noconf/env.zsh"
    ms_run -c ':' || return 1
    [[ $(<"$OPLOG") == $'a:env\nb:env\nc:env' ]] || { cat "$OPLOG"; return 2; }
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    # Only set lines: every module present still loads.
    print -r -- 'set a.x 1' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    : > "$OPLOG"; ms_run -c ':' || return 3
    [[ $(<"$OPLOG") == $'a:env\nb:env\nc:env' ]] || return 4
    # Only off lines: everything but the disabled module loads.
    print -r -- 'module b off' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    : > "$OPLOG"; ms_run -c ':' || return 5
    [[ $(<"$OPLOG") == $'a:env\nc:env' ]] || return 6
    # An explicit list loads only what it enables; unknown names are ignored.
    printf 'module c\nmodule a\nmodule ghost\nmodule b off\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    : > "$OPLOG"; ms_run -c ':' || return 7
    [[ $(<"$OPLOG") == $'a:env\nc:env' && ! -s $TEST_ROOT/err ]] || { cat "$OPLOG"; return 8; }
  }
  It 'enables every module without config.conf and follows explicit module lines when present'
    When run select_case
    The status should be success
  End
  paths_case() {
    emulate -L zsh
    ms_fixture
    mod_log m
    ms_mod m functions/zsh/mfn 'print -r -- mfn-ran'
    ms_mod m completions/zsh/_mcmd '#compdef mcmd'
    ms_run -c 'whence -w mfn; print -r -- ${fpath[(r)*/m/completions/zsh]}' || return 1
    [[ $(<"$TEST_ROOT/out") == *"mfn: none"* && $(<"$TEST_ROOT/out") != *completions* ]] || { cat "$TEST_ROOT/out"; return 2; }
    ms_pty -dic 'print -r -- "R=$(mfn) F=${(M)fpath:#*/m/*} A=${functions_source[mfn]-} W=$(whence -w mfn)"; exit' || return 3
    [[ $(<"$TEST_ROOT/out") == *"R=mfn-ran"* && $(<"$TEST_ROOT/out") == *"/m/functions/zsh"* && $(<"$TEST_ROOT/out") == *"/m/completions/zsh"* ]] || { cat "$TEST_ROOT/out"; return 4; }
  }
  It 'adds module functions and completions to fpath with autoload in the init phase only'
    When run paths_case
    The status should be success
  End
  idem_case() {
    emulate -L zsh
    ms_fixture
    ms_mod m module.conf 'describe "m"'
    ms_mod m env.zsh 'path+=( /ms-dup-test )'
    ms_mod m functions/zsh/mfn 'print -r -- mfn-ran'
    ms_pty -dic 'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; source "$MARKSHARC_HOME/core/zsh/zshrc.zsh"; source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; source "$MARKSHARC_HOME/core/zsh/zshrc.zsh"; pp=( ${(M)path:#/ms-dup-test} ); ff=( ${(M)fpath:#*/m/functions/zsh} ); print -r -- "P=$#pp F=$#ff R=$(mfn)"; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == "P=1 F=1 R=mfn-ran" ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'is safe to source the env and init phases repeatedly'
    When run idem_case
    The status should be success
  End
  failing_case() {
    emulate -L zsh
    ms_fixture
    mod_log a 10; mod_log c
    ms_mod b module.conf 'order 20'
    ms_mod b env.zsh 'print -r -- b:env >> "$OPLOG"; return 7'
    ms_run -c ':' || return 1
    [[ $(<"$OPLOG") == $'a:env\nb:env\nc:env' && ! -s $TEST_ROOT/err && ! -s $TEST_ROOT/out ]] || { cat "$OPLOG" "$TEST_ROOT/err"; return 2; }
  }
  It 'keeps loading later modules when one module returns failure'
    When run failing_case
    The status should be success
  End
  verbose_case() {
    emulate -L zsh
    ms_fixture
    mod_log a
    ms_run MARKSHARC_VERBOSE=1 -c ':' || return 1
    [[ ! -s $TEST_ROOT/out ]] || return 2
    [[ $(<"$TEST_ROOT/err") == *"marksharc: module a: env.zsh"* && $(<"$TEST_ROOT/err") == *"marksharc: session=batch"* && $(<"$TEST_ROOT/err") == *" ms"* ]] || { cat "$TEST_ROOT/err"; return 3; }
    ! grep -v '^marksharc: ' "$TEST_ROOT/err" > /dev/null || return 4
    ms_run MARKSHARC_VERBOSE=0 -c ':' || return 5
    [[ ! -s $TEST_ROOT/err ]]
  }
  It 'prints the per-phase and per-module trace on stderr only when verbose'
    When run verbose_case
    The status should be success
  End
  fatal_batch_case() {
    emulate -L zsh
    ms_fixture
    mod_log c
    ms_mod a module.conf 'order 10'
    ms_mod a env.zsh 'print -r -- a:env >> "$OPLOG"; print ${x:?boom}; print -r -- a:after >> "$OPLOG"'
    ms_mod b module.conf 'order 20'
    ms_mod b env.zsh 'print -r -- b:env >> "$OPLOG"; print $(( 1 +'
    ms_run MARKSHARC_MODULE_GUARD=1 -c 'print survived' || return 1
    [[ $(<"$TEST_ROOT/out") == survived && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    # a ran once (the validation pass) and never for real. c ran after the broken
    # modules, twice on this first shell (validation pass, then for real).
    [[ $(grep -c '^a:env$' "$OPLOG") == 1 && $(grep -c '^c:env$' "$OPLOG") == 2 && $(<"$OPLOG") != *a:after* ]] || { cat "$OPLOG"; return 3; }
    # The verdict is cached by file stat: later shells skip a without running it.
    : > "$OPLOG"
    ms_run MARKSHARC_MODULE_GUARD=1 MARKSHARC_VERBOSE=1 -c 'print survived' || return 4
    [[ $(<"$TEST_ROOT/out") == survived && $(<"$OPLOG") == c:env && $(<"$TEST_ROOT/err") == *'module a: env.zsh skipped (failed validation)'* ]] || { cat "$OPLOG" "$TEST_ROOT/err"; return 5; }
    # Fixing the module re-validates it.
    : > "$OPLOG"
    ms_mod a env.zsh 'print -r -- a:fixed >> "$OPLOG"'
    ms_run MARKSHARC_MODULE_GUARD=1 -c ':' || return 6
    # Any edit changes the env id, so everything re-validates: each module runs twice.
    [[ $(<"$OPLOG") == $'a:fixed\na:fixed\nc:env\nc:env' ]] || { cat "$OPLOG"; return 7; }
  }
  It 'contains a fatal expansion error in a module for agent and batch shells'
    When run fatal_batch_case
    The status should be success
  End
  fatal_pty_case() {
    emulate -L zsh
    ms_fixture
    ms_mod a module.conf 'order 10'
    ms_mod a init.zsh 'print ${x:?boom}'
    mod_log c
    ms_pty -dic 'print -r -- "READY S=$MARKSHARC_SESSION"; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'READY S=interactive'* ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(<"$OPLOG") == $'c:env\nc:init' ]] || { cat "$OPLOG"; return 3; }
  }
  It 'keeps an interactive shell and later modules alive after a failing init.zsh'
    When run fatal_pty_case
    The status should be success
  End
  guard_dependency_case() {
    emulate -L zsh
    ms_fixture
    mod_log c
    ms_mod a module.conf 'order 10'
    ms_mod a lib.zsh 'print -r -- a:lib >> "$OPLOG"'
    ms_mod a env.zsh 'source "$MARKSHARC_HOME/modules/a/lib.zsh"'
    ms_run MARKSHARC_MODULE_GUARD=1 -c 'print -r -- $MARKSHARC_ENV' || return 1
    local id=$(<"$TEST_ROOT/out")
    [[ $(grep -c '^a:lib$' "$OPLOG") == 2 ]] || { cat "$OPLOG"; return 2; }
    # A dependency of the module breaks: the stamp must not vouch for it any more.
    ms_mod a lib.zsh 'print ${x:?boom}'
    : > "$OPLOG"
    ms_run MARKSHARC_MODULE_GUARD=1 MARKSHARC_ENV=$id -c 'print survived' || return 3
    [[ $(<"$TEST_ROOT/out") == survived && ! -s $TEST_ROOT/err && $(<"$OPLOG") == $'c:env\nc:env' ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err" "$OPLOG"; return 4; }
  }
  It 're-validates a module when a file it sources changes'
    When run guard_dependency_case
    The status should be success
  End
  guard_rebuild_case() {
    emulate -L zsh
    ms_fixture
    mod_log c
    ms_mod a module.conf 'order 10'
    ms_mod a env.zsh '[[ -e $TEST_ROOT/boom ]] && (( _ms_env_rebuild )) && print ${x:?boom}; print -r -- a:env >> "$OPLOG"'
    ms_run MARKSHARC_MODULE_GUARD=0 -c 'print -r -- $MARKSHARC_ENV' || return 1
    local id=$(<"$TEST_ROOT/out")
    # An inheriting shell takes the quiet path and stamps it ok.
    : > "$TEST_ROOT/boom"
    : > "$OPLOG"
    ms_run MARKSHARC_MODULE_GUARD=1 MARKSHARC_ENV=$id -c ':' || return 2
    [[ $(grep -c '^a:env$' "$OPLOG") == 2 ]] || { cat "$OPLOG"; return 3; }
    # A rebuilding shell takes another path in the same module: that stamp must not be reused.
    : > "$OPLOG"
    ms_run MARKSHARC_MODULE_GUARD=1 -c 'print survived' || return 4
    [[ $(<"$TEST_ROOT/out") == survived && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 5; }
    [[ $(grep -c '^a:env$' "$OPLOG") == 0 && $(grep -c '^c:env$' "$OPLOG") == 2 ]] || { cat "$OPLOG"; return 6; }
  }
  It 'does not reuse an inheriting shell verdict for a rebuilding shell'
    When run guard_rebuild_case
    The status should be success
  End
  guard_memo_case() {
    emulate -L zsh
    ms_fixture
    ms_mod a module.conf 'order 10'
    ms_mod a env.zsh 'print -r -- a:env >> "$OPLOG"'
    # A cache directory that cannot be created: verdicts ride in an exported variable.
    mkdir -p "$TEST_ROOT/ro"; : > "$TEST_ROOT/ro/cache"
    local -a base=( MARKSHARC_MODULE_GUARD=1 XDG_CACHE_HOME="$TEST_ROOT/ro/cache" )
    ms_run "${base[@]}" -c 'print -r -- "$MARKSHARC_ENV"; print -r -- "$MARKSHARC_GUARD_MEMO" >&2' || return 1
    local id=$(<"$TEST_ROOT/out") memo=$(<"$TEST_ROOT/err")
    [[ -n $memo ]] || return 2
    [[ $(grep -c '^a:env$' "$OPLOG") == 2 ]] || { cat "$OPLOG"; return 3; }
    # The inherited cache is still missing and unwritable, so recovery rebuilds with the
    # same guard key: the memo suppresses a second validation and only the real run remains.
    : > "$OPLOG"
    ms_run "${base[@]}" MARKSHARC_ENV=$id MARKSHARC_GUARD_MEMO="$memo" -c 'print -r -- "$MARKSHARC_GUARD_MEMO" >&2' || return 4
    memo=$(<"$TEST_ROOT/err")
    [[ $(grep -c '^a:env$' "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 5; }
    # A later recovery attempt is memoised too.
    : > "$OPLOG"
    ms_run "${base[@]}" MARKSHARC_ENV=$id MARKSHARC_GUARD_MEMO="$memo" -c ':' || return 6
    [[ $(<"$OPLOG") == a:env && ! -s $TEST_ROOT/err ]] || { cat "$OPLOG" "$TEST_ROOT/err"; return 7; }
  }
  It 'remembers guard verdicts in the environment when the cache is not writable'
    When run guard_memo_case
    The status should be success
  End
End
