Describe 'safe worktree cleanup'
  executable_cancel_case() {
    emulate -L zsh
    git_fixture || return 1
    print n | bash -c '"$MARKSHARC_ROOT/modules/git-worktree/bin/gwt-clean"' > "$TEST_ROOT/output" 2>&1
    [[ $? != 0 && -d "$TEST_ROOT/worktree" && $(<"$TEST_ROOT/output") == *'Cleanup cancelled'* ]]
  }
  It 'keeps the worktree on cancellation when called from bash'
    When run executable_cancel_case
    The status should be success
  End
  late_failure_case() {
    emulate -L zsh
    git_fixture || return 1
    source "$MARKSHARC_ROOT/core/zsh/lib/directives.zsh"
    load_mfn git-worktree gwt-clean
    cat > "$TEST_ROOT/bin/git" <<'DATA'
#!/bin/sh
case "$1 $2" in 'branch -d') exit 9 ;; esac
exec "$REAL_GIT" "$@"
DATA
    cat > "$TEST_ROOT/bin/cwf" <<'DATA'
#!/bin/sh
printf '%s\n' 'no cwf environment'
DATA
    chmod +x "$TEST_ROOT/bin/git" "$TEST_ROOT/bin/cwf"
    path=( "$MARKSHARC_ROOT/modules/git-worktree/bin" $path )
    print y > "$TEST_ROOT/answer"
    gwt-clean < "$TEST_ROOT/answer" > "$TEST_ROOT/output" 2>&1
    local rc=$?
    [[ $rc != 0 && $PWD == "$TEST_ROOT/base" && ! -d "$TEST_ROOT/worktree" ]]
  }
  It 'moves the caller to the base if branch deletion fails after worktree removal'
    When run late_failure_case
    The status should be success
  End
  launch_marker_case() {
    emulate -L zsh
    git_fixture || return 1
    local mode=$1 marker=$TEST_ROOT/worktree
    case $mode in
      empty) marker='' ;;
      different) marker=$TEST_ROOT/base ;;
      alias) ln -s "$TEST_ROOT/worktree" "$TEST_ROOT/worktree-link"; marker=$TEST_ROOT/worktree-link ;;
    esac
    cat > "$TEST_ROOT/bin/cwf" <<'DATA'
#!/bin/sh
if [ "$FIXTURE_MODE" = status-fail ]; then exit 8; fi
printf '%s\n' 'no cwf environment'
DATA
    cat > "$TEST_ROOT/bin/git" <<'DATA'
#!/bin/sh
case "$FIXTURE_MODE:$1 $2" in branch-fail:'branch -d') exit 8 ;; esac
exec "$REAL_GIT" "$@"
DATA
    chmod +x "$TEST_ROOT/bin/cwf" "$TEST_ROOT/bin/git"
    : > "$TEST_ROOT/directives"
    print y | LAUNCH_WORKTREE="$marker" FIXTURE_MODE="$mode" MARKSHARC_DIRECTIVES="$TEST_ROOT/directives" \
      /bin/zsh -f "$MARKSHARC_ROOT/modules/git-worktree/bin/gwt-clean" > "$TEST_ROOT/output" 2>&1
    local rc=$? contents=$(<"$TEST_ROOT/directives")
    case $mode in
      match|alias) [[ $rc == 0 && $contents == $'cd\t'*$'\nexit\t0' ]] ;;
      empty|different) [[ $rc == 0 && $contents == $'cd\t'* && $contents != *exit* ]] ;;
      status-fail) [[ $rc != 0 && -d "$TEST_ROOT/worktree" && -z $contents ]] ;;
      branch-fail) [[ $rc != 0 && $contents == $'cd\t'* && $contents != *exit* ]] ;;
    esac
  }
  Parameters:value match alias empty different status-fail branch-fail
  It 'only exits for successful cleanup of the marked worktree: $1'
    When run launch_marker_case "$1"
    The status should be success
  End
  cleanup_case() {
    emulate -L zsh
    git_fixture "${2:-main}" || return
    load_mfn git-worktree gwt-clean
    cwf() {
      # env status keeps its no-env behavior; the destroy invocation must be
      # exactly the flags gwt-clean passes, so dropped flags fail the specs.
      case "$*" in
        'env status') [[ $mode != no-env ]] || print "no cwf environment";;
        'env destroy --data delete --yes') print destroy >> "$OPLOG"; [[ $mode != destroy-fail ]];;
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
    cat > "$TEST_ROOT/bin/git" <<'DATA'
#!/bin/sh
case "$FIXTURE_MODE:$*" in
  status-fail:status*) exit 7 ;;
  pull-fail:*' fetch --prune --prune-tags') exit 0 ;;
  pull-fail:*' pull --ff-only') exit 9 ;;
  update-fail:fetch*|update-fail:pull*) printf '%s\n' update >> "$OPLOG"; exit 9 ;;
esac
exec "$REAL_GIT" "$@"
DATA
    cat > "$TEST_ROOT/bin/cwf" <<'DATA'
#!/bin/sh
case "$*" in
  'env status') [ "$FIXTURE_MODE" != no-env ] || printf '%s\n' 'no cwf environment' ;;
  'env destroy --data delete --yes') printf '%s\n' destroy >> "$OPLOG"; [ "$FIXTURE_MODE" != destroy-fail ] ;;
  *) exit 1 ;;
esac
DATA
    cat > "$TEST_ROOT/bin/gh" <<'DATA'
#!/bin/sh
printf '%s\t%s\n' "$FIXTURE_PR_HEAD" "$FIXTURE_MERGE_COMMIT"
DATA
    cat > "$TEST_ROOT/bin/hook_ok" <<'DATA'
#!/bin/sh
printf 'hook:%s|%s|%s\n' "$1" "$2" "$3" >> "$OPLOG"
DATA
    cat > "$TEST_ROOT/bin/hook_fail" <<'DATA'
#!/bin/sh
printf '%s\n' hook-fail >> "$OPLOG"
exit 5
DATA
    chmod +x "$TEST_ROOT/bin/git" "$TEST_ROOT/bin/cwf" "$TEST_ROOT/bin/gh" "$TEST_ROOT/bin/hook_ok" "$TEST_ROOT/bin/hook_fail"
    [[ $mode != root-metadata ]] || rm "$TEST_ROOT/bin/cwf"
    print -r -- "$response" | FIXTURE_MODE="$mode" FIXTURE_PR_HEAD="$fixture_pr_head" FIXTURE_MERGE_COMMIT="$fixture_merge_commit" \
      MARKSHARC_GWT_CLEAN_HOOKS=${(F)gwt_clean_pre_remove_hooks} \
      "$MARKSHARC_ROOT/modules/git-worktree/bin/gwt-clean" > "$TEST_ROOT/output" 2>&1
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
