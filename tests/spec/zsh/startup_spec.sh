Describe 'startup eligibility and reload'
  # The whole zsh tree is copied so fixtures can wrap build_path and stub Homebrew
  # without touching the repository; the stub in $HOME/.zshenv links to the copy.
  startup_fixture() {
    ms_fixture_full
    cat >> "$MS_HOME/modules/path/env.zsh" <<'DATA'
functions[_fixture_original_path_build]=$functions[_ms_path_build]
_ms_path_build() { print BUILD >> "$OPLOG"; _fixture_original_path_build "$@"; }
DATA
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    startup_tools
    print 'print COMPINIT >> "$OPLOG"' > "$TEST_ROOT/fpath/compinit"
  }
  startup_tools() {
    local tool
    for tool in zoxide starship atuin; do
      if [[ $tool == starship ]]; then
        cat > "$TEST_ROOT/bin/$tool" <<'DATA'
#!/bin/sh
printf '%s\n' 'starship_precmd() { :; }'
printf 'print starship >> "$OPLOG"\n'
DATA
      else
        cat > "$TEST_ROOT/bin/$tool" <<'DATA'
#!/bin/sh
printf 'print %s >> "$OPLOG"\n' "$(basename "$0")"
DATA
      fi
      chmod +x "$TEST_ROOT/bin/$tool"
    done
    printf '#!/bin/sh\nprintf "FORBIDDEN git %%s\\n" "$*" >> "$OPLOG"\nexit 99\n' > "$TEST_ROOT/bin/git"
    printf '#!/bin/sh\necho fortune >> "$OPLOG"\n' > "$TEST_ROOT/bin/fortune"
    printf '#!/bin/sh\nexit 1\n' > "$TEST_ROOT/bin/go"
    chmod +x "$TEST_ROOT/bin/git" "$TEST_ROOT/bin/fortune" "$TEST_ROOT/bin/go"
    cat > "$TEST_ROOT/bin/herdr" <<'DATA'
#!/bin/sh
case "$*" in
  'session list') echo 'NAME STATE PID SOCKET';;
  'completion zsh') echo HERDR_COMPLETION >> "$OPLOG";;
  *) echo FORBIDDEN >> "$OPLOG"; exit 99;;
esac
DATA
    cat > "$TEST_ROOT/bin/cwf" <<'DATA'
#!/bin/sh
case "$*" in
  'shell zsh') echo CWF_INIT >> "$OPLOG";;
  'session name') exit 1;;
  *) echo FORBIDDEN >> "$OPLOG"; exit 99;;
