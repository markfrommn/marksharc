Describe 'system and workflow modules through the real tree'
  # _ms_fs_root is the core's file-probe seam: no spec depends on the host's real /data/work.
  real_tree() {
    ms_fixture_full
    # The brew module's setup-homebrew would run the (forbidden) brew stub.
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    # The greeting module requires fortune (its option is off, so it never runs).
    printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/fortune"; chmod +x "$TEST_ROOT/bin/fortune"
  }
  wiring_case() {
    emulate -L zsh
    real_tree
    printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/fish"; chmod +x "$TEST_ROOT/bin/fish"
    # A neutral stand-in for the author's private overlay (design rule 10):
    # roots/orgs arrive as options and a private module registers a cwf-new hook.
    # The loader resets declared option variables to their defaults at the init
    # plan, so an overlay sets another module's options in its init.zsh (the
    # source's convoy pattern), never in env.zsh.
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/demo-work"
    print 'describe "demo work roots"' > "$XDG_CONFIG_HOME/marksharc/modules/demo-work/module.conf"
    cat > "$XDG_CONFIG_HOME/marksharc/modules/demo-work/init.zsh" <<'DATA'
[[ -n $_ms_opt_git_worktree_roots ]] || _ms_opt_git_worktree_roots="/work/one /work/two"
[[ -n $_ms_opt_git_worktree_orgs ]] || _ms_opt_git_worktree_orgs="org-one org-two"
typeset -gaU cwf_new_post_create_hooks cwf_new_copy_exclude
cwf_new_post_create_hooks=( demo-cwf-new-hook ${cwf_new_post_create_hooks:#demo-cwf-new-hook} )
cwf_new_copy_exclude+=( 'demo:.env' )
DATA
    ms_pty _ms_fs_root="$TEST_ROOT/fs" -dic 'for f in gwt-clean git-managed git-unmanaged git_managed_arr_core cwf-new fix-tmux run-fish setup-ssh-agent chdir-set-title set-title; do [[ $(whence -w $f) == *function ]] || print -r -- "MISSING:$f"; done; for f in repo-sync clean-ssh-agents cleanup-docker fix-docker-socket; do whence -p "$f" >/dev/null || print -r -- "MISSING:$f"; done; print -r -- "HOOKS:${(j:,:)chpwd_functions} SKIP:${chdir_set_title_skip-unset}"; print -r -- "OPT:${_ms_opt_git_worktree_roots}|${_ms_opt_git_worktree_orgs}"; print -r -- "CWFHOOK:${(j:,:)cwf_new_post_create_hooks} ${(j:,:)cwf_new_copy_exclude}"; exit' || return 1
    local out=$(<"$TEST_ROOT/out")
    [[ $out != *MISSING:* && $out != *'not found'* && $out != *'no such'* ]] || { print -r -- "$out"; return 2; }
    [[ $out == *'HOOKS:'*chdir-set-title*' SKIP:unset'* ]] || { print -r -- "$out"; return 3; }
    [[ $out == *'OPT:/work/one /work/two|org-one org-two'* ]] || { print -r -- "$out"; return 4; }
    [[ $out == *'CWFHOOK:demo-cwf-new-hook demo:.env'* ]] || { print -r -- "$out"; return 5; }
  }
  It 'autoloads the module functions and registers hooks and options in a PTY session'
    When run wiring_case
    The status should be success
  End
  order_case() {
    emulate -L zsh
    real_tree
    mkdir -p "$HOME/.ssh"
    ms_pty _ms_fs_root="$TEST_ROOT/fs" MARKSHARC_VERBOSE=1 -dic 'exit' || return 1
    # The trace names each module file as it is sourced, env phase first, then init.
    local -a env_seen=( ${(f)"$(grep -o 'module [a-z0-9-]*: env.zsh$' "$TEST_ROOT/out" | sed 's/module \(.*\): env.zsh/\1/')"} )
    local -a seen=( ${(f)"$(grep -o 'module [a-z0-9-]*: init.zsh$' "$TEST_ROOT/out" | sed 's/module \(.*\): init.zsh/\1/')"} )
    local -a want got
    local m
    # Env phase: brew (10) before the user-tier contributors (go, rust, bun, pnpm).
    # The private overlay's bindir module that followed them is synthesized per
    # spec, not here.
    want=( path brew go rust bun pnpm ); got=()
    for m in $env_seen; do (( ${want[(Ie)$m]} )) && got+=( $m ); done
    [[ ${(j: :)got} == ${(j: :)want} ]] || { print -r -- "env got: ${(j: :)got}"; return 2; }
    # Init phase: the system and workflow modules in the old startup sequence, against the
    # environment and tool modules: completion (70) before herdr (78) and cwf (79), the
    # 90-99 band last (titles 90, x11 91, ssh-agent 93), greeting (94) after ssh-agent.
    # The author's private modules (convoy, mark-tools, site-bac) never load in this repo.
    want=( completion cwf titles x11 ssh-agent greeting ); got=()
    for m in $seen; do (( ${want[(Ie)$m]} )) && got+=( $m ); done
    [[ ${(j: :)got} == ${(j: :)want} ]] || { print -r -- "init got: ${(j: :)got}"; return 3; }
    # Nothing loads after greeting: it is the last init of the tree.
    [[ ${seen[-1]} == greeting ]] || { print -r -- "last init: ${seen[-1]}"; return 4; }
  }
  It 'loads the env and init phases in the order that reproduces the old startup sequence'
    When run order_case
    The status should be success
  End
  quiet_case() {
    emulate -L zsh
    real_tree
    mkdir -p "$HOME/.ssh"
    ms_run _ms_fs_root="$TEST_ROOT/fs" CLAUDECODE=1 -ic 'print READY' || return 1
    [[ $(<"$TEST_ROOT/out") == READY && ! -s "$TEST_ROOT/err" ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    ms_run _ms_fs_root="$TEST_ROOT/fs" -c 'print READY' || return 3
    [[ $(<"$TEST_ROOT/out") == READY && ! -s "$TEST_ROOT/err" ]] || return 4
    ms_pty _ms_fs_root="$TEST_ROOT/fs" -dic 'print READY2; exit' || return 5
    [[ $(<"$TEST_ROOT/out") == *READY2* && $(<"$TEST_ROOT/out") != *rror* && $(<"$TEST_ROOT/out") != *'no such'* && $(<"$TEST_ROOT/out") != *'not found'* ]] || { cat "$TEST_ROOT/out"; return 6; }
  }
  It 'stays silent in agent and batch sessions and error-free in a PTY session'
    When run quiet_case
    The status should be success
  End
End
