Describe 'cwf-new creation checks, unmanaged copies and hook points'
  executable_usage_case() {
    emulate -L zsh
    cd "$HOME" || return 1
    bash -c '"$MARKSHARC_ROOT/modules/cwf/bin/cwf-new" fixture' > "$TEST_ROOT/output" 2>&1
    [[ $? != 0 && $(<"$TEST_ROOT/output") == *'Usage: cwf-new'* ]]
  }
  It 'checks its repository precondition when invoked from bash'
    When run executable_usage_case
    The status should be success
  End
  cwf_case() {
    emulate -L zsh
    local fixture_mode=$1
    git_fixture
    cd "$TEST_ROOT/base" || return
    mkdir .codex
    print config > '.codex/local file'
    print secret > .env.local
    print literal > '.env.*'
    print tracked > .env.foo
    "$REAL_GIT" add .env.foo
    "$REAL_GIT" commit -qm tracked-env
    local fixture_workdir="$TEST_ROOT/work tree-${TEST_ROOT:t}" before=$PWD repo=demo-frontend
    "$REAL_GIT" remote add origin "git@github.com:fixture/$repo.git"
    mkdir "$fixture_workdir"
    cwf() {
      if [[ $1 == session && $2 == new ]]; then
        print -r -- "  cd '$fixture_workdir'"
        [[ $fixture_mode == malformed ]] && print 'export COMMON_SESSION_ID=bad' || print '  export COMMON_SESSION_ID=12'
        [[ $fixture_mode != creation-fail ]]
      else return 0; fi
    }
    # Hooks see the copied files and run before the shell enters the session.
    hook_a() { print -r -- "hook_a:$1|$2|$3|$4|$([[ -f $2/.env.local ]] && print copied)|${PWD:t}" >> "$OPLOG"; }
    hook_b() { print -r -- "hook_b" >> "$OPLOG"; [[ $fixture_mode != hook-fail ]]; }
    case $fixture_mode in
      hook-ok|hook-fail) cwf_new_post_create_hooks=( hook_a hook_b );;
      hook-missing) cwf_new_post_create_hooks=( hook_a no_such_hook );;
      exclude) cwf_new_copy_exclude=( 'other-repo:*' 'demo-frontend:.env.l*' );;
    esac
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    load_mfn cwf cwf-new
    cat > "$TEST_ROOT/bin/cwf" <<'DATA'
#!/bin/sh
if [ "$1 $2" = 'session new' ]; then
  printf "  cd '%s'\n" "$FIXTURE_WORKDIR"
  if [ "$FIXTURE_MODE" = malformed ]; then printf '%s\n' 'export COMMON_SESSION_ID=bad'; else printf '%s\n' '  export COMMON_SESSION_ID=12'; fi
  [ "$FIXTURE_MODE" != creation-fail ]
fi
DATA
    cat > "$TEST_ROOT/bin/hook_a" <<'DATA'
#!/bin/sh
if [ -f "$2/.env.local" ]; then copied=copied; else copied=; fi
printf 'hook_a:%s|%s|%s|%s|%s|%s\n' "$1" "$2" "$3" "$4" "$copied" "${PWD##*/}" >> "$OPLOG"
DATA
    cat > "$TEST_ROOT/bin/hook_b" <<'DATA'
