# Native Zsh PTY completion specs for rendered launch-session, launch-repo, and cwf-new
# (COMPLETION-SPEC sections 5.2, 7.2-7.4, 8).
Describe 'launch-session completion'
  completion_case() {
    emulate -L zsh
    mkdir -p "$HOME/config" "$HOME/work-files"
    : > "$HOME/work-files/readme.txt"
    printf 'module launch\n' > "$HOME/config/config.conf"
    printf 'host\talpha\tops@alpha\nhost with:colon\n' > "$HOME/config/hosts.conf"
    HOST=test MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" MARKSHARC_HOST=test \
      XDG_CACHE_HOME="$HOME/.cache" "$MARKSHARC_ROOT/bin/marksharc" render >/dev/null || return 1
    mkdir -m 777 "$HOME/insecure-completions"
    cat > "$HOME/.zshrc" <<'DATA'
fpath=( "$XDG_CACHE_HOME/marksharc/test/completions/zsh" "$HOME/insecure-completions" $fpath )
autoload -Uz compinit
# Match MarkSharc startup by skipping insecure completion directories without prompting.
compinit -i -D
launch-session() { printf '%s\n' "$*" >> "$OPLOG"; }
DATA
    local typed=$'cd "$HOME/work-files"\nlaunch-session --host al\t\nlaunch-session --host with\t\nlaunch-session al\t\nlaunch-session --mux tm\t\nlaunch-session --place hi\t\nlaunch-session --in-sh\t\nlaunch-session --pwd / al\t\nlaunch-session --host alpha --command echo -- readm\t\nexit\n'
    PTY_INPUT=$typed ms_pty MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" \
      MARKSHARC_HOST=test XDG_CACHE_HOME="$HOME/.cache" -di || { cat "$TEST_ROOT/out"; return 1; }
    local expected=$'--host alpha\n--host with:colon\nalpha:\n--mux tmux\n--place hidden\n--in-shell\n--pwd / al\n--host alpha --command echo -- readme.txt'
    [[ $(<"$OPLOG") == "$expected" ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
  }
  It 'completes launch hosts, mux kinds, placements, options, flag-form lock, and --command dash fallback'
    When run completion_case
    The status should be success
  End
End

Describe 'launch-repo completion'
  launch_repo_completion_case() {
    emulate -L zsh
    mkdir -p "$HOME/config" "$HOME/.cache/marksharc/test/repos"
    printf 'module launch\n' > "$HOME/config/config.conf"
    printf 'host\tbuilder\tops@builder\nhost\tsol\tops@sol\n' > "$HOME/config/hosts.conf"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      'alpha' '/tmp/alpha' 'base' '/tmp/alpha' 'main' \
      'wt1' '/tmp/alpha-wt/wt1' 'worktree' '/tmp/alpha' 'feat-one' > "$HOME/.cache/marksharc/test/repos/local.tsv"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "api team's" "/repos/api team's" 'base' "/repos/api team's" 'main' \
      "review copy's" "/worktrees/review copy's" 'worktree' "/repos/api team's" 'review/changes' \
      'other-wt' '/worktrees/other-wt' 'worktree' '/repos/unrelated' 'other/branch' > "$HOME/.cache/marksharc/test/repos/builder.tsv"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      'remote-app' '/srv/remote-app' 'base' '/srv/remote-app' 'main' > "$HOME/.cache/marksharc/test/repos/sol.tsv"
    HOST=test MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" MARKSHARC_HOST=test \
      XDG_CACHE_HOME="$HOME/.cache" "$MARKSHARC_ROOT/bin/marksharc" render >/dev/null || return 1
    cat > "$HOME/.zshrc" <<'DATA'
fpath=( "$XDG_CACHE_HOME/marksharc/test/completions/zsh" $fpath )
autoload -Uz compinit
compinit -i -D
launch-repo() { printf '%s\n' "$*" >> "$OPLOG"; }
DATA
    local typed=$'launch-repo --host bu\t\nlaunch-repo --base-on\t\nlaunch-repo --base-only al\t\nlaunch-repo sol:rem\t\nlaunch-repo --host builder --repo "api team\'s" --worktree review/\t\nlaunch-repo --host builder --repo "api team\'s" --worktree oth\t\nlaunch-repo --host sol rem\t\nexit\n'
    PTY_INPUT=$typed ms_pty MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" \
      MARKSHARC_HOST=test XDG_CACHE_HOME="$HOME/.cache" -di || { cat "$TEST_ROOT/out"; return 1; }
    local expected=$'--host builder\n--base-only\n--base-only alpha\nsol:remote-app\n--host builder --repo api team\'s --worktree review/changes\n--host builder --repo api team\'s --worktree oth\n--host sol rem'
    [[ $(<"$OPLOG") == "$expected" ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
  }
  It 'completes --host, --base-only, positional host:target, repo-scoped --worktree branches, and locks positional in flag form'
    When run launch_repo_completion_case
    The status should be success
  End
End

Describe 'cwf-new completion'
  cwf_completion_case() {
    emulate -L zsh
    mkdir -p "$HOME/config" "$HOME/.cache/marksharc/test/repos" "$HOME/project"
    printf 'module cwf\n' > "$HOME/config/config.conf"
    printf 'host\tsol\tops@sol\n' > "$HOME/config/hosts.conf"
    printf 'alpha\t/tmp/alpha\tbase\t/tmp/alpha\tmain\nlinked\t/tmp/linked\tworktree\t/tmp/alpha\tfeature\n' > "$HOME/.cache/marksharc/test/repos/local.tsv"
    printf 'remote-repo\t/srv/remote-repo\tbase\t/srv/remote-repo\tmain\n' > "$HOME/.cache/marksharc/test/repos/sol.tsv"
    git -C "$HOME/project" init -q || return 1
    git -C "$HOME/project" -c user.name=Test -c user.email=test@example.invalid commit -qm initial --allow-empty || return 1
    git -C "$HOME/project" branch feature/demo || return 1
    HOST=test MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" MARKSHARC_HOST=test \
      XDG_CACHE_HOME="$HOME/.cache" "$MARKSHARC_ROOT/bin/marksharc" render >/dev/null || return 1
    cat > "$HOME/.zshrc" <<'DATA'
fpath=( "$XDG_CACHE_HOME/marksharc/test/completions/zsh" $fpath )
autoload -Uz compinit
compinit -i -D
cwf-new() { printf '%s\n' "$*" >> "$OPLOG"; }
DATA
    local typed=$'cd "$HOME/project"\ncwf-new --host so\t\ncwf-new --host sol --repo rem\t\ncwf-new --repo al\t\ncwf-new --mux tmu\t\ncwf-new --place hi\t\ncwf-new --lau\t\ncwf-new feat\t\nexit\n'
    PTY_INPUT=$typed ms_pty MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" \
      MARKSHARC_HOST=test XDG_CACHE_HOME="$HOME/.cache" -di || { cat "$TEST_ROOT/out"; return 1; }
    local expected=$'--host sol\n--host sol --repo remote-repo\n--repo alpha\n--mux tmux\n--place hidden\n--launch\nfeature/demo'
    [[ $(<"$OPLOG") == "$expected" ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
  }
  It 'completes --host, cached base repositories, launch options, and local git branches'
    When run cwf_completion_case
    The status should be success
  End
End
