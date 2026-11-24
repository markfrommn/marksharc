Describe 'bootstrap, update and installers'
  day2_fixture() {
    ms_fixture
    cd "$TEST_ROOT" || return 1
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    ms_env
  }

  brew_case() {
    day2_fixture
    ms_mod sample module.conf $'package brew alpha\npackage cask "App Name"'
    stub_command brew 'cat "$3" > "$TEST_ROOT/brewfile"'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" bootstrap > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    if [[ $OSTYPE == darwin* ]]; then platform=darwin; else platform=linux; fi
    cmp "$TEST_ROOT/brewfile" "$MARKSHARC_ROOT/tests/fixtures/day2/Brewfile.$platform"
  }
  It 'generates and runs a Brewfile from enabled package declarations'
    When run brew_case
    The status should be success
  End

  render_list_case() {
    day2_fixture
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --list > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/out") == *render* ]] || return 2
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only render > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [[ $(<"$TEST_ROOT/out") == *'render: ok'* ]]
  }
  It 'lists and selects the render step'
    When run render_list_case
    The status should be success
  End

  empty_selector_case() {
    day2_fixture
    ms_mod sample module.conf 'update test touch "$TEST_ROOT/ran"'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only '' --dry-run > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? != 0 && ! -e $TEST_ROOT/ran && ! -s $TEST_ROOT/out ]]
  }
  It 'rejects an empty update selector without executing or listing steps'
    When run empty_selector_case
    The status should be success
  End

  update_snapshot_case() {
    day2_fixture
    print -r -- 'update safe touch "$TEST_ROOT/original"' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    print -r -- $'#!/usr/bin/env zsh\nif [[ $MARKSHARC_SYNC_PART == repositories ]]; then\n  print -r -- \'update duplicate touch "$TEST_ROOT/bad-one"\' \'update duplicate touch "$TEST_ROOT/bad-two"\' > "$XDG_CONFIG_HOME/marksharc/config.conf"\nfi' > "$MS_HOME/core/cli/sync"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ -e $TEST_ROOT/original && ! -e $TEST_ROOT/bad-one && ! -e $TEST_ROOT/bad-two && $(<"$TEST_ROOT/out") == *'safe: ok'* ]]
  }
  It 'runs only the validated update snapshot when sync changes configuration'
    When run update_snapshot_case
    The status should be success
  End

  update_literal_case() {
    day2_fixture
    ms_mod sample module.conf $'update literal update-fixture "a b" "" \'$(touch never)\''
    stub_command update-fixture 'printf "<%s>\n" "$@" > "$TEST_ROOT/args"'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only literal > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/args") == $'<a b>\n<>\n<$(touch never)>' && ! -e never ]]
  }
  It 'preserves spaces, empty arguments and literal metacharacters in the snapshot'
    When run update_literal_case
    The status should be success
  End

  installer_environment_case() {
    ms_fixture_full
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    print -r -- $'#!/bin/bash\nprintf "%s|%s|%s|%s" "$GVM_NO_UPDATE_PROFILE" "$PROFILE" "$NVM_DIR" "$(test -d "$NVM_DIR" && echo exists)" > "$TEST_ROOT/installer-env"' > "$TEST_ROOT/payload"
    stub_command curl 'while [ "$1" != -o ]; do shift; done; cp "$TEST_ROOT/payload" "$2"'
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" install gvm > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/installer-env") == '1|'* ]] || return 2
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" install nvm > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [[ $(<"$TEST_ROOT/installer-env") == "|/dev/null|$HOME/.nvm|exists" ]] || return 4
    env -i "${MS_ENV[@]}" NVM_DIR="$TEST_ROOT/custom nvm" "$MS_HOME/bin/marksharc" install nvm > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 5
    [[ $(<"$TEST_ROOT/installer-env") == "|/dev/null|$TEST_ROOT/custom nvm|exists" ]]
  }
  It 'keeps profiles untouched and passes the default or custom nvm directory to installers'
    When run installer_environment_case
    The status should be success
  End

  missing_requirement_case() {
    day2_fixture
    ms_mod sample module.conf $'requires command marksharc-missing-fixture\npackage brew fixture'
    stub_command brew 'cat "$3" > "$TEST_ROOT/brewfile"'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" bootstrap > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/brewfile") == 'brew "fixture"' ]]
  }
  It 'can bootstrap the package of an enabled module whose required command is missing'
    When run missing_requirement_case
    The status should be success
  End

  ruby_interpolation_case() {
    day2_fixture
    ms_mod sample module.conf 'package brew "literal#{danger}"'
    stub_command brew 'cat "$3" > "$TEST_ROOT/brewfile"'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" bootstrap > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/brewfile") == 'brew "literal\#{danger}"' ]]
  }
  It 'escapes Ruby interpolation in generated Brewfiles'
    When run ruby_interpolation_case
    The status should be success
  End

  confirm_case() {
    [[ $OSTYPE == linux* ]] || return 0
    day2_fixture
    ms_mod sample module.conf 'package apt alpha'
    stub_command apt 'exit 0'
    stub_command sudo 'printf "%s\n" "$*" > "$TEST_ROOT/sudo"'
    print -r -- n | env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" bootstrap > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ ! -e $TEST_ROOT/sudo && $(<"$TEST_ROOT/out") == *'sudo apt install alpha'* ]] || return 2
    print -r -- y | env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" bootstrap > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [[ $(<"$TEST_ROOT/sudo") == 'apt install alpha' ]]
  }
  It 'prints the system package command and requires confirmation'
    When run confirm_case
    The status should be success
  End

  public_installers_case() {
    ms_fixture_full
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    stub_command curl 'exit 42'
    ms_env
    local name result
    for name in krew gvm wezterm-terminfo pyenv nvm mise; do
      env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" install "$name" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
      result=$?
      [[ $result == 42 ]] || return 1
    done
  }
  It 'registers each public installer and propagates download failure'
    When run public_installers_case
    The status should be success
  End

  mise_day2_case() {
    ms_fixture_full
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'module mise' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    stub_command brew 'cat "$3" > "$TEST_ROOT/brewfile"'
    stub_command mise 'printf "%s\n" "$*" >> "$OPLOG"'
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" bootstrap > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/brewfile") == *'brew "mise"'* ]] || { cat "$TEST_ROOT/brewfile"; return 2; }
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --list > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [[ $(<"$TEST_ROOT/out") == *mise-tools* ]] || { cat "$TEST_ROOT/out"; return 4; }
    : > "$OPLOG"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only mise-tools --dry-run > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 5
    [[ $(<"$TEST_ROOT/out") == *'mise upgrade'* && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 6; }
  }
  It 'registers the public mise package and update listing with a side-effect-free dry-run'
    When run mise_day2_case
    The status should be success
  End

  mise_installer_case() {
    ms_fixture_full
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    print -r -- $'#!/bin/sh\nprintf "%s|%s" "$MISE_INSTALL_HELP" "$1" > "$TEST_ROOT/installer-env"' > "$TEST_ROOT/payload"
    stub_command curl 'printf "%s\n" "$@" > "$TEST_ROOT/curl-args"; while [ "$1" != -o ]; do shift; done; cp "$TEST_ROOT/payload" "$2"; printf "%s" "$2" > "$TEST_ROOT/temp-path"'
    print -r -- zsh-original > "$HOME/.zshrc"
    print -r -- bash-original > "$HOME/.bashrc"
    print -r -- profile-original > "$HOME/.profile"
    cp "$HOME/.zshrc" "$TEST_ROOT/zshrc-original"
    cp "$HOME/.bashrc" "$TEST_ROOT/bashrc-original"
    cp "$HOME/.profile" "$TEST_ROOT/profile-original"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" install mise > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    [[ $(<"$TEST_ROOT/curl-args") == *https://mise.run* && $(<"$TEST_ROOT/installer-env") == '0|' ]] || return 2
    [[ ! -e $(<"$TEST_ROOT/temp-path") ]] || return 3
    cmp "$HOME/.zshrc" "$TEST_ROOT/zshrc-original" && cmp "$HOME/.bashrc" "$TEST_ROOT/bashrc-original" && cmp "$HOME/.profile" "$TEST_ROOT/profile-original"
  }
  It 'runs the mise installer from mise.run with profile edits disabled and cleans its download'
    When run mise_installer_case
    The status should be success
  End

  invalid_update_case() {
    day2_fixture
    ms_mod sample module.conf $'update good touch "$TEST_ROOT/ran"\nupdate invalid'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only good > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? != 0 && ! -e $TEST_ROOT/ran ]]
  }
  It 'validates all update definitions before executing a selected step'
    When run invalid_update_case
    The status should be success
  End

  ordered_case() {
    day2_fixture
    print -r -- $'#!/usr/bin/env zsh\nprint -r -- "$MARKSHARC_SYNC_PART" >> "$OPLOG"' > "$MS_HOME/core/cli/sync"
    print -r -- $'#!/usr/bin/env zsh\nprint -r -- render >> "$OPLOG"' > "$MS_HOME/core/cli/render"
    stub_command update-fixture 'printf "%s\n" "$1" >> "$OPLOG"'
    ms_mod sample module.conf 'update example update-fixture module'
    print -r -- 'update overlay update-fixture overlay' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$OPLOG") == $'repositories\npins\nmodule\noverlay\nrender' ]]
  }
  It 'runs checkout sync, pins, module and overlay steps, then render in order'
    When run ordered_case
    The status should be success
  End

  unsafe_bundle_case() {
    day2_fixture
    mkdir -p "$XDG_CONFIG_HOME/marksharc/packages"
    print -r -- 'system "touch /tmp/invalid"' > "$XDG_CONFIG_HOME/marksharc/packages/input.Brewfile"
    stub_command brew 'touch "$TEST_ROOT/brew-ran"'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" bootstrap > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? != 0 && ! -e $TEST_ROOT/brew-ran ]]
  }
  It 'rejects executable Ruby in overlay Brewfile fragments'
    When run unsafe_bundle_case
    The status should be success
  End

  unsafe_package_case() {
    day2_fixture
    ms_mod sample module.conf 'package apt --assume-yes'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" bootstrap > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
    [[ $? != 0 ]]
  }
  It 'rejects package-manager options in package declarations'
    When run unsafe_package_case
    The status should be success
  End

  relative_update_case() {
    day2_fixture
    mkdir -p "$XDG_CONFIG_HOME/marksharc/packages"
    print -r -- 'update local ./packages/update-local' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    print -r -- $'#!/bin/sh\ntouch "$TEST_ROOT/relative"' > "$XDG_CONFIG_HOME/marksharc/packages/update-local"
    chmod +x "$XDG_CONFIG_HOME/marksharc/packages/update-local"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only local > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ -e $TEST_ROOT/relative ]]
  }
  It 'resolves relative update executables against their declaring overlay'
    When run relative_update_case
    The status should be success
  End

  missing_case() {
    day2_fixture
    ms_mod sample module.conf 'update absent marksharc-nonexistent-command'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only absent > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/out") == *'absent: skipped'* ]]
  }
  It 'skips missing optional update commands'
    When run missing_case
    The status should be success
  End

  selection_case() {
    day2_fixture
    ms_mod sample module.conf $'update one touch "$TEST_ROOT/one"\nupdate two touch "$TEST_ROOT/two"'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only two --dry-run > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ ! -e $TEST_ROOT/one && ! -e $TEST_ROOT/two && $(<"$TEST_ROOT/out") == two:* ]] || return 2
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update --only two > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [[ ! -e $TEST_ROOT/one && -e $TEST_ROOT/two ]]
  }
  It 'selects one update and makes dry-run side-effect free'
    When run selection_case
    The status should be success
  End

  update_failure_case() {
    day2_fixture
    ms_mod sample module.conf $'update first false\nupdate second touch "$TEST_ROOT/second"'
    print -r -- $'#!/usr/bin/env zsh\nexit 0' > "$MS_HOME/core/cli/sync"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $? != 0 && -f $TEST_ROOT/second && $(<"$TEST_ROOT/out") == *first* && $(<"$TEST_ROOT/out") == *second* ]]
  }
  It 'continues after a failed update step and returns failure'
    When run update_failure_case
    The status should be success
  End

  installer_case() {
    day2_fixture
    ms_mod sample module.conf 'installer example run'
    ms_mod sample run $'#!/bin/sh\nprintf installed > "$TEST_ROOT/installed"'
    chmod +x "$MS_HOME/modules/sample/run"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" install example > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/installed") == installed ]]
  }
  It 'runs the script registered by an enabled module'
    When run installer_case
    The status should be success
  End
End