#!/bin/sh
printf '%s\n' hook_b >> "$OPLOG"
[ "$FIXTURE_MODE" != hook-fail ]
DATA
    chmod +x "$TEST_ROOT/bin/cwf" "$TEST_ROOT/bin/hook_a" "$TEST_ROOT/bin/hook_b"
    if [[ $fixture_mode == copy-fail ]]; then
      print -r -- $'#!/bin/sh\nexit 8' > "$TEST_ROOT/bin/cp"
      chmod +x "$TEST_ROOT/bin/cp"
    fi
    local framework=$MARKSHARC_ROOT
    if [[ $fixture_mode == no-git-worktree ]]; then
      framework=$TEST_ROOT/framework
      mkdir -p "$framework/core/zsh/lib"
      command cp "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh" "$framework/core/zsh/lib/directives.zsh"
    fi
    path=( "$MARKSHARC_ROOT/modules/cwf/bin" $path )
    export FIXTURE_MODE=$fixture_mode FIXTURE_WORKDIR=$fixture_workdir MARKSHARC_HOME=$framework
    cwf-new demo > "$TEST_ROOT/output" 2>&1
    local rc=$?
    case $fixture_mode in
      creation-fail|malformed)
        [[ $rc != 0 && $PWD == $before && ! -e "$fixture_workdir/.env.local" && -z $(<"$OPLOG") ]] || return 1;;
      copy-fail)
        [[ $rc != 0 && $PWD == $before && -z $(<"$OPLOG") ]] || return 2;;
      no-git-worktree)
        [[ $rc != 0 && $PWD == $before && $(<"$TEST_ROOT/output") == *'needs the git-worktree module'* && ! -e "$fixture_workdir/.env.local" ]] || return 3;;
      hook-fail|hook-missing)
        [[ $rc != 0 && $PWD == $before && $(<"$OPLOG") != *INDEX* && -f "$fixture_workdir/.env.local" ]] || { cat "$TEST_ROOT/output" "$OPLOG"; return 4; }
        if [[ $fixture_mode == hook-fail ]]; then
          [[ $(<"$OPLOG") == hook_a*$'\nhook_b' && $(<"$TEST_ROOT/output") == *'Post-create hook failed: hook_b'*"retained at $fixture_workdir"* ]] || { cat "$TEST_ROOT/output" "$OPLOG"; return 5; }
        else
          [[ $(<"$TEST_ROOT/output") == *'Post-create hook not defined: no_such_hook'* ]] || { cat "$TEST_ROOT/output"; return 6; }
        fi;;
      *)
        [[ ! -e "$fixture_workdir/.env.foo" && $(<"$fixture_workdir/.env.*") == literal && $(<"$fixture_workdir/.codex/local file") == config && $PWD == $fixture_workdir ]] || { cat "$TEST_ROOT/output"; return 7; }
        if [[ $fixture_mode == exclude ]]; then
          # The pattern keeps .env.local out; the other files (.env.*, .codex/...) still travel.
          [[ ! -e "$fixture_workdir/.env.local" ]] || return 12
        else
          [[ -f "$fixture_workdir/.env.local" && $(<"$fixture_workdir/.env.local") == secret ]] || return 13
        fi
        [[ $rc == 0 ]] || { cat "$TEST_ROOT/output"; return 9; }
        if [[ $fixture_mode == hook-ok ]]; then
          [[ $(<"$OPLOG") == "hook_a:$repo|$fixture_workdir|12|${fixture_workdir:t}|copied|base"$'\nhook_b' ]] || { cat "$OPLOG"; return 10; }
        else
          [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 11; }
        fi;;
    esac
  }
  Parameters:value success creation-fail malformed copy-fail hook-ok hook-fail hook-missing exclude no-git-worktree
  It "handles $1 with spaced output as data"
    When run cwf_case "$1"
    The status should be success
  End
