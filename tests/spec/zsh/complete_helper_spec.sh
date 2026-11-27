# Shared offline dynamic completion candidate helper (COMPLETION-SPEC section 4).
Describe 'core/cli/complete dynamic candidate helper'
  run_complete() {
    ms_env
    local -a extra=()
    while [[ ${1-} == [A-Za-z_]*=* ]]; do extra+=( "$1" ); shift; done
    env -i "${MS_ENV[@]}" HOST=testhost MARKSHARC_HOST=testhost "${extra[@]}" \
      "$MS_HOME/core/cli/complete" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
  }

  install_offline_traps() {
    local tool
    for tool in ssh hc herdr repo-list; do
      stub_command "$tool" 'printf "FORBIDDEN %s\n" "'"$tool"' $*" >> "$OPLOG"; exit 99'
    done
  }

  modules_and_hosts_case() {
    emulate -L zsh
    ms_fixture
    install_offline_traps
    ms_mod zeta module.conf 'describe "Zeta public"'
    ms_mod alpha module.conf 'describe "Alpha public"'
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/alpha" "$XDG_CONFIG_HOME/marksharc/modules/priv"
    print -r -- 'describe "Alpha overlay override"' > "$XDG_CONFIG_HOME/marksharc/modules/alpha/module.conf"
    print -r -- 'describe "Private tool"' > "$XDG_CONFIG_HOME/marksharc/modules/priv/module.conf"

    run_complete modules || { cat "$TEST_ROOT/err"; return 1; }
    local want_mods=$'alpha\tAlpha overlay override\npriv\tPrivate tool\nzeta\tZeta public'
    [[ $(<"$TEST_ROOT/out") == "$want_mods" ]] || { print -r -- "MODS=$(<$TEST_ROOT/out)"; return 2; }

    # Missing hosts.conf exits 0 with empty stdout
    run_complete hosts || return 3
    [[ ! -s $TEST_ROOT/out && ! -s $TEST_ROOT/err ]] || return 4

    cat > "$XDG_CONFIG_HOME/marksharc/hosts.conf" <<'EOF'
# comment
host sol sol.internal
host luna
host ipv6:box box.example
EOF
    run_complete hosts || return 5
    local want_hosts=$'sol\tsol.internal\nluna\nipv6:box\tbox.example'
    [[ $(<"$TEST_ROOT/out") == "$want_hosts" ]] || { print -r -- "HOSTS=$(<$TEST_ROOT/out)"; return 6; }

    # launch-hosts without --colon includes builtins + hosts.conf deduped
    run_complete launch-hosts || return 7
    local lh=$(<"$TEST_ROOT/out")
    [[ $lh == *'local'* && $lh == *'localhost'* && $lh == *'remote'* && $lh == *'testhost'* && $lh == *$'sol\tsol.internal'* && $lh == *'ipv6:box'* ]] || { print -r -- "LH=$lh"; return 8; }

    # launch-hosts --colon omits host names containing ':' and appends ':'
    run_complete launch-hosts --colon || return 9
    local lhc=$(<"$TEST_ROOT/out")
    [[ $lhc == *'local:'* && $lhc == *'testhost:'* && $lhc == *$'sol:\tsol.internal'* && $lhc == *'luna:'* && $lhc != *'ipv6:box'* ]] || { print -r -- "LHC=$lhc"; return 10; }
    [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 11; }
  }
  It 'lists sorted modules with overlay override, hosts, and launch-hosts with colon filtering'
    When run modules_and_hosts_case
    The status should be success
  End

  installers_and_updates_case() {
    emulate -L zsh
    ms_fixture
    install_offline_traps
    ms_mod toolA module.conf 'describe "Tool A"
requires command absent-tool-xyz
installer tool-a ./install-a
update step-a echo a'
    ms_mod toolB module.conf 'describe "Tool B"
installer tool-b ./install-b
update step-b echo b'
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    cat > "$XDG_CONFIG_HOME/marksharc/config.conf" <<'EOF'
installer overlay-inst ./install-o
update overlay-step echo o
EOF
    run_complete installers || { cat "$TEST_ROOT/err"; return 1; }
    local inst=$(<"$TEST_ROOT/out")
    # _day2_allow_missing=1 includes tool-a even though absent-tool-xyz is missing
    [[ $inst == $'tool-a\ntool-b\noverlay-inst' ]] || { print -r -- "INST=$inst"; return 2; }

    run_complete update-steps || { cat "$TEST_ROOT/err"; return 3; }
    local steps=$(<"$TEST_ROOT/out")
    [[ $steps == $'sync\npins\nsystem\nrender\nstep-b\noverlay-step' ]] || { print -r -- "STEPS=$steps"; return 4; }
    [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 5; }
  }
  It 'lists installers (allowing missing commands) and built-in plus registered update-steps'
    When run installers_and_updates_case
    The status should be success
  End

  repos_worktrees_and_targets_case() {
    emulate -L zsh
    ms_fixture
    install_offline_traps
    local repodir="$XDG_CACHE_HOME/marksharc/testhost/repos"
    mkdir -p "$repodir" "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'host sol sol.internal' > "$XDG_CONFIG_HOME/marksharc/hosts.conf"

    # Missing TSV exits 0 cleanly
    run_complete repos --host sol || return 1
    [[ ! -s $TEST_ROOT/out && ! -s $TEST_ROOT/err ]] || return 2

    # Populate local.tsv with spaces, apostrophes, colons, shell metachars
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "alpha" "/work/alpha" "base" "/work/alpha" "main" \
      "wt-1" "/work/alpha-wt/wt-1" "worktree" "/work/alpha" "feat/one" \
      "same" "/work/alpha-wt/same" "worktree" "/work/alpha" "same" \
      "it's repo" "/work/it's repo" "base" "/work/it's repo" "main" \
      "odd \$(touch $TEST_ROOT/pwned)" "/work/odd-wt" "worktree" "/work/it's repo" "br:1" \
      > "$repodir/local.tsv"

    printf '%s\t%s\t%s\t%s\t%s\n' \
      "remote-app" "/srv/remote-app" "base" "/srv/remote-app" "main" \
      "r-wt" "/srv/remote-app-wt/r-wt" "worktree" "/srv/remote-app" "dev" \
      > "$repodir/sol.tsv"

    # repos (local aliases: empty, local, localhost, testhost)
    local h
    for h in '' local localhost testhost; do
      if [[ -z $h ]]; then
        run_complete repos || return 3
      else
        run_complete repos --host "$h" || return 3
      fi
      local out=$(<"$TEST_ROOT/out")
      [[ $out == *"alpha"* && $out == *"alpha/wt-1"* && $out == *"alpha/feat/one"* && $out == *"alpha/same"* && $out == *"it's repo"* && $out == *"it's repo/odd \$(touch $TEST_ROOT/pwned)"* && $out == *"it's repo/br:1"* ]] || { print -r -- "REPOS($h)=$out"; return 4; }
    done
    [[ ! -e $TEST_ROOT/pwned ]] || return 5

    # repos --base-only and --prefix
    run_complete repos --base-only --prefix 'local:' || return 6
    [[ $(<"$TEST_ROOT/out") == $'local:alpha\nlocal:it'\''s repo' ]] || { cat "$TEST_ROOT/out"; return 7; }

    # base-repos --host sol
    run_complete base-repos --host sol || return 8
    [[ $(<"$TEST_ROOT/out") == 'remote-app' ]] || { cat "$TEST_ROOT/out"; return 9; }

    # worktrees filtered by --repo vs unfiltered
    run_complete worktrees --repo alpha || return 10
    [[ $(<"$TEST_ROOT/out") == $'wt-1\nfeat/one\nsame' ]] || { cat "$TEST_ROOT/out"; return 11; }
    run_complete worktrees || return 12
    [[ $(<"$TEST_ROOT/out") == *"odd \$(touch $TEST_ROOT/pwned)"* && $(<"$TEST_ROOT/out") == *"br:1"* ]] || { cat "$TEST_ROOT/out"; return 13; }

    # launch-repo-target with host: splitting and --base-only
    run_complete launch-repo-target --current 'sol:' || return 14
    [[ $(<"$TEST_ROOT/out") == $'sol:remote-app\nsol:remote-app/r-wt\nsol:remote-app/dev' ]] || { cat "$TEST_ROOT/out"; return 15; }
    run_complete launch-repo-target --current 'sol:' --base-only || return 16
    [[ $(<"$TEST_ROOT/out") == 'sol:remote-app' ]] || { cat "$TEST_ROOT/out"; return 17; }

    # launch-repo-target starting host prefix without ':' offers host: candidates
    run_complete launch-repo-target --current 'so' || return 18
    [[ $(<"$TEST_ROOT/out") == *$'sol:\tsol.internal'* ]] || { cat "$TEST_ROOT/out"; return 19; }

    # --from-carapace env vars and explicit override precedence
    run_complete C_FLAG_HOST=sol C_FLAG_BASE_ONLY=true repos --from-carapace || return 20
    [[ $(<"$TEST_ROOT/out") == 'remote-app' ]] || { cat "$TEST_ROOT/out"; return 21; }
    run_complete C_FLAG_HOST=sol C_FLAG_REPO=remote-app worktrees --from-carapace || return 22
    [[ $(<"$TEST_ROOT/out") == $'r-wt\ndev' ]] || { cat "$TEST_ROOT/out"; return 23; }
    run_complete C_VALUE='sol:' C_FLAG_BASE_ONLY=true launch-repo-target --from-carapace || return 24
    [[ $(<"$TEST_ROOT/out") == 'sol:remote-app' ]] || { cat "$TEST_ROOT/out"; return 25; }
    # Explicit --host overrides C_FLAG_HOST
    run_complete C_FLAG_HOST=sol base-repos --host local --from-carapace || return 26
    [[ $(<"$TEST_ROOT/out") == $'alpha\nit'\''s repo' ]] || { cat "$TEST_ROOT/out"; return 27; }

    [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 28; }
  }
  It 'reads cached TSV repos, worktrees, launch-repo-target, special characters, and Carapace env vars offline'
    When run repos_worktrees_and_targets_case
    The status should be success
  End

  path_traversal_and_errors_case() {
    emulate -L zsh
    ms_fixture
    install_offline_traps
    mkdir -p "$XDG_CACHE_HOME/marksharc/testhost/repos"
    printf 'secret\t/secret\tbase\t/secret\tmain\n' > "$XDG_CACHE_HOME/marksharc/testhost/secret.tsv"

    local bad
    for bad in '..' '.' '../secret' 'a/b' '-bad' 'bad host'; do
      run_complete repos --host "$bad" || return 1
      [[ ! -s $TEST_ROOT/out ]] || { print -r -- "LEAKED($bad)=$(<$TEST_ROOT/out)"; return 2; }
      run_complete base-repos --host "$bad" || return 3
      [[ ! -s $TEST_ROOT/out ]] || return 4
      run_complete worktrees --host "$bad" || return 5
      [[ ! -s $TEST_ROOT/out ]] || return 6
      run_complete launch-repo-target --current "${bad}:foo" || return 7
      [[ ! -s $TEST_ROOT/out ]] || return 8
    done

    run_complete unknown-kind
    [[ $? == 2 && -s $TEST_ROOT/err ]] || return 9
    run_complete repos --bogus
    [[ $? == 2 && -s $TEST_ROOT/err ]] || return 10
    [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 11; }
  }
  It 'rejects path-traversal host names safely and returns exit 2 for unknown kinds or options'
    When run path_traversal_and_errors_case
    The status should be success
  End

  git_branches_case() {
    emulate -L zsh
    ms_fixture
    install_offline_traps
    # Non-git dir exits 0 with empty stdout
    ( cd "$TEST_ROOT" && run_complete PATH="$PATH:${REAL_GIT:h}" git-branches ) || return 1
    [[ ! -s $TEST_ROOT/out ]] || return 2

    git_fixture main
    run_complete PATH="$PATH:${REAL_GIT:h}" git-branches || return 3
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'main'* && $out == *'feature'* ]] || { print -r -- "BRANCHES=$out"; return 4; }
    [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 5; }
  }
  It 'lists local git branches in a repository and exits cleanly outside git'
    When run git_branches_case
    The status should be success
  End
End
