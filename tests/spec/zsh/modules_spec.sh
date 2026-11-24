Describe 'module tree: bands, idempotency, tree layout and loading'
  # Every module under modules/ is covered; no list of module names is kept here.
  # The per-module contract (describe, order range, syntax, linked tests) is in module_specs_spec.sh;
  # this file holds the cross-module rules.
  modules_dir() { print -r -- "$MARKSHARC_ROOT/modules"; }
  all_modules() { local -a m=( "$MARKSHARC_ROOT"/modules/*/module.conf(N:h:t) ); print -r -- "${(j: :)m}"; }
  band_case() {
    emulate -L zsh
    local name conf order lo hi dir=$(modules_dir)
    local -a mods=( ${=$(all_modules)} )
    (( $#mods > 0 )) || { print "no modules found"; return 1; }
    for name in $mods; do
      conf=$dir/$name/module.conf
      order=$(sed -n 's/^order //p' "$conf")
      [[ -n $order ]] || order=50
      # Reserved bands of spec 6.4; herdr and cwf sit at the top of the completion band
      # because they register completions after the completion module.
      case $name in
        path) lo=0 hi=9 ;;
        brew) lo=10 hi=19 ;;
        completion|completion-fzf-tab|fzf-fish|herdr|cwf) lo=70 hi=79 ;;
        nav|zoxide|prompt-starship|history-atuin|history-native) lo=80 hi=89 ;;
        titles|x11|ssh-agent|greeting) lo=90 hi=94 ;;
        # Line-editor plugins that wrap widgets load last of all.
        zsh-autosuggestions|zsh-syntax-highlighting) lo=95 hi=99 ;;
        *) lo=20 hi=69 ;;
      esac
      (( order >= lo && order <= hi )) || { print "$name order $order outside $lo-$hi"; return 2; }
    done
  }
  It 'keeps every module inside its reserved load-order band'
    When run band_case
    The status should be success
  End
  idempotent_case() {
    emulate -L zsh
    local name dir=$(modules_dir) phase failed=
    # Every env.zsh and init.zsh is sourced twice in one shell, the way a reload does;
    # init also gets the module's autoloaded functions. Output and errors are failures.
    for name in ${=$(all_modules)}; do
      for phase in env init; do
        [[ -r $dir/$name/$phase.zsh ]] || continue
        cat > "$TEST_ROOT/child.zsh" <<DATA
MARKSHARC_SESSION=interactive; _ms_reloading=1
_ms_fs_root=$TEST_ROOT/fs
_ms_mod_dir=( $name $dir/$name ); typeset -A _ms_mod_dir
source "\$MARKSHARC_HOME/modules/path/env.zsh"
fpath=( $dir/$name/functions/zsh \$fpath )
autoload -Uz $dir/$name/functions/zsh/*(N-.:t)
source $dir/$name/$phase.zsh || exit 11
source $dir/$name/$phase.zsh || exit 12
DATA
        ms_unit "source $TEST_ROOT/child.zsh"
        if [[ $? != 0 || -s $TEST_ROOT/err ]]; then failed+=" $name/$phase:$(<"$TEST_ROOT/err")"; fi
      done
    done
    [[ -z $failed ]] || { print -r -- "$failed"; return 1; }
  }
  It 'sources every module file twice without error or output'
    When run idempotent_case
    The status should be success
  End
  layout_case() {
    emulate -L zsh
    # The public tree holds the core and the module directories, nothing else.
    local -a found=( "$MARKSHARC_ROOT"/modules/*(N:t) )
    (( $#found > 0 )) || { print 'no modules'; return 1; }
    [[ -r $MARKSHARC_ROOT/core/zsh/zshenv.zsh && -d $MARKSHARC_ROOT/core/zsh/lib ]] || return 2
    [[ ! -e $MARKSHARC_ROOT/modules/legacy ]] || return 3
  }
  It 'keeps the public tree to the core and the module directories'
    When run layout_case
    The status should be success
  End
  full_start_case() {
    emulate -L zsh
    ms_fixture_full
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    local tool
    for tool in zoxide starship atuin herdr cwf; do printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/$tool"; chmod +x "$TEST_ROOT/bin/$tool"; done
    # The loader runs every new module in an interactive session with its trace on.
    ms_pty MARKSHARC_VERBOSE=1 -dic 'print READY' || return 1
    local out=$(<"$TEST_ROOT/out") name
    for name in path brew zsh-options editor pager ls nav completion command-not-found; do
      [[ $out == *"marksharc: module $name:"* ]] || { print "module $name not loaded"; return 2; }
    done
    [[ $out != *'returned'* && $out != *'failed validation'* ]] || { print -r -- "$out"; return 3; }
    # Silent herdr/cwf stubs replace the global FORBIDDEN ones: the P1.6 modules
    # legitimately probe these tools at startup, but with a silent session list
    # and no COMMON_DEV_TOOLS nothing may reach the operation log.
    [[ ! -s $OPLOG ]] || { grep FORBIDDEN "$OPLOG"; return 4; }
  }
  It 'loads the modules through the loader in an interactive session'
    When run full_start_case
    The status should be success
  End
End
