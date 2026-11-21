Describe 'core env phase, host facts, ZDOTDIR and MARKSHARC_ENV'
  facts_case() {
    emulate -L zsh
    ms_fixture
    local tool
    for tool in uname hostname awk; do
      printf '#!/bin/sh\necho "FORBIDDEN %s" >> "$OPLOG"\nexit 99\n' "$tool" > "$TEST_ROOT/bin/$tool"
      chmod +x "$TEST_ROOT/bin/$tool"
    done
    ms_run -c 'print -r -- "$MARKSHARC_OS|$MARKSHARC_ARCH|$MARKSHARC_HOST|$ostype|$hwtype|$shorthost|$hostbase|$hname|$idcmd|$uid|$gid"' || return 1
    [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 2; }
    local os=${$(/usr/bin/uname -s):l} arch=$(/usr/bin/uname -m) host=$(/bin/hostname | /usr/bin/awk -F. '{print $1}')
    local base=$(print -r -- "$host" | /usr/bin/awk -F- '{print $1}') kernel=$(/usr/bin/uname -s)
    local expect="$os|$arch|$host|$kernel|$arch|$host|$base|$(/bin/hostname)|/usr/bin/id|$(/usr/bin/id -u)|$(/usr/bin/id -g)"
    [[ $(<"$TEST_ROOT/out") == "$expect" ]] || { print -r -- "GOT=$(<$TEST_ROOT/out)"; print -r -- "WANT=$expect"; return 3; }
    [[ ! -s $TEST_ROOT/err ]]
  }
  It 'computes host facts with builtins only and keeps today'\''s compatibility values'
    When run facts_case
    The status should be success
  End
  dname_case() {
    emulate -L zsh
    ms_fixture
    ms_run -c 'print -r -- "$dname"' || return 1
    local want dncommand
    dncommand=$(command -v domainname) && want=$($dncommand)
    if [[ -z $want || $want == "(none)" ]]; then want=$(egrep /etc/resolv.conf -e "^(search|domain)" | head -1 | /usr/bin/awk '{ print $2}'); fi
    [[ $(<"$TEST_ROOT/out") == "$want" ]]
  }
  It 'derives dname like the old forking code on this host'
    When run dname_case
    The status should be success
  End
  fake_root_case() {
    emulate -L zsh
    ms_fixture
    local fake="$TEST_ROOT/fake" _ms_fs_root
    _ms_fs_root=$fake
    mkdir -p "$fake/etc" "$fake/proc/sys/kernel"
    source "$MS_HOME/core/zsh/lib/facts.zsh"
    local OSTYPE=linux-gnu CPUTYPE=aarch64 HOST=box-one.example.test
    _ms_facts
    [[ $MARKSHARC_OS == linux && $MARKSHARC_ARCH == aarch64 && $MARKSHARC_HOST == box-one && $ostype == Linux && $hwtype == aarch64 && $shorthost == box-one && $hostbase == box && $statfmtarg == -c ]] || return 1
    [[ $distro == unknown && $MARKSHARC_DISTRO == unknown && -z $dname ]] || return 2
    print -r -- "ID=Ubuntu" > "$fake/etc/os-release"
    print -r -- "NAME=x" > "$fake/etc/os-release"; print -r -- "ID=ubuntu" >> "$fake/etc/os-release"
    print -r -- "(none)" > "$fake/proc/sys/kernel/domainname"
    printf "nameserver 1.1.1.1\nsearch lab.example.test other.test\ndomain later.test\n" > "$fake/etc/resolv.conf"
    _ms_facts
    [[ $distro == ubuntu && $MARKSHARC_DISTRO == ubuntu && $dname == lab.example.test ]] || { print -r -- "distro=$distro dname=$dname"; return 3; }
    print -r -- "nis.example.test" > "$fake/proc/sys/kernel/domainname"
    _ms_facts
    [[ $dname == nis.example.test ]] || return 4
    touch "$fake/etc/redhat-release"
    mkdir -p "$fake/opt/psa"
    _ms_facts
    [[ $distro == redhat && $dname == nis.example.test ]] || return 5
    OSTYPE=darwin25.0 CPUTYPE=arm64
    unset distro
    _ms_facts
    [[ $MARKSHARC_OS == darwin && $ostype == Darwin && $statfmtarg == -f && $MARKSHARC_DISTRO == macos && ${+distro} == 0 ]]
  }
  It 'maps OSTYPE, CPUTYPE, HOST, distro files and domain sources without forking'
    When run fake_root_case
    The status should be success
  End
  site_override_case() {
    emulate -L zsh
    # The portable core holds no site names; a private overlay module may set them.
    ms_fixture_full
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/site-demo"
    print 'describe "site demo"' > "$XDG_CONFIG_HOME/marksharc/modules/site-demo/module.conf"
    print 'dname=demo-site' > "$XDG_CONFIG_HOME/marksharc/modules/site-demo/env.zsh"
    ms_run -c 'print -r -- "$dname"' || return 1
    [[ $(<"$TEST_ROOT/out") == demo-site ]]
  }
  It 'lets a private overlay module own the site name, not the core'
    When run site_override_case
    The status should be success
  End
  compat_export_case() {
    emulate -L zsh
    ms_fixture
    ms_run -c 'print -r -- "${(t)ostype} ${(t)hwtype} ${(t)shorthost} ${(t)dname} ${(t)MARKSHARC_OS} ${(t)MARKSHARC_HOST} ${(t)zdir}"' || return 1
    [[ $(<"$TEST_ROOT/out") != *export* && $(<"$TEST_ROOT/out") == scalar* ]]
  }
  It 'keeps compatibility variables and host facts out of the environment'
    When run compat_export_case
    The status should be success
  End
  exports_case() {
    emulate -L zsh
    ms_fixture
    ms_run -c 'print -r -- "${(t)MARKSHARC_HOME} ${(t)MARKSHARC_ENV} ${(t)PATH} ${MARKSHARC_HOME}"' || return 1
    [[ $(<"$TEST_ROOT/out") == "scalar-export scalar-export scalar-tied-export-special $MS_HOME" ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'exports MARKSHARC_HOME, MARKSHARC_ENV and PATH'
    When run exports_case
    The status should be success
  End
  global_compinit_case() {
    emulate -L zsh
    ms_fixture
    # Debian/Ubuntu's global zshrc runs its own compinit unless the user zshenv set
    # skip_global_compinit; the completion module owns compinit (spec 6.9). The
    # suppression must hold in every mode, stay shell-local, silent, and leave the
    # session class alone.
    local flags
    for flags in -c -ic -lc; do
      ms_run $flags 'print -r -- "S=$MARKSHARC_SESSION ${(t)skip_global_compinit}:$skip_global_compinit"' || return 1
      [[ $(<"$TEST_ROOT/out") == 'S=batch scalar:1' && ! -s $TEST_ROOT/err ]] || { print -r -- "$flags OUT=$(<$TEST_ROOT/out) ERR=$(<$TEST_ROOT/err)"; return 2; }
    done
    ms_run CLAUDECODE=1 -ic 'print -r -- "S=$MARKSHARC_SESSION ${(t)skip_global_compinit}:$skip_global_compinit"' || return 3
    [[ $(<"$TEST_ROOT/out") == 'S=agent scalar:1' && ! -s $TEST_ROOT/err ]] || { print -r -- "OUT=$(<$TEST_ROOT/out) ERR=$(<$TEST_ROOT/err)"; return 4; }
  }
  It 'suppresses the distro global compinit from the env phase in every session class'
    When run global_compinit_case
    The status should be success
  End
  zdot_case() {
    emulate -L zsh
    ms_fixture
    local zdot="$XDG_STATE_HOME/marksharc/zdot" name
    ms_run -c 'print -r -- "$ZDOTDIR"' || return 1
    [[ ! -e $zdot ]] || return 2
    ms_run -ic 'print -r -- "$ZDOTDIR ${(t)ZDOTDIR}"' || return 3
    [[ $(<"$TEST_ROOT/out") == "$zdot scalar" ]] || { cat "$TEST_ROOT/out"; return 4; }
    for name in .zshenv .zprofile .zshrc .zlogin; do
      [[ -f $zdot/$name && $(wc -l < "$zdot/$name") -le 3 && $(<"$zdot/$name") == *core/z* ]] || return 5
      [[ $(<"$zdot/$name") != */Users/* && $(<"$zdot/$name") != */home/* ]] || return 6
    done
    rm -f "$zdot/.zshrc"
    ms_run -ic ':' || return 7
    [[ -f $zdot/.zshrc ]] || return 8
    print -r -- stale > "$zdot/.zlogin"; print -r -- 0 > "$zdot/.version"
    ms_run -lc ':' || return 9
    [[ $(<"$zdot/.zlogin") == *core/zsh/zlogin.zsh* ]] || return 10
    # Missing XDG_STATE_HOME falls back to $HOME/.local/state.
    ms_run XDG_STATE_HOME= -ic 'print -r -- "$ZDOTDIR"' || return 11
    [[ $(<"$TEST_ROOT/out") == "$HOME/.local/state/marksharc/zdot" && -f $HOME/.local/state/marksharc/zdot/.zshrc ]]
  }
  It 'generates the state-dir ZDOTDIR only when missing or stale'
    When run zdot_case
    The status should be success
  End
  zdot_readonly_case() {
    emulate -L zsh
    ms_fixture
    [[ $(/usr/bin/id -u) != 0 ]] || return 0
    mkdir -p "$XDG_STATE_HOME"
    chmod 555 "$XDG_STATE_HOME"
    local rc=0 flags
    for flags in -lc -ic; do
      ms_run CODEX_SANDBOX=seatbelt $flags 'print -r -- "Z=[${ZDOTDIR-unset}] S=$MARKSHARC_SESSION"' || rc=1
      [[ $(<"$TEST_ROOT/out") == 'Z=[unset] S=agent' && ! -s $TEST_ROOT/err ]] || { print -r -- "$flags OUT=$(<$TEST_ROOT/out) ERR=$(<$TEST_ROOT/err)"; rc=2; }
    done
    # A state path that is a file behaves the same way.
    chmod 755 "$XDG_STATE_HOME"; rm -rf "$XDG_STATE_HOME"; : > "$XDG_STATE_HOME"
    ms_run CODEX_SANDBOX=seatbelt -lc 'print -r -- "Z=[${ZDOTDIR-unset}]"' || rc=3
    [[ $(<"$TEST_ROOT/out") == 'Z=[unset]' && ! -s $TEST_ROOT/err ]] || rc=4
    chmod 755 "$XDG_STATE_HOME" 2>/dev/null
    return $rc
  }
  It 'stays silent and leaves ZDOTDIR unset when the state directory is not writable'
    When run zdot_readonly_case
    The status should be success
  End
  norepo_case() {
    emulate -L zsh
    # The real tree, reached through a generated stub (the installer's stub is P2.4).
    print -r -- "export MARKSHARC_HOME=\"$MARKSHARC_ROOT\"
source \"\$MARKSHARC_HOME/core/zsh/zshenv.zsh\"" > "$HOME/.zshenv"
    touch "$TEST_ROOT/stamp"; sleep 1
    ms_run -c ':' || return 1
    ms_run -lic ':' || return 2
    ms_run CLAUDECODE=1 -lc ':' || return 3
    local -a touched=( ${(f)"$(find "$MARKSHARC_ROOT" -newer "$TEST_ROOT/stamp" -not -path "*/.git/*" -not -path "*/.git" 2>/dev/null)"} )
    (( $#touched == 0 )) || { print -l -- $touched; return 4; }
    [[ ! -s $TEST_ROOT/err ]]
  }
  It 'never writes into the repository tree'
    When run norepo_case
    The status should be success
  End
  umask_case() {
    emulate -L zsh
    ms_fixture
    printf '#!/bin/sh\necho ID >> "$OPLOG"\nexec /usr/bin/id "$@"\n' > "$TEST_ROOT/bin/id-stub"
    chmod +x "$TEST_ROOT/bin/id-stub"
    ms_run _ms_idcmd="$TEST_ROOT/bin/id-stub" -c 'umask' || return 1
    local want=0022
    [[ $(/usr/bin/id -u) != 0 && $(/usr/bin/id -gn) == $(/usr/bin/id -un) ]] && want=0002
    [[ $(<"$TEST_ROOT/out") == $want || $(<"$TEST_ROOT/out") == ${want#0} ]] || { cat "$TEST_ROOT/out"; return 2; }
    local first=$(wc -l < "$OPLOG")
    ms_run _ms_idcmd="$TEST_ROOT/bin/id-stub" -c 'umask' || return 3
    [[ $(wc -l < "$OPLOG") == $first ]] || return 4
    local -a cached=( "$XDG_CACHE_HOME"/marksharc/*/*(N) )
    (( $#cached >= 1 ))
  }
  It 'sets the umask from the cached group name without forking id on later shells'
    When run umask_case
    The status should be success
  End
End
