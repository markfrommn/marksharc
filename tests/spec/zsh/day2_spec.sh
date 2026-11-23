Describe 'bootstrap, update and installers'
  day2_fixture() {
    ms_fixture
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
    for name in krew gvm wezterm-terminfo pyenv nvm; do
      env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" install "$name" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
      result=$?
      [[ $result == 42 ]] || return 1
    done
  }
  It 'registers each public installer and propagates download failure'
    When run public_installers_case
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
    print -r -- $'#!/usr/bin/env zsh\nprint -r -- "$MARKSHARC_SYNC_PART" >> "$TEST_ROOT/order"' > "$MS_HOME/core/cli/sync"
    ms_mod sample module.conf 'update example touch "$TEST_ROOT/module-ran"'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" update > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ $(<"$TEST_ROOT/order") == $'repositories\npins' && -e $TEST_ROOT/module-ran ]]
  }
  It 'runs checkout sync then plugin pins before module steps'
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
