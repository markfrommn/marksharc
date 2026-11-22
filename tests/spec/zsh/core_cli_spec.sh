# The marksharc command (spec 6.2, 6.10, 6.15): bin/marksharc, core/cli/* and the
# interactive marksharc function. A framework fixture copies the real core and bin; modules
# are synthetic so the expectations stay stable.
Describe 'marksharc CLI'
  # cli_fw: the framework fixture plus an overlay directory path.
  cli_fw() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    print -r -- 0.1.0-test > "$MS_HOME/VERSION"
    OVERLAY=$XDG_CONFIG_HOME/marksharc
  }
  # cli_mods: four public modules for the list and edit specs.
  cli_mods() {
    ms_mod alpha module.conf 'describe "Alpha module"'
    ms_mod beta module.conf $'describe "Beta module"\nrequires command no-such-command-xyz'
    ms_mod gamma module.conf $'describe "Gamma module"\nrequires os plan9'
    ms_mod delta module.conf 'describe "Delta module"'
  }
  # cli [VAR=value ...] args...: run bin/marksharc hermetically; output in $TEST_ROOT/out and err.
  cli() {
    ms_env
    local -a extra=()
    while [[ $1 == [A-Za-z_]*=* ]]; do extra+=( "$1" ); shift; done
    env -i "${MS_ENV[@]}" "${extra[@]}" "$MS_HOME/bin/marksharc" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
  }
  conf() { print -r -- "$1" > "$OVERLAY/config.conf"; }

  usage_case() {
    emulate -L zsh
    cli_fw
    local args
    for args in '' help --help -h; do
      cli ${=args} || return 1
      [[ $(<"$TEST_ROOT/out") == *Usage:* && $(<"$TEST_ROOT/out") == *reload* && $(<"$TEST_ROOT/out") == *'module list'* && $(<"$TEST_ROOT/out") == *uninstall* && $(<"$TEST_ROOT/out") == *version* ]] || { cat "$TEST_ROOT/out"; return 2; }
    done
    cli bogus; [[ $? == 2 && ! -s $TEST_ROOT/out && $(<"$TEST_ROOT/err") == *"unknown command: bogus"* ]] || { cat "$TEST_ROOT/err"; return 4; }
    cli ../core/zsh/zshenv; [[ $? == 2 ]] || return 5
    cli -V || return 6
    local short=$(<"$TEST_ROOT/out")
    cli version || return 7
    [[ $short == $(<"$TEST_ROOT/out") ]]
  }
  It 'prints usage, rejects unknown commands with status 2 and maps -V to version'
    When run usage_case
    The status should be success
  End

  version_case() {
    emulate -L zsh
    cli_fw
    cli version || return 1
    [[ $(<"$TEST_ROOT/out") == 'marksharc 0.1.0-test' && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    # In a git checkout the described commit follows the version.
    "$REAL_GIT" -C "$MS_HOME" init -q
    "$REAL_GIT" -C "$MS_HOME" add -A
    "$REAL_GIT" -C "$MS_HOME" -c user.email=f@example.invalid -c user.name=Fixture commit -qm init
    cli "PATH=$PATH:${REAL_GIT:h}" version || return 3
    [[ $(<"$TEST_ROOT/out") =~ '^marksharc 0\.1\.0-test \([0-9a-f]{7,}\)$' ]] || { cat "$TEST_ROOT/out"; return 4; }
    rm "$MS_HOME/VERSION"
    cli "PATH=$PATH:${REAL_GIT:h}" version || return 5
    [[ $(<"$TEST_ROOT/out") == 'marksharc unknown ('* ]] || { cat "$TEST_ROOT/out"; return 6; }
  }
  It 'prints the VERSION file and the git description of a checkout'
    When run version_case
    The status should be success
  End

  reload_direct_case() {
    emulate -L zsh
    cli_fw
    cli reload; [[ $? == 1 ]] || return 1
    [[ ! -s $TEST_ROOT/out && $(<"$TEST_ROOT/err") == *'current shell'* && $(<"$TEST_ROOT/err") == *'interactive marksharc shell'* && ! $(<"$TEST_ROOT/err") =~ '(^|[^[:alnum:]])(cs|li)([^[:alnum:]]|$)' ]] || { cat "$TEST_ROOT/err"; return 2; }
  }
  It 'explains that reload runs inside a marksharc shell when run as a program'
    When run reload_direct_case
    The status should be success
  End

  list_case() {
    emulate -L zsh
    cli_fw; cli_mods
    mkdir -p "$OVERLAY/modules/priv"
    print -r -- 'describe "Private module"' > "$OVERLAY/modules/priv/module.conf"
    conf 'module delta off'
    cli module list || { cat "$TEST_ROOT/err"; return 1; }
    [[ ! -s $TEST_ROOT/err ]] || return 2
    local out=$(<"$TEST_ROOT/out")
    [[ $out =~ $'(^|\n)alpha +enabled +Alpha module' ]] || { print -r -- "$out"; return 3; }
    [[ $out =~ $'\nbeta +skipped +Beta module +\\(requires command no-such-command-xyz\\)' ]] || { print -r -- "$out"; return 4; }
    [[ $out =~ $'\ngamma +skipped +Gamma module +\\(requires os plan9\\)' ]] || { print -r -- "$out"; return 5; }
    [[ $out =~ $'\ndelta +disabled +Delta module' ]] || { print -r -- "$out"; return 6; }
    [[ $out =~ $'\npriv +enabled +Private module' ]] || { print -r -- "$out"; return 7; }
    # An explicit list leaves the unlisted modules disabled.
    conf $'module alpha\nmodule priv'
    cli module list || return 8
    out=$(<"$TEST_ROOT/out")
    [[ $out =~ $'(^|\n)alpha +enabled' && $out =~ $'\ndelta +disabled' && $out =~ $'\nbeta +disabled' && $out =~ $'\npriv +enabled' ]] || { print -r -- "$out"; return 9; }
    # The overlay is optional for listing.
    rm -rf "$OVERLAY"
    cli module list || return 10
    [[ $(<"$TEST_ROOT/out") =~ $'\ndelta +enabled' ]]
  }
  It 'lists modules with enabled, disabled and skipped status and the describe line'
    When run list_case
    The status should be success
  End

  roundtrip_case() {
    emulate -L zsh
    cli_fw; cli_mods
    mkdir -p "$OVERLAY"
    local original=$'# header\n# module alpha off\n# module beta off\nset alpha.x 1'
    conf $original
    cli module disable alpha || { cat "$TEST_ROOT/err"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *'marksharc reload'* ]] || return 20
    [[ $(<"$OVERLAY/config.conf") == $'# header\nmodule alpha off\n# module beta off\nset alpha.x 1' ]] || { cat "$OVERLAY/config.conf"; return 2; }
    cli module list; [[ $(<"$TEST_ROOT/out") =~ $'(^|\n)alpha +disabled' ]] || return 3
    local before=$(<"$OVERLAY/config.conf")
    cli module disable alpha || return 4
    [[ $(<"$OVERLAY/config.conf") == $before && $(<"$TEST_ROOT/out") == *'already disabled'* ]] || { cat "$TEST_ROOT/out"; return 5; }
    cli module enable alpha || { cat "$TEST_ROOT/err"; return 6; }
    [[ $(<"$OVERLAY/config.conf") == $original ]] || { cat "$OVERLAY/config.conf"; return 7; }
    cli module enable alpha || return 8
    [[ $(<"$TEST_ROOT/out") == *'already enabled'* && $(<"$OVERLAY/config.conf") == $original ]] || return 9
    # No template line to uncomment: disable appends, enable comments the line out again.
    cli module disable delta || return 10
    [[ $(<"$OVERLAY/config.conf") == $original$'\nmodule delta off' ]] || { cat "$OVERLAY/config.conf"; return 11; }
    cli module enable delta || return 12
    [[ $(<"$OVERLAY/config.conf") == $original$'\n# module delta off' ]] || { cat "$OVERLAY/config.conf"; return 13; }
    # Enabling in all-enabled mode never adds a plain module line (that would make the list explicit).
    cli module list; [[ $(<"$TEST_ROOT/out") =~ $'\ndelta +enabled' && $(<"$TEST_ROOT/out") =~ $'\nbeta +skipped' ]] || return 14
    grep -Eq '^module [a-z]+$' "$OVERLAY/config.conf" && return 15
    return 0
  }
  It 'disables and enables modules by editing config.conf, idempotently and reversibly'
    When run roundtrip_case
    The status should be success
  End

  explicit_case() {
    emulate -L zsh
    cli_fw; cli_mods
    mkdir -p "$OVERLAY"
    conf $'module alpha\nmodule beta'
    cli module disable beta || { cat "$TEST_ROOT/err"; return 1; }
    [[ $(<"$OVERLAY/config.conf") == $'module alpha\nmodule beta off' ]] || { cat "$OVERLAY/config.conf"; return 2; }
    # alpha is the last listed module: disabling it would silently enable every module.
    local before=$(<"$OVERLAY/config.conf")
    cli module disable alpha; [[ $? == 1 ]] || return 3
    [[ $(<"$TEST_ROOT/err") == *'last'* && $(<"$OVERLAY/config.conf") == $before ]] || { cat "$TEST_ROOT/err"; return 4; }
    cli module enable beta || return 5
    [[ $(<"$OVERLAY/config.conf") == $'module alpha\nmodule beta' ]] || { cat "$OVERLAY/config.conf"; return 6; }
    cli module enable delta || return 7
    [[ $(<"$OVERLAY/config.conf") == $'module alpha\nmodule beta\nmodule delta' ]] || { cat "$OVERLAY/config.conf"; return 8; }
    cli module disable beta || return 9
    [[ $(<"$OVERLAY/config.conf") == $'module alpha\nmodule beta off\nmodule delta' ]] || { cat "$OVERLAY/config.conf"; return 10; }
    cli module list; [[ $(<"$TEST_ROOT/out") =~ $'\ndelta +enabled' && $(<"$TEST_ROOT/out") =~ $'\nbeta +disabled' ]]
  }
  It 'edits an explicit module list without ever emptying it'
    When run explicit_case
    The status should be success
  End

  refusal_case() {
    emulate -L zsh
    cli_fw; cli_mods
    mkdir -p "$OVERLAY"
    conf '# module alpha off'
    local before=$(<"$OVERLAY/config.conf") name
    for name in nosuch '../alpha' 'a b' ''; do
      cli module disable "$name"; [[ $? == 1 || $? == 2 ]] || return 1
      [[ ! -s $TEST_ROOT/out && -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out"; return 2; }
    done
    cli module disable nosuch; [[ $(<"$TEST_ROOT/err") == *'unknown module: nosuch'* ]] || return 3
    [[ $(<"$OVERLAY/config.conf") == $before ]] || return 4
    cli module; [[ $? == 2 ]] || return 5
    cli module enable; [[ $? == 2 ]] || return 6
    cli module frobnicate alpha; [[ $? == 2 ]] || return 7
    # No overlay: nothing is created.
    rm -rf "$OVERLAY"
    cli module disable alpha; [[ $? == 1 && $(<"$TEST_ROOT/err") == *'no overlay'* && ! -e $OVERLAY ]] || { cat "$TEST_ROOT/err"; return 8; }
    # An overlay without a config.conf gets one.
    mkdir -p "$OVERLAY"
    cli module disable alpha || return 9
    [[ $(<"$OVERLAY/config.conf") == 'module alpha off' ]]
  }
  It 'rejects unknown names and missing overlays, and creates a missing config.conf'
    When run refusal_case
    The status should be success
  End

  host_case() {
    emulate -L zsh
    cli_fw; cli_mods
    mkdir -p "$OVERLAY/hosts"
    conf '# module alpha off'
    print -r -- 'module alpha off' > "$OVERLAY/hosts/testhost.conf"
    cli HOST=testhost module enable alpha; [[ $? == 1 ]] || return 1
    [[ $(<"$TEST_ROOT/err") == *'hosts/testhost.conf'* ]] || { cat "$TEST_ROOT/err"; return 2; }
  }
  It 'reports a module that a host file still overrides'
    When run host_case
    The status should be success
  End

  symlink_case() {
    emulate -L zsh
    cli_fw; cli_mods
    mkdir -p "$OVERLAY" "$TEST_ROOT/real"
    print -r -- '# module alpha off' > "$TEST_ROOT/real/config.conf"
    ln -s "$TEST_ROOT/real/config.conf" "$OVERLAY/config.conf"
    print -r -- keep > "$OVERLAY/notes"
    cli module disable alpha || { cat "$TEST_ROOT/err"; return 1; }
    [[ -L $OVERLAY/config.conf && $(<"$TEST_ROOT/real/config.conf") == 'module alpha off' ]] || return 2
    [[ $(<"$OVERLAY/notes") == keep && $(ls -A "$OVERLAY" | tr '\n' ' ') == 'config.conf notes ' ]]
  }
  It 'writes through a symlinked config.conf and touches nothing else'
    When run symlink_case
    The status should be success
  End
End

Describe 'marksharc function and PATH'
  fn_fw() {
    ms_fixture
    mkdir -p "$MS_HOME/bin"
    print -r -- $'#!/bin/sh\nprintf "delegated:%s\\n" "$*"' > "$MS_HOME/bin/marksharc"
    chmod +x "$MS_HOME/bin/marksharc"
    ms_mod probe module.conf 'describe "probe"'
    ms_mod probe env.zsh 'print -r -- "env rebuild=$_ms_env_rebuild reloading=$_ms_reloading" >> "$OPLOG"'
    ms_mod probe init.zsh 'print -r -- "init reloading=$_ms_reloading" >> "$OPLOG"'
  }
  function_case() {
    emulate -L zsh
    fn_fw
    ms_pty -dic 'print -r -- "FN=$+functions[marksharc]"; marksharc reload; print -r -- MID; marksharc reload --verbose; print -r -- "VERBOSE=${MARKSHARC_VERBOSE-unset}"; marksharc reload -v; marksharc reload --bogus; print -r -- "RC=$?"; marksharc module list "a b"; print -r -- END; exit' || return 1
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'FN=1'* ]] || { print -r -- "$out"; return 2; }
    # Quiet by default, traced with --verbose or -v, and the trace does not stick.
    local quiet=${${out#*FN=1}%%MID*}
    [[ $quiet != *'marksharc: env phase'* ]] || { print -r -- "$quiet"; return 3; }
    local loud=${${out#*MID}%%VERBOSE=*}
    [[ $loud == *'marksharc: env phase: start'* && $loud == *'marksharc: init phase: done'* ]] || { print -r -- "$loud"; return 4; }
    [[ $out == *'VERBOSE=unset'* ]] || { print -r -- "$out"; return 5; }
    [[ $out == *'RC=2'* && $out == *'unknown option: --bogus'* ]] || { print -r -- "$out"; return 6; }
    [[ $out == *'delegated:module list a b'* ]] || { print -r -- "$out"; return 7; }
    # start, reload, --verbose, -v: env and init ran in this shell each time.
    [[ $(<"$OPLOG") == $'env rebuild=1 reloading=0\ninit reloading=0\nenv rebuild=1 reloading=1\ninit reloading=1\nenv rebuild=1 reloading=1\ninit reloading=1\nenv rebuild=1 reloading=1\ninit reloading=1' ]] || { cat "$OPLOG"; return 8; }
  }
  It 'reloads the current shell from the function and delegates other subcommands to bin/marksharc'
    When run function_case
    The status should be success
  End

  batch_case() {
    emulate -L zsh
    fn_fw
    ms_run -c 'print -r -- "$+functions[marksharc]"' || return 1
    [[ $(<"$TEST_ROOT/out") == 0 ]] || return 2
    ms_run CLAUDECODE=1 -c 'print -r -- "$+functions[marksharc]"' || return 3
    [[ $(<"$TEST_ROOT/out") == 0 ]]
  }
  It 'defines no function in batch and agent sessions'
    When run batch_case
    The status should be success
  End

  path_case() {
    emulate -L zsh
    ms_fixture_full
    mkdir -p "$MS_HOME/bin"
    print -r -- $'#!/bin/sh\nexit 0' > "$MS_HOME/bin/marksharc"
    chmod +x "$MS_HOME/bin/marksharc"
    local flags got bin_at sys_at
    for flags in '-c' '-lc' '-ic'; do
      ms_run ${=flags} 'print -r -- "$commands[marksharc]|$path[(i)$MARKSHARC_HOME/bin]|$path[(i)/usr/bin]"' || return 1
      got=$(<"$TEST_ROOT/out"); bin_at=${${got#*|}%%|*}; sys_at=${got##*|}
      [[ ${got%%|*} == "$MS_HOME/bin/marksharc" && ! -s $TEST_ROOT/err ]] || { print -r -- "$flags: $got"; cat "$TEST_ROOT/err"; return 2; }
      (( bin_at > sys_at )) || { print -r -- "$flags: bin before system: $got"; return 3; }
    done
    ms_run CLAUDECODE=1 -c 'print -r -- "$commands[marksharc]"' || return 4
    [[ $(<"$TEST_ROOT/out") == "$MS_HOME/bin/marksharc" && ! -s $TEST_ROOT/err ]] || return 5
  }
  It 'puts bin/ on PATH after the system tier in batch, login, interactive and agent shells, quietly'
    When run path_case
    The status should be success
  End
End
