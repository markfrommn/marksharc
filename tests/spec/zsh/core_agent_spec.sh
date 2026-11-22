Describe 'agent and batch sessions on the real tree'
  # The whole tree (core and modules) is copied, with a realistic
  # gvm, Go and Homebrew layout in the temporary HOME. Agent and batch shells must
  # not print, source gvm, run go or rewrite ~/.gvm.
  real_tree_fixture() {
    ms_fixture_full
    mkdir -p "$HOME/.gvm/scripts" "$HOME/.gvm/gos/go1.26/bin" "$HOME/.gvm/environments"
    cat > "$HOME/.gvm/scripts/gvm" <<'DATA'
print GVM_SOURCED >> "$OPLOG"
export GVM_VERSION=stub
gvm() {
  case $1 in
    list) print '   go1.26' ;;
    use) print "Now using version $2"; print "gvm $*" >> "$OPLOG"; [[ $* == *--default* ]] && print default > "$HOME/.gvm/environments/default" ;;
  esac
  return 0
}
DATA
    printf '#!/bin/sh\necho "go $*" >> "$OPLOG"\necho "$HOME/go"\n' > "$HOME/.gvm/gos/go1.26/bin/go"
    printf '#!/bin/sh\necho "go $*" >> "$OPLOG"\necho "$HOME/go"\n' > "$TEST_ROOT/bin/go"
    chmod +x "$HOME/.gvm/gos/go1.26/bin/go" "$TEST_ROOT/bin/go"
    mkdir -p "$HOME/go/bin" "$HOME/bin"
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    # Homebrew's real tools are on the rebuilt PATH; keep them out of the example.
    local tool
    for tool in starship atuin zoxide; do
      printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/$tool"
      chmod +x "$TEST_ROOT/bin/$tool"
    done
  }
  quiet_agent_case() {
    emulate -L zsh
    real_tree_fixture
    local flags marker
    for marker in CLAUDECODE=1 CODEX_SANDBOX=seatbelt NONE=; do
      for flags in -c -lc; do
        : > "$OPLOG"
        ms_run MARKSHARC_MODULE_GUARD=1 $marker $flags 'print SESSION=$MARKSHARC_SESSION' || return 1
        [[ $(<"$TEST_ROOT/out") == SESSION=(agent|batch) && ! -s $TEST_ROOT/err ]] || { print -r -- "$marker $flags OUT=$(<$TEST_ROOT/out) ERR=$(<$TEST_ROOT/err)"; return 2; }
        [[ ! -s $OPLOG ]] || { print -r -- "$marker $flags OPLOG:"; cat "$OPLOG"; return 3; }
      done
    done
    [[ ! -e $HOME/.gvm/environments/default ]] || return 4
    # The agent PATH still carries the user and Go directories.
    ms_run CLAUDECODE=1 -c 'print -r -- $PATH' || return 5
    [[ $(<"$TEST_ROOT/out") == *"$HOME/go/bin"* && $(<"$TEST_ROOT/out") == *"$HOME/bin"* ]] || { cat "$TEST_ROOT/out"; return 6; }
  }
  It 'prints nothing and runs no gvm or go in agent or batch -c and -lc'
    When run quiet_agent_case
    The status should be success
  End
  quiet_rebuild_case() {
    emulate -L zsh
    real_tree_fixture
    ms_run MARKSHARC_MODULE_GUARD=1 MARKSHARC_ENV=stale CLAUDECODE=1 -c 'print SESSION=$MARKSHARC_SESSION' || return 1
    [[ $(<"$TEST_ROOT/out") == SESSION=agent && ! -s $TEST_ROOT/err && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err" "$OPLOG"; return 2; }
  }
  It 'stays quiet when an env mismatch forces a rebuild'
    When run quiet_rebuild_case
    The status should be success
  End
  interactive_gvm_case() {
    emulate -L zsh
    real_tree_fixture
    # Startup names the selected Go without sourcing gvm or running go.
    ms_pty -dic 'print READY $gvm_go_name' || return 1
    [[ $(<"$TEST_ROOT/out") == 'READY go1.26' ]] || { print -r -- "OUT=[$(<$TEST_ROOT/out)]"; return 2; }
    ! grep -Eq '^(GVM_SOURCED|gvm |go )' "$OPLOG" || { cat "$OPLOG"; return 3; }
    # The first gvm call sources it once, quietly; the selected Go needs no gvm use.
    ms_pty -dic 'gvm list >/dev/null; gvm list >/dev/null; print READY' || return 4
    [[ $(<"$TEST_ROOT/out") == READY ]] || { print -r -- "OUT=[$(<$TEST_ROOT/out)]"; return 5; }
    [[ $(grep -c '^GVM_SOURCED$' "$OPLOG") == 1 && $(grep -c '^gvm use' "$OPLOG") == 0 ]] || { cat "$OPLOG"; return 6; }
    [[ ! -e $HOME/.gvm/environments/default ]] || return 7
  }
  It 'loads gvm once on first use in an interactive shell, without output and without --default'
    When run interactive_gvm_case
    The status should be success
  End
  gvm_go_case() {
    emulate -L zsh
    real_tree_fixture
    local v
    for v in go1.9 go1.27.4 go1.27.10; do
      mkdir -p "$HOME/.gvm/gos/$v/bin" "$HOME/.gvm/pkgsets/$v/global/bin"
      printf '#!/bin/sh\necho "go $*" >> "$OPLOG"\n' > "$HOME/.gvm/gos/$v/bin/go"
      chmod +x "$HOME/.gvm/gos/$v/bin/go"
    done
    # A go earlier in an inherited, unmanaged directory stays ahead of the manager tier
    # (virtualenv-style activations); the fixture's own stub must not be that directory.
    rm -f "$TEST_ROOT/bin/go"
    # Forks that the old activation used must not run: any call logs and fails.
    local tool
    for tool in ls sort tail awk; do
      printf '#!/bin/sh\necho "FORBIDDEN %s" >> "$OPLOG"\nexit 99\n' "$tool" > "$TEST_ROOT/bin/$tool"
      chmod +x "$TEST_ROOT/bin/$tool"
    done
    local flags marker
    for marker in CLAUDECODE=1 NONE=; do
      for flags in -c -lc; do
        : > "$OPLOG"
        ms_run MARKSHARC_MODULE_GUARD=1 $marker $flags 'print -r -- "$(whence -p go)"; print -r -- $PATH' || return 1
        local -a lines=( "${(@f)$(<"$TEST_ROOT/out")}" )
        [[ $lines[1] == "$HOME/.gvm/gos/go1.27.10/bin/go" && ! -s $TEST_ROOT/err ]] || { print -r -- "$marker $flags OUT=$(<$TEST_ROOT/out) ERR=$(<$TEST_ROOT/err)"; return 2; }
        # The pkgset bin comes first, then the Go bin, as gvm's own activation orders them.
        [[ $lines[2] == "$HOME/.gvm/pkgsets/go1.27.10/global/bin:$HOME/.gvm/gos/go1.27.10/bin:"* || $lines[2] == *":$HOME/.gvm/pkgsets/go1.27.10/global/bin:$HOME/.gvm/gos/go1.27.10/bin:"* ]] || { print -r -- "PATH=$lines[2]"; return 3; }
        [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 4; }
      done
    done
    # The gvm default environment names the Go to use.
    printf 'export gvm_go_name=go1.27.4\nexport GOROOT=/x\n' > "$HOME/.gvm/environments/default"
    ms_run MARKSHARC_MODULE_GUARD=1 CLAUDECODE=1 -c 'print -r -- "$(whence -p go)"' || return 5
    [[ $(<"$TEST_ROOT/out") == "$HOME/.gvm/gos/go1.27.4/bin/go" && ! -s $TEST_ROOT/err && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err" "$OPLOG"; return 6; }
  }
  It 'puts the default or newest gvm Go on the PATH of agent and batch shells without forking'
    When run gvm_go_case
    The status should be success
  End
End
