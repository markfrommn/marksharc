Describe 'repo-sync policy'
  setup_org() { _ms_opt_git_worktree_orgs='acme other-org'; load_mfn git-worktree; }
  repo_case() {
    emulate -L zsh
    git_fixture
    "$REAL_GIT" remote add origin git@github.com:acme/project.git
    setup_org
    git() { case "$1" in fetch) print -r -- "$*" >> "$OPLOG"; return 7;; *) "$REAL_GIT" "$@";; esac; }
    _ms_repo_sync_one "$PWD" > "$TEST_ROOT/output" 2>&1
    [[ $? == 7 && $(<"$OPLOG") == 'fetch --prune --prune-tags' ]]
  }
  repo_matrix_case() {
    emulate -L zsh
    local fixture_mode=$1
    git_fixture
    local original=$PWD expected=0 remote=git@github.com:acme/project.git
    case $fixture_mode in
      foreign) remote=git@github.com:foreign/project.git;;
      https) remote=https://github.com/acme/project.git;;
    esac
    [[ $fixture_mode == no-origin ]] || "$REAL_GIT" remote add origin "$remote"
    case $fixture_mode in
      feature) "$REAL_GIT" update-ref refs/remotes/origin/main HEAD;;
      master) "$REAL_GIT" update-ref refs/remotes/origin/master HEAD;;
      base|pull-fail) cd "$TEST_ROOT/base";;
      detached) "$REAL_GIT" checkout -q --detach;;
    esac
    local subject=$PWD
    cd "$HOME" || return 1
    setup_org
    git() {
      case $1 in
        fetch) print -r -- "$*" >> "$OPLOG"; return 0;;
        pull) print -r -- "$*" >> "$OPLOG"; [[ $fixture_mode != pull-fail ]];;
        *) "$REAL_GIT" "$@";;
      esac
    }
    _ms_repo_sync_one "$subject" > "$TEST_ROOT/out" 2>&1
    local rc=$?
    [[ $PWD == $HOME ]] || return 1
    case $fixture_mode in
      foreign|https|no-origin) [[ $rc == 0 && -z $(<"$OPLOG") ]];;
      detached|missing-base|pull-fail) [[ $rc != 0 && $(<"$OPLOG") == 'fetch --prune --prune-tags'* ]];;
      feature) [[ $rc == 0 && $(<"$OPLOG") == $'fetch --prune --prune-tags\nfetch origin refs/heads/main:refs/heads/main' ]];;
      master) [[ $rc == 0 && $(<"$OPLOG") == $'fetch --prune --prune-tags\nfetch origin refs/heads/master:refs/heads/master' ]];;
      base) [[ $rc == 0 && $(<"$OPLOG") == $'fetch --prune --prune-tags\npull --ff-only' ]];;
    esac
  }
  Describe 'repository policy'
    Parameters:value no-origin foreign https detached missing-base feature master base pull-fail
    It "preserves boundaries, refs and status for $1"
      When run repo_matrix_case "$1"
      The status should be success
    End
  End
  It 'propagates a repository fetch failure'
    When run repo_case
    The status should be success
  End
  roots_case() {
    emulate -L zsh
    local mode=$1 r1="$TEST_ROOT/r1" r2="$TEST_ROOT/r2"
    mkdir -p "$r1/a/.git" "$r1/b/.git" "$r1/notrepo" "$r2/c/.git"
    : > "$OPLOG"
    load_mfn git-worktree
    _ms_repo_sync_one() { print -r -- "visit:${1:t}" >> "$OPLOG"; [[ ${1:t} != b || $mode != one-fails ]]; }
    case $mode in
      two-roots|one-fails) _ms_opt_git_worktree_roots="$r1 $r2/";;
      none) _ms_opt_git_worktree_roots='';;
    esac
    repo-sync > "$TEST_ROOT/out" 2>&1
    local rc=$?
    case $mode in
      two-roots) [[ $rc == 0 && $(<"$OPLOG") == $'visit:a\nvisit:b\nvisit:c' ]] || { cat "$OPLOG"; return 1; };;
      one-fails) [[ $rc == 1 && $(<"$OPLOG") == $'visit:a\nvisit:b\nvisit:c' ]] || return 2;;
      none) [[ $rc == 1 && ! -s $OPLOG && $(<"$TEST_ROOT/out") == *'no roots configured'* ]] || return 3;;
    esac
  }
  Describe 'roots option'
    Parameters:value two-roots one-fails none
    It "visits every repository under the configured roots: $1"
      When run roots_case "$1"
      The status should be success
    End
  End
  orgs_case() {
    emulate -L zsh
    git_fixture
    "$REAL_GIT" remote add origin git@github.com:acme/project.git
    local subject=$PWD
    cd "$HOME" || return 1
    load_mfn git-worktree
    git() { case $1 in fetch|pull) print -r -- "$*" >> "$OPLOG"; return 0;; *) "$REAL_GIT" "$@";; esac; }
    _ms_opt_git_worktree_orgs=$1
    _ms_repo_sync_one "$subject" > "$TEST_ROOT/out" 2>&1
    local rc=$?
    # A synced repository fetches (this fixture has no origin/main, so it then reports and fails).
    if [[ $2 == synced ]]; then [[ -s $OPLOG ]]; else [[ $rc == 0 && ! -s $OPLOG ]]; fi
  }
  Describe 'orgs option'
    Parameters
      'acme' synced
      'other acme' synced
      'other' skipped
      '' skipped
    End
    It "orgs='$1' leaves the repository $2"
      When run orgs_case "$1" "$2"
      The status should be success
    End
  End
End
