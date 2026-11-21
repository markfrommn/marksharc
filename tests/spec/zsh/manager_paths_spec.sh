Describe 'version-manager paths: nvm, gvm, pyenv'
  # Unit cases source the module env.zsh under zsh -f; the integration cases start the
  # whole copied tree. _ms_fs_root points system probes at a fixture root, so a
  # Homebrew-style directory exists on every host and the real one is never seen.
  nvm_layout() {
    export NVM_DIR="$HOME/.nvm"
    mkdir -p "$NVM_DIR/alias/lts" "$NVM_DIR"/versions/node/{v24.9.0,v24.19.0,v24.22.3,v26.1.0,v20.11.1}/bin
  }
  nvm_default() {
    # nvm_default <alias-content> : prints the resolved bin directory relative to NVM_DIR
    print -r -- "$1" > "$NVM_DIR/alias/default"
    ms_unit "NVM_DIR=$NVM_DIR
      source \"\$MARKSHARC_HOME/modules/node-nvm/env.zsh\"
      _ms_nvm_default && print -r -- \"\${REPLY#$NVM_DIR/}\""
    cat "$TEST_ROOT/out"
  }
  nvm_resolution_case() {
    emulate -L zsh
    nvm_layout
    [[ $(nvm_default 24) == versions/node/v24.22.3/bin ]] || { print "24 -> $(nvm_default 24)"; return 1; }
    [[ $(nvm_default v24.19) == versions/node/v24.19.0/bin ]] || return 2
    [[ $(nvm_default v24.9.0) == versions/node/v24.9.0/bin ]] || return 3
    [[ $(nvm_default 2) == '' ]] || return 4
    [[ $(nvm_default node) == versions/node/v26.1.0/bin ]] || return 5
    [[ $(nvm_default stable) == versions/node/v26.1.0/bin ]] || return 6
    print -r -- 'lts/iron' > "$NVM_DIR/alias/lts/*"
    print -r -- 'v20.11.1' > "$NVM_DIR/alias/lts/iron"
    [[ $(nvm_default 'lts/*') == versions/node/v20.11.1/bin ]] || { print "lts -> $(nvm_default 'lts/*')"; return 7; }
    [[ $(nvm_default system) == '' && $(nvm_default bogus-alias) == '' && $(nvm_default 99) == '' ]] || return 8
    rm "$NVM_DIR/alias/default"
    ms_unit "NVM_DIR=$NVM_DIR
      source \"\$MARKSHARC_HOME/modules/node-nvm/env.zsh\"
      _ms_nvm_default && print found" ; [[ ! -s $TEST_ROOT/out ]] || return 9
  }
  It 'resolves the nvm default alias to the newest matching node bin directory without forking'
    When run nvm_resolution_case
    The status should be success
  End
  gvm_select_case() {
    emulate -L zsh
    local v root="$HOME/.gvm"
    mkdir -p "$root/environments"
    for v in go1.9 go1.27.4 go1.27.10 system; do
      mkdir -p "$root/gos/$v/bin"; printf '#!/bin/sh\n' > "$root/gos/$v/bin/go"; chmod +x "$root/gos/$v/bin/go"
    done
    mkdir -p "$root/gos/go1.30/bin"   # no go binary: never chosen
    ms_unit "source \"\$MARKSHARC_HOME/modules/go-gvm/env.zsh\"; _ms_gvm_select; print -r -- \"[\$REPLY]\"" || return 1
    [[ $(<"$TEST_ROOT/out") == '[go1.27.10]' ]] || { cat "$TEST_ROOT/out"; return 2; }
    printf 'export gvm_go_name="go1.27.4"\nexport GOROOT="/x"\n' > "$root/environments/default"
    ms_unit "source \"\$MARKSHARC_HOME/modules/go-gvm/env.zsh\"; _ms_gvm_select; print -r -- \"[\$REPLY]\"" || return 3
    [[ $(<"$TEST_ROOT/out") == '[go1.27.4]' ]] || { cat "$TEST_ROOT/out"; return 4; }
    # A default that names a Go which is not installed falls back to the newest.
    printf 'export gvm_go_name="go9.9"\n' > "$root/environments/default"
    ms_unit "source \"\$MARKSHARC_HOME/modules/go-gvm/env.zsh\"; _ms_gvm_select; print -r -- \"[\$REPLY]\"" || return 5
    [[ $(<"$TEST_ROOT/out") == '[go1.27.10]' ]] || return 6
    rm -rf "$root/gos"
    ms_unit "source \"\$MARKSHARC_HOME/modules/go-gvm/env.zsh\"; _ms_gvm_select && print found" ; [[ ! -s $TEST_ROOT/out ]]
  }
  It 'selects the default environment Go, else the numerically newest installed Go'
    When run gvm_select_case
    The status should be success
  End
  goroot_case() {
    emulate -L zsh
    local root="$HOME/.gvm" brew="$TEST_ROOT/brewgo/bin" other="$TEST_ROOT/othergo/libexec/bin"
    mkdir -p "$root/gos/go1.27.4/bin" "$brew" "$other"
    printf '#!/bin/sh\n' > "$root/gos/go1.27.4/bin/go"; cp "$root/gos/go1.27.4/bin/go" "$brew/go"; cp "$root/gos/go1.27.4/bin/go" "$other/go"
    chmod +x "$root/gos/go1.27.4/bin/go" "$brew/go" "$other/go"
    local run='source "$MARKSHARC_HOME/modules/go-gvm/env.zsh"; _ms_gvm_finalize; print -r -- "GOROOT=${GOROOT-unset}"'
    # gvm Go first: GOROOT names it, even over a stale inherited value.
    ms_unit "path=( $root/gos/go1.27.4/bin $brew /usr/bin ) GOROOT=/stale/go
      $run" || return 1
    [[ $(<"$TEST_ROOT/out") == "GOROOT=$root/gos/go1.27.4" ]] || { cat "$TEST_ROOT/out"; return 2; }
    # Homebrew-style Go first and a GOROOT that names another Go: removed.
    ms_unit "path=( $brew $root/gos/go1.27.4/bin /usr/bin ) GOROOT=$root/gos/go1.27.4
      $run" || return 3
    [[ $(<"$TEST_ROOT/out") == 'GOROOT=unset' ]] || { cat "$TEST_ROOT/out"; return 4; }
    # A GOROOT that matches the first Go stays (also through its own bin directory).
    ms_unit "path=( $other /usr/bin ) GOROOT=$TEST_ROOT/othergo/libexec
      $run" || return 5
    [[ $(<"$TEST_ROOT/out") == "GOROOT=$TEST_ROOT/othergo/libexec" ]] || { cat "$TEST_ROOT/out"; return 6; }
    # No go on PATH: nothing changes. The PATH is a guaranteed go-free fixture
    # directory; a host directory like /usr/bin may hold a real go on some CI images.
    mkdir -p "$TEST_ROOT/nogo"
    ms_unit "path=( $TEST_ROOT/nogo ) GOROOT=/keep
      $run" || return 7
    [[ $(<"$TEST_ROOT/out") == 'GOROOT=/keep' ]] || return 8
    # Not a rebuild: an inherited environment is left as it is.
    ms_unit "path=( $brew /usr/bin ) GOROOT=/inherited _ms_env_rebuild=0
      $run" || return 9
    [[ $(<"$TEST_ROOT/out") == 'GOROOT=/inherited' ]]
  }
  It 'makes GOROOT agree with the first go on PATH'
    When run goroot_case
    The status should be success
  End

  # A stub that behaves like gvm's own script: sourcing it activates the default environment
  # (resetting GOROOT and GOPATH to it), and gvm use switches all of them.
  gvm_stub() {
    cat > "$HOME/.gvm/scripts/gvm" <<'DATA'
source "$HOME/.gvm/environments/default"
export GVM_VERSION=stub
export GOROOT="$HOME/.gvm/gos/$gvm_go_name" GOPATH="$HOME/.gvm/pkgsets/$gvm_go_name/global"
path=( "$HOME/.gvm/pkgsets/$gvm_go_name/global/bin" "$HOME/.gvm/gos/$gvm_go_name/bin" "$HOME/.gvm/bin" "${path[@]}" )
gvm() {
  case $1 in
    use)
      export gvm_go_name=$2 GOROOT="$HOME/.gvm/gos/$2" GOPATH="$HOME/.gvm/pkgsets/$2/global"
      path=( "$HOME/.gvm/pkgsets/$2/global/bin" "$HOME/.gvm/gos/$2/bin" "${path[@]}" )
      print "gvm use $2" >> "$OPLOG" ;;
  esac
  return 0
}
DATA
  }
  mgr_fixture() {
    ms_fixture_full
    local root="$TEST_ROOT/root" v
    mkdir -p "$root"/opt/homebrew/bin "$root"/usr/local/bin
    nvm_layout
    print 24 > "$NVM_DIR/alias/default"
    for v in go1.27.3 go1.27.4; do
      mkdir -p "$HOME/.gvm/gos/$v/bin"
      printf '#!/bin/sh\n' > "$HOME/.gvm/gos/$v/bin/go"; chmod +x "$HOME/.gvm/gos/$v/bin/go"
    done
    mkdir -p "$HOME/.gvm/environments" "$HOME/.gvm/scripts"
    print 'export gvm_go_name="go1.27.3"' > "$HOME/.gvm/environments/default"
    # Tools that startup may run are benign stubs, never the host's.
    local tool
    for tool in zoxide starship atuin herdr cwf; do printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/$tool"; chmod +x "$TEST_ROOT/bin/$tool"; done
    # Homebrew activation would run the real brew of the host.
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    export _ms_fs_root="$root"
    unset NVM_DIR
  }
  # The nvm and gvm directories must precede Homebrew's, and GOROOT must name the default Go.
  mgr_check() {
    local -a lines=( "${(@f)$(<"$TEST_ROOT/out")}" )
    lines=( "${(@)lines//$'\r'/}" )
    local n=${lines[(Ie)$HOME/.nvm/versions/node/v24.22.3/bin]} g=${lines[(Ie)$HOME/.gvm/gos/go1.27.3/bin]} b=${lines[(Ie)/opt/homebrew/bin]}
    (( n > 0 && g > 0 && b > 0 )) || { print -l -- $lines; return 1; }
    (( n < b && g < b )) || { print -l -- $lines; return 2; }
    [[ $lines[(r)GOROOT=*] == "GOROOT=$HOME/.gvm/gos/go1.27.3" ]] || { print -l -- $lines; return 3; }
  }
  manager_classes_case() {
    emulate -L zsh
    mgr_fixture
    local flags marker
    local script='print -l $path; print GOROOT=$GOROOT'
    for marker in CLAUDECODE=1 NONE=; do
      for flags in -c -lc; do
        ms_run _ms_fs_root=$_ms_fs_root MARKSHARC_MODULE_GUARD=1 $marker $flags "$script" || return 1
        mgr_check || { print "agent/batch $marker $flags"; return 2; }
      done
    done
    # A path_helper style reorder before .zprofile cannot move Homebrew ahead either:
    # zprofile re-asserts the env phase PATH.
    ms_run _ms_fs_root=$_ms_fs_root -c 'path=( /usr/local/bin /opt/homebrew/bin "$path[@]" ); source "$MARKSHARC_HOME/core/zsh/zprofile.zsh"; print -l $path; print GOROOT=$GOROOT' || return 3
    mgr_check || { print "after the zprofile re-assert"; return 4; }
  }
  It 'puts nvm and gvm directories ahead of Homebrew in agent, batch and login shells'
    When run manager_classes_case
    The status should be success
  End
  manager_interactive_case() {
    emulate -L zsh
    mgr_fixture
    gvm_stub
    ms_pty _ms_fs_root=$_ms_fs_root -dic 'print -l $path; print GOROOT=$GOROOT' || return 1
    mgr_check || return 2
    # gvm's own pkgset bin directory is on PATH although it does not exist yet (GOPATH points
    # at the pkgset, so go install must find its binaries after the first install).
    local -a lines=( "${(@f)$(<"$TEST_ROOT/out")}" )
    lines=( "${(@)lines//$'\r'/}" )
    (( ${lines[(Ie)$HOME/.gvm/pkgsets/go1.27.3/global/bin]} > 0 && ${lines[(Ie)$HOME/.gvm/pkgsets/go1.27.3/global/bin]} < ${lines[(Ie)$HOME/.gvm/gos/go1.27.3/bin]} )) || { print -l -- $lines; return 3; }
  }
  It 'keeps the manager directories ahead of Homebrew in an interactive shell'
    When run manager_interactive_case
    The status should be success
  End
  explicit_gvm_case() {
    emulate -L zsh
    mgr_fixture
    gvm_stub
    mkdir -p "$HOME/.gvm/gos/go1.25/bin"
    printf '#!/bin/sh\n' > "$HOME/.gvm/gos/go1.25/bin/go"; chmod +x "$HOME/.gvm/gos/go1.25/bin/go"
    # An interactive child of a shell that ran gvm use go1.25: the default environment is
    # go1.27.3, but go on PATH is go1.25, so GOROOT and GOPATH must name go1.25.
    ms_pty _ms_fs_root=$_ms_fs_root PATH="$HOME/.gvm/gos/go1.25/bin:$PATH" -dic 'print -l $path[1,2]; print "GOROOT=$GOROOT GOPATH=$GOPATH NAME=$gvm_go_name"' || return 1
    local out=${$(<"$TEST_ROOT/out")//$'\r'/}
    [[ $out == *"GOROOT=$HOME/.gvm/gos/go1.25 GOPATH=$HOME/.gvm/pkgsets/go1.25/global NAME=go1.25"* ]] || { print -r -- "$out"; return 2; }
    local -a lines=( "${(@f)out}" )
    [[ $lines[1] == *go1.25* ]] || { print -r -- "$out"; return 3; }
    # The default Go: nothing to switch (no gvm use) and the same names.
    : > "$OPLOG"
    ms_pty _ms_fs_root=$_ms_fs_root -dic 'print "GOROOT=$GOROOT NAME=$gvm_go_name"' || return 4
    [[ $(<"$TEST_ROOT/out") == *"GOROOT=$HOME/.gvm/gos/go1.27.3 NAME=go1.27.3"* && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 5; }
  }
  It 'keeps GOROOT, GOPATH and go in step after an explicit gvm use in a parent shell'
    When run explicit_gvm_case
    The status should be success
  End
  agent_pkgset_case() {
    emulate -L zsh
    mgr_fixture
    ms_run _ms_fs_root=$_ms_fs_root CLAUDECODE=1 -c 'print -l $path' || return 1
    # Agent and batch shells keep GOPATH at its default, so a missing pkgset bin stays out.
    [[ $(<"$TEST_ROOT/out") != *pkgsets* ]]
  }
  It 'leaves a missing pkgset bin directory out of agent and batch PATHs'
    When run agent_pkgset_case
    The status should be success
  End
  switched_manager_case() {
    emulate -L zsh
    mgr_fixture
    # A manager the user switched on explicitly stays in front across cs and li.
    mkdir -p "$HOME/.gvm/gos/go1.25/bin"
    ms_run _ms_fs_root=$_ms_fs_root -c 'path=( "$HOME/.gvm/gos/go1.25/bin" "$path[@]" ); export PATH; _ms_force_rebuild=1; source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; print -l $path[1,3]' || return 1
    local -a lines=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ $lines[1] == "$HOME/.gvm/gos/go1.25/bin" ]] || { print -l -- $lines; return 2; }
  }
  It 'keeps an explicitly activated manager in front across a rebuild'
    When run switched_manager_case
    The status should be success
  End
  pyenv_case() {
    emulate -L zsh
    mgr_fixture
    mkdir -p "$HOME/.pyenv/bin" "$HOME/.pyenv/shims"
    printf '#!/bin/sh\n' > "$HOME/.pyenv/bin/pyenv"; chmod +x "$HOME/.pyenv/bin/pyenv"
    ms_run _ms_fs_root=$_ms_fs_root -c 'print -l $path' || return 1
    local -a lines=( "${(@f)$(<"$TEST_ROOT/out")}" )
    (( ${lines[(Ie)$HOME/.pyenv/shims]} > 0 && ${lines[(Ie)$HOME/.pyenv/shims]} < ${lines[(Ie)/opt/homebrew/bin]} )) || { print -l -- $lines; return 2; }
    # uv wins: no pyenv directories.
    print '#!/bin/sh' > "$TEST_ROOT/root/opt/homebrew/bin/uv"; chmod +x "$TEST_ROOT/root/opt/homebrew/bin/uv"
    ms_run _ms_fs_root=$_ms_fs_root -c 'print -l $path' || return 3
    [[ $(<"$TEST_ROOT/out") != *'/.pyenv/'* ]] || { cat "$TEST_ROOT/out"; return 4; }
  }
  It 'puts pyenv shims in the manager tier unless uv is available'
    When run pyenv_case
    The status should be success
  End
