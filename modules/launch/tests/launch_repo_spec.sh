Describe 'repository inventory and launcher'
  repo_list() { "$MARKSHARC_ROOT/modules/git-worktree/bin/repo-list" "$@"; }
  launch_repo() { "$MARKSHARC_ROOT/modules/launch/bin/launch-repo" "$@"; }

  inventory_case() {
    export MARKSHARC_HOST=test
    local config="$XDG_CONFIG_HOME/marksharc"
    mkdir -p "$HOME/repos/alpha" "$config"
    git -C "$HOME/repos/alpha" init -q || return
    git -C "$HOME/repos/alpha" -c user.name=Test -c user.email=test@example.test commit --allow-empty -qm initial || return
    git -C "$HOME/repos/alpha" worktree add -qb 'feature/topic' "$HOME/linked tree" || return
    printf 'set git-worktree.roots %s\n' "$HOME/repos" > "$config/config.conf"
    local out cache="$XDG_CACHE_HOME/marksharc/$MARKSHARC_HOST/repos/local.tsv"
    out=$(repo_list --porcelain) || return 1
    [[ $out == *$'alpha\t'*$'\tbase\t'* && $out == *$'linked tree\t'*$'\tworktree\t'*'feature/topic'* ]] || return 2
    local mode
    if [[ $(uname -s) == Darwin ]]; then mode=$(stat -f %Lp "$cache"); else mode=$(stat -c %a "$cache"); fi
    [[ $mode == 600 ]] || return 3
    mkdir -p "$HOME/repos/new"
    git -C "$HOME/repos/new" init -q || return
    out=$(repo_list --name new) || return 4
    [[ $out == *$'new\t'* ]] || return 5
  }
  It 'scans linked worktrees and refreshes a missing name'
    When run inventory_case
    The status should be success
  End

  remote_case() {
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print 'host peer user@server' > "$XDG_CONFIG_HOME/marksharc/hosts.conf"
    stub_command ssh 'printf "%s\n" "$@" > "$TEST_ROOT/ssh-argv"; printf "alpha\t/srv/alpha\tbase\t/srv/alpha\t\n"'
    local out
    out=$(repo_list --host peer --porcelain) || return 1
    [[ $out == $'alpha\t/srv/alpha\tbase\t/srv/alpha\t' ]] || return 2
    [[ $(<"$TEST_ROOT/ssh-argv") == *$'BatchMode=yes\n'*$'ConnectTimeout=10\n'*$'user@server\nrepo-list\n--porcelain'* ]] || return 3
    stub_command ssh 'printf "malformed\n"'
    repo_list --host peer --rescan >/dev/null 2>&1 && return 4
    [[ $(<"$XDG_CACHE_HOME/marksharc/test/repos/peer.tsv") == *$'alpha\t/srv/alpha'* ]] || return 5
    stub_command ssh 'printf "%s\n" "$@" > "$TEST_ROOT/ssh-argv"; printf "new\t/srv/new\tbase\t/srv/new\tmain\n"'
    out=$(repo_list --host peer) || return 5
    [[ $out == $'new\t/srv/new\tbase\t/srv/new\tmain' && $(<"$TEST_ROOT/ssh-argv") != *--rescan* ]]
  }
  It 'validates remote inventory before replacing the cache'
    When run remote_case
    The status should be success
  End

  edge_case() {
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/repos/quoted'base"
    repo_list >/dev/null || return 1
    repo_list >/dev/null || return 2
    git -C "$HOME/repos/quoted'base" init -q || return 3
    print "set git-worktree.roots $HOME/repos" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    local out
    out=$(repo_list) || return 4
    [[ $out == *"quoted'base"* ]] || return 5
    out=$(repo_list) || return 6
    [[ $out == *"quoted'base"* ]]
  }
  It 'caches an empty inventory and preserves quoted paths after roots change'
    When run edge_case
    The status should be success
  End

  freshness_case() {
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/repos/old"
    git -C "$HOME/repos/old" init -q || return 1
    print "set git-worktree.roots $HOME/repos" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    repo_list >/dev/null || return 2
    rm -rf "$HOME/repos/old"
    mkdir -p "$HOME/repos/new"
    git -C "$HOME/repos/new" init -q || return 3
    local out=$(repo_list) || return 4
    [[ $out == *$'new\t'* && $out != *$'old\t'* ]] || return 5
    mkdir -p "$HOME/repos/another"
    git -C "$HOME/repos/another" init -q || return 6
    print 'set launch.repo_cache_minutes 0' >> "$XDG_CONFIG_HOME/marksharc/config.conf"
    out=$(repo_list) || return 7
    [[ $out == *$'another\t'* ]]
  }
  It 'refreshes missing cached paths and expired inventories'
    When run freshness_case
    The status should be success
  End

  remote_errors_case() {
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    repo_list --host missing >/dev/null 2>&1 && return 1
    print 'host peer user@server' > "$XDG_CONFIG_HOME/marksharc/hosts.conf"
    stub_command ssh 'exit 255'
    repo_list --host peer >/dev/null 2>&1 && return 2
    [[ ! -e $XDG_CACHE_HOME/marksharc/test/repos/peer.tsv ]]
  }
  It 'propagates absent targets and SSH failures'
    When run remote_errors_case
    The status should be success
  End

  remote_retry_case() {
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print 'host peer user@server' > "$XDG_CONFIG_HOME/marksharc/hosts.conf"
    stub_command ssh 'printf "%s\n" "$*" >> "$TEST_ROOT/calls"; printf "alpha\t/srv/alpha\tbase\t/srv/alpha\tmain\n"'
    repo_list --host peer >/dev/null || return 1
    : > "$TEST_ROOT/calls"
    launch_repo --host peer --repo alpha --worktree missing >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"
    [[ $? == 1 ]] || return 2
    local -a calls=( "${(@f)$(<"$TEST_ROOT/calls")}" )
    (( $#calls == 2 )) || return 3
    [[ $calls[1] != *--rescan* && $calls[2] == *--rescan* ]]
  }
  It 'rescans once after a remote worktree miss'
    When run remote_retry_case
    The status should be success
  End

  handoff_case() {
    export MARKSHARC_HOST=test TMUX_ROWS='$3:work'
    mkdir -p "$HOME/repos/alpha" "$XDG_CONFIG_HOME/marksharc"
    git -C "$HOME/repos/alpha" init -q || return 1
    git -C "$HOME/repos/alpha" -c user.name=Test -c user.email=test@example.test commit --allow-empty -qm initial || return 1
    git -C "$HOME/repos/alpha" worktree add -qb 'feature/topic' "$HOME/linked tree" || return 1
    print "set git-worktree.roots $HOME/repos" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    stub_command tmux 'case "$*" in *list-sessions*) printf "%s\n" "\0443:work" ;; *display-message*) exit 1 ;; *new-window*|*new-session*) printf "%s\0" "$@" > "$OPLOG"; printf "\0443:@4.%%5\n" ;; esac'
    launch_repo --mux tmux --env 'NOTE=a b;$' alpha/feature/topic printf 'a b;$' >/dev/null 2>"$TEST_ROOT/err" || return 2
    local data=$(tr '\0' '\n' < "$OPLOG")
    [[ $data == *"$HOME/linked tree"* && $data == *'NOTE=a b;$'* && $data == *'a b;$'* ]] || return 3
    launch_repo --mux tmux --host local --repo alpha --worktree 'feature/topic' --command printf -- 'literal ;$' >/dev/null 2>"$TEST_ROOT/err" || return 4
    data=$(tr '\0' '\n' < "$OPLOG")
    [[ $data == *"$HOME/linked tree"* && $data == *'literal ;$'* ]] || return 5
    launch_repo --mux tmux "$HOME/repos/alpha" >/dev/null 2>"$TEST_ROOT/err" || return 6
    data=$(tr '\0' '\n' < "$OPLOG")
    [[ $data == *"$HOME/repos/alpha"* ]] || return 7
    ( cd "$HOME/linked tree" && launch_repo --mux tmux . >/dev/null 2>"$TEST_ROOT/err" ) || return 8
    data=$(tr '\0' '\n' < "$OPLOG")
    [[ $data == *"$HOME/linked tree"* ]]
  }
  It 'resolves branch names and forwards literal command arguments'
    When run handoff_case
    The status should be success
  End

  base_only_case() {
    [[ -n $PYTHON ]] || return 0
    export MARKSHARC_HOST=test
    mkdir -p "$HOME/repos/alpha" "$XDG_CONFIG_HOME/marksharc"
    git -C "$HOME/repos/alpha" init -q || return 1
    git -C "$HOME/repos/alpha" -c user.name=Test -c user.email=test@example.test commit --allow-empty -qm initial || return 2
    git -C "$HOME/repos/alpha" worktree add -qb feature "$HOME/linked" || return 3
    print "set git-worktree.roots $HOME/repos" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    stub_command gum 'tee "$TEST_ROOT/picker" | head -n 1'
    stub_command tmux 'case "$*" in *list-sessions*) printf "%s\n" "\0443:work" ;; *display-message*) exit 1 ;; esac'
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "$MARKSHARC_ROOT/modules/launch/bin/launch-repo" --base-only --mux tmux --dry-run > "$TEST_ROOT/out" || return 4
    [[ $(<"$TEST_ROOT/picker") == *"$HOME/repos/alpha"* && $(<"$TEST_ROOT/picker") != *"$HOME/linked"* ]] || return 5
    launch_repo --base-only --mux tmux --dry-run "$HOME/linked" > "$TEST_ROOT/out" 2>&1 || return 6
    [[ $(<"$TEST_ROOT/out") == *"$HOME/repos/alpha"* && $(<"$TEST_ROOT/out") != *"$HOME/linked"* ]]
  }
  It 'restricts a creation picker and linked path to the base repository'
    When run base_only_case
    The status should be success
  End

  remote_base_only_case() {
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print 'host peer user@server' > "$XDG_CONFIG_HOME/marksharc/hosts.conf"
    stub_command ssh 'printf "alpha\t/srv/alpha\tbase\t/srv/alpha\tmain\nlinked\t/srv/linked\tworktree\t/srv/alpha\tfeature\n"'
    stub_command tmux 'exit 1'
    # A missing path is rejected before selection of a multiplexer.
    launch_repo --base-only --host peer --repo /srv/missing > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 1 && $(<"$TEST_ROOT/err") == *'remote repository path not in inventory'* ]] || return 1
    # A mapped linked path reaches launch-session, where tmux cannot serve a remote host.
    launch_repo --base-only --host peer --repo /srv/linked --mux tmux --dry-run > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? == 1 && $(<"$TEST_ROOT/err") == *'no usable multiplexer'* ]]
  }
  It 'validates remote creation paths against the target inventory'
    When run remote_base_only_case
    The status should be success
  End

  validation_case() {
    launch_repo --pwd /tmp >/dev/null 2>&1; [[ $? == 2 ]] || return 1
    launch_repo alpha --repo beta >/dev/null 2>&1; [[ $? == 2 ]] || return 2
    launch_repo --repo alpha beta >/dev/null 2>&1; [[ $? == 2 ]] || return 3
    launch_repo --worktree work >/dev/null 2>&1; [[ $? == 2 ]] || return 4
    launch_repo --repo /tmp --worktree work >/dev/null 2>&1; [[ $? == 2 ]]
  }
  It 'rejects conflicting forms and unsupported paths'
    When run validation_case
    The status should be success
  End

  worktree_refresh_case() {
    export MARKSHARC_HOST=test
    mkdir -p "$HOME/repos/alpha" "$XDG_CONFIG_HOME/marksharc"
    git -C "$HOME/repos/alpha" init -q || return 1
    git -C "$HOME/repos/alpha" -c user.name=Test -c user.email=test@example.test commit --allow-empty -qm initial || return 2
    print "set git-worktree.roots $HOME/repos" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    repo_list >/dev/null || return 3
    git -C "$HOME/repos/alpha" worktree add -qb other "$HOME/topic" || return 4
    git -C "$HOME/repos/alpha" worktree add -qb topic "$HOME/elsewhere" || return 5
    stub_command tmux 'case "$*" in *list-sessions*) printf "%s\n" "\0443:work" ;; *display-message*) exit 1 ;; *new-window*|*new-session*) printf "%s\0" "$@" > "$OPLOG"; printf "\0443:@4.%%5\n" ;; esac'
    launch_repo --mux tmux alpha/topic >/dev/null 2>"$TEST_ROOT/err" || return 6
    local data=$(tr '\0' '\n' < "$OPLOG")
    [[ $data == *"$HOME/topic"* && $data != *"$HOME/elsewhere"* ]] || return 7
    launch_repo --mux tmux alpha/missing >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"
    [[ $? == 1 && $(<"$TEST_ROOT/err") == *'alpha/topic'* && $(<"$TEST_ROOT/err") == *'alpha/other'* ]] || return 12
    mkdir -p "$HOME/repos/new"
    git -C "$HOME/repos/new" init -q || return 8
    repo_list --rescan > "$TEST_ROOT/out" || return 9
    [[ $(<"$TEST_ROOT/out") == *$'new\t'* ]] || return 10
    local line
    local -a fields
    while IFS= read -r line; do
        fields=( "${(@ps:\t:)line}" )
        (( $#fields == 5 )) || return 11
    done < "$TEST_ROOT/out"
  }
  It 'rescans for a missing worktree and prefers its directory over a branch'
    When run worktree_refresh_case
    The status should be success
  End

  duplicate_case() {
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/one/same" "$HOME/two/same"
    git -C "$HOME/one/same" init -q || return 1
    git -C "$HOME/two/same" init -q || return 1
    print "set git-worktree.roots $HOME/one $HOME/two" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    launch_repo same >"$TEST_ROOT/out" 2>"$TEST_ROOT/err"
    [[ $? == 3 && $(<"$TEST_ROOT/err") == *"$HOME/one/same"* && $(<"$TEST_ROOT/err") == *"$HOME/two/same"* ]]
  }
  It 'lists duplicate paths and returns 3 without a terminal'
    When run duplicate_case
    The status should be success
  End

  duplicate_pick_case() {
    [[ -n $PYTHON ]] || return 0
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$HOME/one/same" "$HOME/two/same"
    git -C "$HOME/one/same" init -q || return 1
    git -C "$HOME/two/same" init -q || return 2
    print "set git-worktree.roots $HOME/one $HOME/two" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    stub_command gum 'head -n 1'
    stub_command tmux 'case "$*" in *list-sessions*) printf "%s\n" "\0443:work" ;; *display-message*) exit 1 ;; esac'
    local result
    result=$("$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "$MARKSHARC_ROOT/modules/launch/bin/launch-repo" --mux tmux --dry-run same) || return 3
    [[ $result == *"$HOME/one/same"* ]]
  }
  It 'uses the picker to select among duplicate bases'
    When run duplicate_pick_case
    The status should be success
  End

  completion_case() {
    [[ -n $REAL_FISH ]] || return 0
    export MARKSHARC_HOST=test
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$XDG_CACHE_HOME/marksharc/test/repos"
    printf 'module launch\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    HOST=test MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_HOST=test "$MARKSHARC_ROOT/bin/marksharc" render >/dev/null || return 1
    printf '# marksharc-repos\t1\t0\t\nalpha\t/tmp/alpha\tbase\t/tmp/alpha\tmain\n' > "$XDG_CACHE_HOME/marksharc/test/repos/local.tsv"
    stub_command ssh 'exit 99'
    stub_command git 'exit 99'
    local out
    out=$(MARKSHARC_HOME="$MARKSHARC_ROOT" "$REAL_FISH" -c 'source "$XDG_CACHE_HOME/marksharc/test/completions/fish/launch-repo.fish"; complete -C "launch-repo al"') || return 1
    [[ $out == *alpha* ]]
  }
  It 'completes cached names without contacting a service'
    When run completion_case
    The status should be success
  End

  It 'requires a terminal when no repository is selected'
    When run launch_repo
    The status should equal 3
    The stderr should include 'Selection needs a terminal'
  End

  It 'rejects reserved worktree creation'
    When run launch_repo 'alpha/new:branch'
    The status should equal 2
    The stderr should include 'creation is reserved'
  End
End
