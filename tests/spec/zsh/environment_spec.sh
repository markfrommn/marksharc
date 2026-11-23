Describe 'environment discovery and PATH contracts'
  helper_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/util.zsh"
    fn_exists have_command
  }
  domain_case() {
    emulate -L zsh
    local fake="$TEST_ROOT/fake" _ms_fs_root
    _ms_fs_root=$fake
    mkdir -p "$fake/proc/sys/kernel"
    print fixture.invalid > "$fake/proc/sys/kernel/domainname"
    source "$MARKSHARC_ROOT/core/zsh/lib/facts.zsh"
    _ms_facts
    [[ ${+dname} == 0 ]]
  }
  host_fact_case() {
    emulate -L zsh
    local fake="$TEST_ROOT/fake" _ms_fs_root OSTYPE=solaris2.11 CPUTYPE=sparc HOST=fixture.example
    _ms_fs_root=$fake
    mkdir -p "$fake/proc/sys/kernel" "$fake/etc"
    print fixture.invalid > "$fake/proc/sys/kernel/domainname"
    source "$MARKSHARC_ROOT/core/zsh/lib/facts.zsh"
    _ms_facts
    [[ $MARKSHARC_ARCH == sparc && $idcmd == /usr/bin/id && ${+dname} == 0 && ${+ostype} == 0 && $MARKSHARC_OS == solaris ]]
  }
  brew_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/util.zsh"
    source "$MARKSHARC_ROOT/core/zsh/lib/cache.zsh"
    load_mfn brew
    mkdir -p "$HOME/brew space"
    printf '#!/bin/sh\nprintf "export BREW_FIXTURE=correct\\n"\n' > "$HOME/brew space/brew"
    chmod +x "$HOME/brew space/brew"
    setup-homebrew "$HOME/missing" "$HOME/brew space/brew" || return 1
    [[ $BREW_FIXTURE == correct ]]
  }
  brew_empty_case() {
    emulate -L zsh
    source "$MARKSHARC_ROOT/core/zsh/lib/util.zsh"
    source "$MARKSHARC_ROOT/core/zsh/lib/cache.zsh"
    load_mfn brew
    mkdir -p "$HOME/bw/bin"
    # Like the real brew: no output when PATH already starts with its directory.
    cat > "$HOME/bw/bin/brew" <<'DATA'
#!/bin/sh
case "$PATH" in
  "$HOME/bw/bin:"*) ;;
  *) printf 'export BREW_FIXTURE=correct\nexport PATH="%s/bw/bin:$PATH"\n' "$HOME" ;;
esac
DATA
    chmod +x "$HOME/bw/bin/brew"
    path=( "$HOME/bw/bin" /first /usr/bin /bin )
    setup-homebrew "$HOME/bw/bin/brew" || return 1
    [[ $BREW_FIXTURE == correct ]] || return 2
    local -a cached=( "$XDG_CACHE_HOME"/marksharc/*/init/*(N) )
    (( ${#cached} == 1 )) && [[ $(wc -l < "$cached[1]") -ge 2 ]] || return 3
    # PATH already starts with the brew directory, as in a shell where the env phase put
    # it first: brew prints nothing then, so the cache must be generated under a fixed PATH.
    # The user's PATH order is kept.
    [[ $path[1] == "$HOME/bw/bin" && $path[2] == /first ]] || { print -r -- "path=$path"; return 4; }
    # When PATH lacks the brew directory, it goes to the front as before.
    unset BREW_FIXTURE
    path=( /usr/bin /bin )
    setup-homebrew "$HOME/bw/bin/brew" || return 5
    [[ $BREW_FIXTURE == correct && $path[1] == "$HOME/bw/bin" ]]
  }
  It 'keeps a usable cached Brew environment when PATH already starts with the brew directory'
    When run brew_empty_case
    The status should be success
  End
  It 'executes the selected executable Brew path literally'
    When run brew_case
    The status should be success
  End
  It 'retains fn_exists after loading primitives'
    When run helper_case
    The status should be success
  End
  It 'ignores the old NIS domain fact'
    When run domain_case
    The status should be success
  End
  It 'keeps generic modern host facts without legacy normalization'
    When run host_fact_case
    The status should be success
  End
End