End
Describe 'cwf cached zsh integration'
  integration_fixture() {
    ms_fixture
    ms_copy_module cwf
    mkdir -p "$HOME/tools" "$HOME/initial-tools"
    cat > "$TEST_ROOT/bin/cwf" <<'DATA'
#!/bin/sh
if [ "$1 $2" = 'shell zsh' ]; then
  printf 'GENERATED\n' >> "$OPLOG"
  printf 'export COMMON_DEV_TOOLS="%s"\n' "$HOME/tools"
  printf 'alias cwf-claude="cwf fixture"\n'
  printf 'typeset -ga cwf_marker=( loaded )\n'
  printf 'print -r -- SOURCED >> "$OPLOG"\n'
fi
DATA
    chmod +x "$TEST_ROOT/bin/cwf"
    : > "$OPLOG"
  }
  render_cwf() {
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb MARKSHARC_HOME="$MS_HOME" \
      COMMON_DEV_TOOLS="$HOME/initial-tools" HOST="$HOST" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT" \
      /bin/zsh -f "$MS_HOME/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
  }
  cwf_cache() { print -r -- "$XDG_CACHE_HOME/marksharc/${HOST%%.*}"; }

  render_case() {
    emulate -L zsh
    integration_fixture
    render_cwf || { cat "$TEST_ROOT/err"; return 1; }
    local cache=$(cwf_cache)
    [[ $(<"$OPLOG") == GENERATED && -r $cache/completions/zsh/_cwf ]] || { cat "$OPLOG"; return 2; }
    [[ $(<"$cache/completions/zsh/_cwf") == *'alias cwf-claude'* && $(<"$cache/completions/zsh/_cwf") != *compdef* ]] || return 3
  }
  It 'generates shell integration without evaluating it and without requiring compdef'
    When run render_case
    The status should be success
  End

  init_case() {
    emulate -L zsh
    integration_fixture
    render_cwf || { cat "$TEST_ROOT/err"; return 1; }
    ms_pty COMMON_DEV_TOOLS="$HOME/initial-tools" -dic '
      print -r -- "first=${aliases[cwf-claude]}|$COMMON_DEV_TOOLS|${(j:,:)cwf_marker}"
      source "$MARKSHARC_HOME/core/zsh/reload.zsh" || exit 11
      print -r -- "second=${aliases[cwf-claude]}|$COMMON_DEV_TOOLS|${(j:,:)cwf_marker}"
      exit' || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(<"$TEST_ROOT/out") == *"first=cwf fixture|$HOME/tools|loaded"* && $(<"$TEST_ROOT/out") == *"second=cwf fixture|$HOME/tools|loaded"* ]] || { cat "$TEST_ROOT/out"; return 3; }
    [[ $(grep -c '^GENERATED$' "$OPLOG") == 1 && $(grep -c '^SOURCED$' "$OPLOG") == 2 ]] || { cat "$OPLOG"; return 4; }
  }
  It 'sources the cached integration interactively and again on reload without regenerating'
    When run init_case
    The status should be success
  End

  optional_case() {
    emulate -L zsh
    integration_fixture
    ms_pty COMMON_DEV_TOOLS="$HOME/initial-tools" -dic 'print -r -- "missing=${+aliases[cwf-claude]}|${+cwf_marker}"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *'missing=0|0'* && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
    render_cwf || return 3
    ms_pty COMMON_DEV_TOOLS="$HOME/missing" -dic 'print -r -- "dangling=${+aliases[cwf-claude]}|${+cwf_marker}"; exit' || { cat "$TEST_ROOT/out"; return 4; }
    [[ $(<"$TEST_ROOT/out") == *'dangling=0|0'* && $(<"$OPLOG") == GENERATED ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 5; }
  }
  It 'stays quiet and optional when the cache or tooling checkout is absent'
    When run optional_case
    The status should be success
  End

  batch_agent_case() {
    emulate -L zsh
    integration_fixture
    render_cwf || { cat "$TEST_ROOT/err"; return 1; }
    : > "$OPLOG"
    ms_run COMMON_DEV_TOOLS="$HOME/initial-tools" -c 'print -r -- "${+aliases[cwf-claude]}|${+cwf_marker}|$COMMON_DEV_TOOLS"' || { cat "$TEST_ROOT/err"; return 2; }
    [[ $(<"$TEST_ROOT/out") == "0|0|$HOME/initial-tools" && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 3; }
    ms_run COMMON_DEV_TOOLS="$HOME/initial-tools" CLAUDECODE=1 -ic 'print -r -- "${+aliases[cwf-claude]}|${+cwf_marker}|$COMMON_DEV_TOOLS"' || { cat "$TEST_ROOT/err"; return 4; }
    [[ $(<"$TEST_ROOT/out") == "0|0|$HOME/initial-tools" && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 5; }
  }
  It 'does not generate or source the integration in batch or agent shells'
    When run batch_agent_case
    The status should be success
  End
End