esac
DATA
    chmod +x "$TEST_ROOT/bin/herdr" "$TEST_ROOT/bin/cwf"
    # envman stays with the private overlay (mark-tools); no portable module loads it.
    # The cdt directory is the synthesized tooling checkout the cwf module reads.
    mkdir -p "$TEST_ROOT/fpath" "$TEST_ROOT/cdt"
  }
  startup_case() {
    emulate -L zsh
    local fixture_mode=$1
    startup_fixture
    if [[ $fixture_mode == node ]]; then
      mkdir -p "$HOME/.nvm" "$HOME/project" "$HOME/bad-project"
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
    fi
    if [[ $fixture_mode == pyenv ]]; then
      print 'have_command() { [[ $1 != uv ]] && command -v "$1" >/dev/null 2>&1; }' >> "$MS_HOME/core/zsh/lib/util.zsh"
      mkdir -p "$HOME/.pyenv/bin"
      cat > "$HOME/.pyenv/bin/pyenv" <<'DATA'
#!/bin/sh
if [ "$1" = init ]; then echo PYENV_INIT >> "$OPLOG"; echo ':'; fi
DATA
      chmod +x "$HOME/.pyenv/bin/pyenv"
    fi
    local script='set -- original; if (( ${+aliases[cs]} )); then eval cs; eval li; eval cs; eval li; fi; [[ $1 == original ]] || exit 12; (( ${+functions[have_command]} )) || exit 13; print READY'
    if [[ $fixture_mode == node ]]; then
      script+='; cd "$HOME/project"; [[ $NVM_CURRENT == v22 ]] || exit 21; cd "$HOME"; [[ $NVM_CURRENT == v20 ]] || exit 22; saved_path=$PATH; cd "$HOME/bad-project"; [[ $PATH == $saved_path ]] || exit 23'
    fi
    if [[ $fixture_mode == (tty|tty-login|node|pyenv) ]]; then
      script+='; [[ -z ${ZSH-} && -z ${ZSH_THEME-} && -z ${ZSH_DISABLE_COMPFIX-} ]] || exit 24'
      script+='; [[ -z ${OPS1-} && -z ${VCPS1-} ]] || exit 25'
      script+='; (( ${+functions[p10k]} == 0 && ${+functions[vcs_info]} == 0 )) || exit 26'
      script+='; (( ${+functions[starship_precmd]} == 1 )) || exit 27'
      script+='; [[ $MARKSHARC_SESSION == interactive ]] || exit 28'
    fi
    # The cwf module runs cwf shell zsh once per shell when the tooling checkout
    # is known; the fixture synthesizes one (COMMON_DEV_TOOLS is the documented,
    # portable contract — the private overlay's discovery of it stays behind).
    local -a extra=( FPATH="$TEST_ROOT/fpath:$FPATH" COMMON_DEV_TOOLS="$TEST_ROOT/cdt" )
    case $fixture_mode in
      command-tty) ms_pty "${extra[@]}" -dlc "$script" ;;
      tty-login) ms_pty "${extra[@]}" -dlic "$script" ;;
      command) ms_run "${extra[@]}" -dc "$script" ;;
      tty|node|pyenv) ms_pty "${extra[@]}" -dic "$script" ;;
      suppressed|vscode|nonce|claude|opencode|kilo)
        case $fixture_mode in
          vscode) extra+=( VSCODE_INJECTION=fixture );;
          nonce) extra+=( VSCODE_NONCE=fixture );;
          claude) extra+=( CLAUDECODE=1 );;
          opencode) extra+=( OPENCODE=fixture );;
          kilo) extra+=( KILO_CLI_MODE=fixture );;
          suppressed) extra+=( CODEX_SESSION_ID=fixture );;
        esac
        ms_pty "${extra[@]}" -dlic "$script" ;;
      *) ms_run "${extra[@]}" -dlic "$script" ;;
    esac
    local out
    if [[ $fixture_mode == (command|headless) ]]; then out=$(<"$TEST_ROOT/out")$(<"$TEST_ROOT/err"); else out=$(<"$TEST_ROOT/out"); fi
    [[ $out == *READY* ]] || { print -r -- "$out"; return 1; }
    [[ $(<"$OPLOG") != *FORBIDDEN* ]] || { cat "$OPLOG"; return 2; }
    if [[ $fixture_mode == (tty|tty-login|node|pyenv) ]]; then
      local event
      # ENVMAN stays with the private overlay; the herdr and cwf events come from
      # the portable modules against the synthesized stubs and tooling checkout.
      for event in COMPINIT HERDR_COMPLETION CWF_INIT; do
        [[ $(grep -c "^$event\$" "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 7; }
      done
      [[ $fixture_mode != pyenv || $(grep -c '^PYENV_INIT$' "$OPLOG") == 2 ]] || return 8
      # One env build at startup plus one forced rebuild per cs/li; tool init runs once
      # per shell, never on reload, and the fortune greeting is opt-in.
      [[ $(grep -c '^BUILD$' "$OPLOG") == 5 && $(grep -c '^atuin$' "$OPLOG") == 1 && $(grep -c '^fortune$' "$OPLOG") == 0 ]] || { cat "$OPLOG"; cat "$TEST_ROOT/out"; return 3; }
      # cs and li trace to stderr, which the PTY merges into the output.
      [[ $out == *'marksharc: env phase: start'* ]] || return 9
    else
      [[ $(<"$OPLOG") == BUILD ]] || { cat "$OPLOG"; return 4; }
    fi
  }
  Describe modes
    Parameters:value tty tty-login command command-tty node pyenv suppressed vscode nonce claude opencode kilo headless
    It "keeps $1 startup/reload free of maintenance and repeats"
      When run startup_case "$1"
      The status should be success
    End
  End
  no_overlay_case() {
    emulate -L zsh
    local mode=$1 script='
      if [[ $MARKSHARC_SESSION == interactive ]]; then
        source "$MARKSHARC_HOME/core/zsh/reload.zsh" >/dev/null 2>&1
        source "$MARKSHARC_HOME/core/zsh/reload.zsh" >/dev/null 2>&1
        local -a unique_hooks=( "${(@u)chpwd_functions}" )
        (( $#unique_hooks == $#chpwd_functions )) || exit 31
        local -a unique_path=( "${(@u)path}" )
        (( $#unique_path == $#path )) || exit 32
      fi
      print READY'
    startup_fixture
    rm -rf "$XDG_CONFIG_HOME/marksharc"
    local -a extra=( FPATH="$TEST_ROOT/fpath:$FPATH" )
    case $mode in
      batch) ms_run "${extra[@]}" -dc "$script" ;;
      login) ms_run "${extra[@]}" -dlc "$script" ;;
      agent) ms_pty "${extra[@]}" CODEX_SESSION_ID=fixture -dic "$script" ;;
      interactive) ms_pty "${extra[@]}" -dic "$script" ;;
    esac || return 1
    [[ $(<"$TEST_ROOT/out") == READY && ! -s $TEST_ROOT/err && $(<"$OPLOG") != *FORBIDDEN* ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err" "$OPLOG"; return 2; }
  }
  Describe 'without an overlay'
    Parameters:value batch login agent interactive
    It "starts quietly and reloads without duplicates: $1"
      When run no_overlay_case "$1"
      The status should be success
    End
  End
  quiet_case() {
    emulate -L zsh
    startup_fixture
    ms_pty FPATH="$TEST_ROOT/fpath:$FPATH" -dic 'print READY' || return 1
    [[ $(<"$TEST_ROOT/out") == READY ]] || { print -r -- "OUT=[$(<"$TEST_ROOT/out")]"; return 2; }
    ms_pty FPATH="$TEST_ROOT/fpath:$FPATH" -dlic 'print READY' || return 3
    [[ $(<"$TEST_ROOT/out") == READY ]] || { print -r -- "OUT=[$(<"$TEST_ROOT/out")]"; return 4; }
    ms_pty FPATH="$TEST_ROOT/fpath:$FPATH" MARKSHARC_VERBOSE=1 -dic 'print READY' || return 5
    [[ $(<"$TEST_ROOT/out") == *'marksharc: module pager: init.zsh'* && $(<"$TEST_ROOT/out") == *'marksharc: module path: env.zsh'* && $(<"$TEST_ROOT/out") == *READY* ]]
  }
  It 'prints nothing at interactive startup unless verbose'
    When run quiet_case
    The status should be success
  End
  insecure_fpath_case() {
    emulate -L zsh
    ms_fixture_full
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    startup_tools
    # A world-writable completions directory fails compaudit's audit (a
    # world-writable site-functions directory ships on some CI images).
    # compinit -i excludes it silently; a prompting compinit hangs the PTY here.
    ms_mod zz-insecure module.conf 'describe "insecure completions fixture"'
    mkdir -p "$MS_HOME/modules/zz-insecure/completions/zsh"
    chmod 777 "$MS_HOME/modules/zz-insecure/completions/zsh"
    ms_pty -dic 'print READY' || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *READY* && $(<"$TEST_ROOT/out") != *insecure* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'initialises completion silently when an fpath directory fails the security audit'
    When run insecure_fpath_case
    The status should be success
  End
  greeting_case() {
    emulate -L zsh
    startup_fixture
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'set greeting.fortune on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_pty FPATH="$TEST_ROOT/fpath:$FPATH" -dic 'eval cs; print READY' || return 1
    [[ $(grep -c '^fortune$' "$OPLOG") == 1 ]]
  }
  It 'runs the greeting once when the greeting.fortune option is on'
    When run greeting_case
    The status should be success
  End
  offline_startup_case() {
    emulate -L zsh
    local sha=24105b15714bfec37989ed5c5b6e60f572253019
    startup_fixture
    # The registry is the module's own modules/completion-fzf-tab/zsh.plugins,
    # copied into the fixture tree by ms_fixture_full.
    # The compinit stub records its arguments and whether the old dump was
    # removed before initialization ran.
    cat > "$TEST_ROOT/fpath/compinit" <<'DATA'
print "compinit $*" >> "$OPLOG"
if [ -e "${@[-1]}" ]; then
  print DUMP_PRESENT >> "$OPLOG"
else
  print DUMP_ABSENT >> "$OPLOG"
fi
DATA
    # Fake an already-cloned pinned fzf-tab; there is no $HOME/.oh-my-zsh.
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$sha"
    mkdir -p "$root"
    print 'print FZF_TAB >> "$OPLOG"' > "$root/fzf-tab.plugin.zsh"
    # Precreate a stale dump and a mismatched fpath fingerprint.
    local host=${$(hostname)%%.*}
    local cache="$XDG_CACHE_HOME/marksharc/$host"
    mkdir -p "$cache"
    print stale > "$cache/zcompdump"
    print /nonexistent/fpath > "$cache/zcompdump.fpath"
    local script='if (( ${+aliases[cs]} )); then eval cs; eval li; eval cs; eval li; fi'
    script+='; [[ -z ${ZSH-} && -z ${ZSH_THEME-} && -z ${ZSH_DISABLE_COMPFIX-} ]] || exit 24'
    script+='; [[ -z ${OPS1-} && -z ${VCPS1-} ]] || exit 25'
    script+='; (( ${+functions[p10k]} == 0 && ${+functions[vcs_info]} == 0 )) || exit 26'
    script+='; (( ${+functions[starship_precmd]} == 1 )) || exit 27; print READY'
    ms_pty FPATH="$TEST_ROOT/fpath:$FPATH" -dic "$script" || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *READY* ]] || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$OPLOG") != *FORBIDDEN* ]] || { cat "$OPLOG"; return 2; }
    [[ $(grep -c '^FZF_TAB$' "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 3; }
    [[ $(grep -c '^DUMP_ABSENT$' "$OPLOG") == 1 && $(<"$OPLOG") != *DUMP_PRESENT* ]] || { cat "$OPLOG"; return 4; }
    [[ $(grep -c "^compinit -i -d $cache/zcompdump\$" "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 5; }
    [[ $(<"$OPLOG") != *'compinit -C'* && $(<"$OPLOG") != *'compinit -D'* && $(<"$OPLOG") != *'compinit -u'* ]] || { cat "$OPLOG"; return 6; }
    [[ ! -e $cache/zcompdump && -s $cache/zcompdump.fpath && $(<"$cache/zcompdump.fpath") != /nonexistent/fpath ]] || return 7
    local -a zcompdumps=( "$MS_HOME"/.zcompdump*(N) "$MS_HOME"/core/.zcompdump*(N) )
    [[ ${#zcompdumps} == 0 ]] || return 8
  }
  It 'starts offline with a pinned plugin clone and cached native completion'
    When run offline_startup_case
    The status should be success
  End
  cached_init_case() {
    emulate -L zsh
    startup_fixture
    ms_pty FPATH="$TEST_ROOT/fpath:$FPATH" -dic 'print READY' || return 1
    [[ $(grep -c '^starship$' "$OPLOG") == 1 && $(grep -c '^atuin$' "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 2; }
    local -a cached=( "$XDG_CACHE_HOME"/marksharc/*/init/*(N) )
    (( ${#cached} >= 3 )) || { print -l -- $cached; return 3; }
    # Later shells source the cached text: the sourced text still logs once, and
    # the tool binaries are not executed again (they would also log nothing new).
    : > "$OPLOG"
    ms_pty FPATH="$TEST_ROOT/fpath:$FPATH" -dic 'print READY' || return 4
    [[ $(grep -c '^starship$' "$OPLOG") == 1 && $(grep -c '^atuin$' "$OPLOG") == 1 && $(<"$OPLOG") != *FORBIDDEN* ]] || { cat "$OPLOG"; return 5; }
  }
  It 'sources cached tool init in later shells'
    When run cached_init_case
    The status should be success
  End
  maintenance_case() {
    emulate -L zsh
    export TMPDIR="$TEST_ROOT/tmp"
    mkdir "$TMPDIR"
    mktemp() { [[ $1 == -d ]] && command mktemp -d "$TEST_ROOT/krew.XXXXXX" || command mktemp "$TEST_ROOT/install.XXXXXX"; }
    local before=$PWD helper
    curl() { return 42; }
    load_mfn go-gvm
    for helper in install-gvm install-wezterm-terminfo install-krew; do
      case $helper in
        install-wezterm-terminfo) load_mfn wezterm "$helper";;
        install-krew) load_mfn cloud "$helper";;
      esac
      "$helper" > "$TEST_ROOT/out" 2>&1
      [[ $? == 42 && $PWD == $before ]] || return 1
    done
    local -a leftovers=( "$TEST_ROOT"/krew.*(ND) "$TEST_ROOT"/install.*(ND) )
    [[ $#leftovers == 0 ]]
  }
  It 'propagates explicit installer failures and removes temporary artifacts'
    When run maintenance_case
    The status should be success
  End
End