End

Describe 'version-manager hooks (interactive)'
  hook_fixture() {
    ms_fixture_full
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    local tool
    for tool in zoxide starship atuin herdr cwf; do printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/$tool"; chmod +x "$TEST_ROOT/bin/$tool"; done
    mkdir -p "$HOME/project" "$HOME/bad-project" "$HOME/gomod"
  }
  nvm_hook_case() {
    emulate -L zsh
    hook_fixture
    mkdir -p "$HOME/.nvm"
    print v22 > "$HOME/project/.nvmrc"
    print bad > "$HOME/bad-project/.nvmrc"
    cat > "$HOME/.nvm/nvm.sh" <<'DATA'
nvm_find_nvmrc() { [[ ! -f .nvmrc ]] || print -r -- "$PWD/.nvmrc"; }
nvm() {
  case $1 in
    version)
      if [[ -z $2 ]]; then print -r -- "${NVM_CURRENT:-v20}"
      elif [[ $2 == default ]]; then print v20
      elif [[ $2 == $NVM_CURRENT ]]; then print -r -- "$2"
      else print N/A; fi;;
    install)
      if [[ $(<.nvmrc) == bad ]]; then path=( /broken ); return 7; fi
      NVM_CURRENT=v22; print nvm-install >> "$OPLOG";;
    use) NVM_CURRENT=v20; print nvm-default >> "$OPLOG";;
  esac
}
DATA
    local script='cd "$HOME/project"; [[ $NVM_CURRENT == v22 ]] || exit 21; cd "$HOME"; [[ $NVM_CURRENT == v20 ]] || exit 22; saved_path=$PATH; cd "$HOME/bad-project"; [[ $PATH == $saved_path ]] || exit 23; print READY'
    ms_pty -dic "$script" || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *READY* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'switches node from .nvmrc on cd and restores PATH when the switch fails'
    When run nvm_hook_case
    The status should be success
  End
  gvm_hook_case() {
    emulate -L zsh
    hook_fixture
    mkdir -p "$HOME/.gvm/scripts" "$HOME/.gvm/gos/go1.26/bin" "$HOME/.gvm/gos/go1.27/bin"
    printf '#!/bin/sh\n' > "$HOME/.gvm/gos/go1.26/bin/go"; cp "$HOME/.gvm/gos/go1.26/bin/go" "$HOME/.gvm/gos/go1.27/bin/go"
    chmod +x "$HOME/.gvm/gos/go1.26/bin/go" "$HOME/.gvm/gos/go1.27/bin/go"
    cat > "$HOME/.gvm/scripts/gvm" <<'DATA'
export GVM_VERSION=stub
gvm() {
  case $1 in
    list) print '   go1.26'; print '=> go1.27' ;;
    use) print "gvm $*" >> "$OPLOG" ;;
  esac
  return 0
}
DATA
    print 'go 1.26' > "$HOME/gomod/go.mod"
    # Startup activates the newest Go once; entering a go.mod directory switches to its version.
    ms_pty -dic 'cd "$HOME/gomod"; print READY' || return 1
    [[ $(<"$TEST_ROOT/out") == *READY* ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(grep -c '^gvm use go1.27$' "$OPLOG") == 1 && $(grep -c '^gvm use go1.26$' "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 3; }
    [[ ! -e $HOME/.gvm/environments/default ]]
  }
  It 'switches Go from go.mod on cd after activating gvm once without --default'
    When run gvm_hook_case
    The status should be success
  End
End
