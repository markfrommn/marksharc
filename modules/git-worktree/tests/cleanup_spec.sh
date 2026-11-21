Describe 'safe worktree cleanup'
  cleanup_case() {
    emulate -L zsh
    git_fixture "${2:-main}" || return
    load_mfn git-worktree gwt-clean
    cwf() {
      case "$1 $2" in
        "env status") [[ $mode != no-env ]] || print "no cwf environment";;
        "env destroy") print destroy >> "$OPLOG"; [[ $mode != destroy-fail ]];;
        *) return 1;;
      esac
    }
    local mode=$1
    local fixture_basebranch=${2:-main} fixture_pr_head fixture_merge_commit
    hook_ok() { print -r -- "hook:$1|$2|$3" >> "$OPLOG"; }
    hook_fail() { print -r -- "hook-fail" >> "$OPLOG"; return 5; }
    case $mode in
      hook-ok) gwt_clean_pre_remove_hooks=( hook_ok hook_ok );;
      hook-fail) gwt_clean_pre_remove_hooks=( hook_ok hook_fail );;
      hook-missing) gwt_clean_pre_remove_hooks=( no_such_hook );;
      hook-after-cancel|hook-after-dirty) gwt_clean_pre_remove_hooks=( hook_ok );;
    esac
    git() {
      [[ $mode != status-fail || $1 != status ]] || return 7
      case "$*" in
        'remote get-url origin') return 2;;
        'fetch --prune --prune-tags'|'pull --ff-only') print update >> "$OPLOG"; [[ $mode != update-fail ]];;
        *) "$REAL_GIT" "$@";;
      esac
    }
    case $mode in
      dirty|hook-after-dirty) print changed >> retained;;
      untracked) print lost > new-file;;
      unmerged|published) print new > feature-file; "$REAL_GIT" add feature-file; "$REAL_GIT" commit -qm feature;;
      squash-*)
        print first > feature-file
        "$REAL_GIT" add feature-file && "$REAL_GIT" commit -qm first || return 23
        print second >> feature-file
        "$REAL_GIT" commit -qam second || return 23
        fixture_pr_head=$("$REAL_GIT" rev-parse HEAD) || return 23
        if [[ $mode == squash-stack ]]; then
          "$REAL_GIT" -C "$TEST_ROOT/base" switch -qc parent || return 23
        fi
        "$REAL_GIT" -C "$TEST_ROOT/base" merge --squash feature >/dev/null || return 23
        "$REAL_GIT" -C "$TEST_ROOT/base" commit -qm squash || return 23
        fixture_merge_commit=$("$REAL_GIT" -C "$TEST_ROOT/base" rev-parse HEAD) || return 23
        if [[ $mode != squash-tree ]]; then
          "$REAL_GIT" -C "$TEST_ROOT/base" switch -q "$fixture_basebranch" || return 23
          print later >> "$TEST_ROOT/base/retained"
          "$REAL_GIT" -C "$TEST_ROOT/base" commit -qam later || return 23
          "$REAL_GIT" init --bare -q "$TEST_ROOT/remote" || return 23
          "$REAL_GIT" -C "$TEST_ROOT/base" remote add origin "$TEST_ROOT/remote" || return 23
          "$REAL_GIT" -C "$TEST_ROOT/base" push -qu origin "$fixture_basebranch" || return 23
          gh() {
            [[ $1 == pr && $2 == list && $3 == --repo && $4 == "$TEST_ROOT/remote" &&
               $5 == --head && $6 == feature && $7 == --state && $8 == merged ]] || return 24
            print -r -- "$fixture_pr_head"$'\t'"$fixture_merge_commit"
          }
        fi
        if [[ $mode == squash-stale-head ]]; then
          print unpublished >> feature-file
          "$REAL_GIT" commit -qam unpublished || return 23
        fi;;
      detached) "$REAL_GIT" checkout -q --detach;;
      locked) "$REAL_GIT" worktree lock --reason retained "$TEST_ROOT/worktree";;
      root-metadata)
        unfunction cwf
        rm "$TEST_ROOT/bin/cwf"
        print '.cwf/' >> "$TEST_ROOT/base/.git/info/exclude"
        mkdir .cwf src
        print retained > .cwf/state
        cd src;;
      base) cd "$TEST_ROOT/base";;
      dirty-base) print changed >> "$TEST_ROOT/base/retained";;
      occupied)
        "$REAL_GIT" -C "$TEST_ROOT/base" switch -qc parking
        "$REAL_GIT" -C "$TEST_ROOT/base" worktree add -q "$TEST_ROOT/holding" main;;
      ignored) mkdir node_modules; print ignored > node_modules/data; ln -s "$TEST_ROOT/outside" node_modules/outside; print safe > "$TEST_ROOT/outside";;
    esac
    if [[ $mode == published ]]; then
      "$REAL_GIT" init --bare -q "$TEST_ROOT/remote"
      "$REAL_GIT" remote add origin "$TEST_ROOT/remote"
      "$REAL_GIT" push -qu origin "${2:-main}" || return 21
      "$REAL_GIT" push -q origin feature || return 22
    fi
    if [[ $mode == pull-fail ]]; then
      "$REAL_GIT" remote add origin "$TEST_ROOT/not-used"
      git() { case "$*" in *' fetch --prune --prune-tags') return 0;; *' pull --ff-only') return 9;; *) "$REAL_GIT" "$@";; esac; }
    fi
    if [[ $mode == update-fail ]]; then
      "$REAL_GIT" -C "$TEST_ROOT/base" remote add origin "$TEST_ROOT/remote"
      git() { case "$*" in fetch*|pull*) print update >> "$OPLOG"; return 9;; *) "$REAL_GIT" "$@";; esac; }
    fi
    local response=y
    [[ $mode == (cancel|hook-after-cancel) ]] && response=n
    print -r -- "$response" | gwt-clean > "$TEST_ROOT/output" 2>&1
    local rc=$?
    case $mode in
      dirty|untracked|unmerged|published|squash-stale-head|squash-stack|detached|base|dirty-base|occupied|locked|root-metadata|status-fail|cancel|pull-fail|update-fail)
        [[ $rc != 0 && -d "$TEST_ROOT/worktree" ]] || { cat "$TEST_ROOT/output"; return 11; }
        [[ $(<"$OPLOG") != *destroy* ]] || { cat "$OPLOG"; return 12; };;
      no-env)
        [[ $rc == 0 && ! -d "$TEST_ROOT/worktree" && -z $(<"$OPLOG") ]] || return 23;;
      destroy-fail)
        [[ $rc != 0 && -d "$TEST_ROOT/worktree" && $(<"$OPLOG") == *destroy* ]] || return 13;;
      hook-ok)
        # Hooks run in order, with the worktree, base and branch, before the environment is destroyed.
        local expected="hook:$TEST_ROOT/worktree|$TEST_ROOT/base|feature"
        [[ $rc == 0 && ! -d "$TEST_ROOT/worktree" && $(<"$OPLOG") == "$expected"$'\n'"$expected"$'\ndestroy' ]] || { cat "$TEST_ROOT/output" "$OPLOG"; return 17; };;
      hook-fail)
        [[ $rc != 0 && -d "$TEST_ROOT/worktree" && $(<"$OPLOG") == *hook-fail* && $(<"$OPLOG") != *destroy* && $(<"$TEST_ROOT/output") == *'Pre-remove hook failed: hook_fail'* ]] || { cat "$TEST_ROOT/output" "$OPLOG"; return 18; };;
      hook-missing)
        [[ $rc != 0 && -d "$TEST_ROOT/worktree" && $(<"$TEST_ROOT/output") == *'Pre-remove hook not defined: no_such_hook'* && $(<"$OPLOG") != *destroy* ]] || { cat "$TEST_ROOT/output"; return 19; };;
      hook-after-cancel|hook-after-dirty)
        # Preflight and confirmation come first: no hook runs for a refused cleanup.
        [[ $rc != 0 && -d "$TEST_ROOT/worktree" && -z $(<"$OPLOG") ]] || { cat "$TEST_ROOT/output" "$OPLOG"; return 20; };;
      *)
        [[ $rc == 0 && ! -d "$TEST_ROOT/worktree" ]] || { cat "$TEST_ROOT/output"; return 14; }
        if "$REAL_GIT" -C "$TEST_ROOT/base" show-ref --verify --quiet refs/heads/feature; then return 14; fi
        [[ $(<"$OPLOG") == destroy ]] || return 15
        [[ $mode != ignored || $(<"$TEST_ROOT/outside") == safe ]] || return 16;;
    esac
  }
  Parameters
    dirty main
    status-fail main
    untracked main
    unmerged main
    published main
    squash-tree main
    squash-pr main
    squash-stale-head main
    squash-stack main
    detached main
    base main
    dirty-base main
    occupied main
    locked main
    root-metadata main
    cancel main
    update-fail main
    pull-fail main
    destroy-fail main
    no-env main
    ignored main
    merged master
    hook-ok main
    hook-fail main
    hook-missing main
    hook-after-cancel main
    hook-after-dirty main
  End
  It "preserves work and ordering: $1 on $2"
    When run cleanup_case "$1" "$2"
    The status should be success
  End
End
