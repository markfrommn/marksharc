Describe 'marksharc doctor'
  missing_command_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_mod needs-tool module.conf $'describe "fixture"\nrequires command marksharc-no-such-command'
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'module needs-tool' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'missing command: marksharc-no-such-command (needs-tool)'* ]]
  }
  It 'reports missing commands for modules the overlay enables explicitly'
    When run missing_command_case
    The status should be success
  End
  optional_command_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_mod needs-tool module.conf $'describe "fixture"\nrequires command marksharc-no-such-command'
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") != *'marksharc-no-such-command'* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'treats requires command as a load condition for modules enabled by default'
    When run optional_command_case
    The status should be success
  End
  missing_stub_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    rm "$HOME/.zshenv"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'missing stub'* ]]
  }
  It 'reports a missing managed stub'
    When run missing_stub_case
    The status should be success
  End
  altered_stub_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    print -r -- '# marksharc: managed stub' > "$HOME/.zshenv"
    mkdir -p "$XDG_STATE_HOME/marksharc" "$TEST_ROOT/empty-zdot"
    print -r -- 'stub_sum=1 1' > "$XDG_STATE_HOME/marksharc/install.manifest"
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'modified stub'* ]]
  }
  It 'detects changes to the installer stub using its recorded checksum'
    When run altered_stub_case
    The status should be success
  End
  installed_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    cp -R "$MARKSHARC_ROOT/templates" "$MS_HOME/templates"
    rm "$HOME/.zshenv"
    ln -s "$MS_HOME" "$TEST_ROOT/framework-link"
    ms_env
    env -i "${MS_ENV[@]}" sh "$MARKSHARC_ROOT/install.sh" --home "$TEST_ROOT/framework-link" > "$TEST_ROOT/install-out" 2> "$TEST_ROOT/install-err" || return 1
    env -i "${MS_ENV[@]}" zsh -lc exit > /dev/null 2>&1 || return 4
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 2
    [[ $(<"$TEST_ROOT/out") != *'modified stub'* && $(<"$TEST_ROOT/out") != *'stale environment ID'* && $(<"$TEST_ROOT/out") != *'stale generated stub'* ]] || { cat "$TEST_ROOT/out"; return 3; }
  }
  It 'accepts the installer stub and environment from a valid fresh install'
    When run installed_case
    The status should be success
  End
  foreign_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    print -r -- 'foreign content' > "$HOME/.zshrc"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'foreign dotfile'*'.zshrc'* ]]
  }
  It 'reports foreign dotfiles left outside the managed stub'
    When run foreign_case
    The status should be success
  End
  link_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME"
    ln -s "$TEST_ROOT/missing" "$XDG_CONFIG_HOME/marksharc"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'broken link'* ]]
  }
  It 'reports a broken overlay link'
    When run link_case
    The status should be success
  End
  plugin_missing_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_mod sample module.conf 'describe sample'
    ms_mod sample zsh.plugins 'plugin sample /not-used abc shell zsh kind source'
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'missing plugin'*sample*'(run marksharc update)'* ]]
  }
  It 'reports a missing enabled-module plugin clone'
    When run plugin_missing_case
    The status should be success
  End
  repo_state_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    "$REAL_GIT" -C "$MS_HOME" init -q || return 1
    print -r -- changed > "$MS_HOME/untracked"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'dirty repository'* ]]
  }
  It 'reports a dirty repository without fetching'
    When run repo_state_case
    The status should be success
  End
  duplicate_path_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$TEST_ROOT/empty-zdot"
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" PATH="$TEST_ROOT/bin:/usr/bin:/bin:/usr/bin" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'duplicate PATH'*'/usr/bin'* ]]
  }
  It 'reports duplicate PATH entries'
    When run duplicate_path_case
    The status should be success
  End
  parent_path_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_pty -ic 'typeset +U path; path+=(/usr/bin); marksharc doctor; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'duplicate PATH'*'/usr/bin'* ]]
  }
  It 'diagnoses duplicate PATH entries from the invoking interactive shell'
    When run parent_path_case
    The status should be success
  End
  env_id_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$TEST_ROOT/empty-zdot"
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_ENV=stale "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'stale environment'* ]]
  }
  It 'reports an inherited environment ID that no longer matches its inputs'
    When run env_id_case
    The status should be success
  End
  budget_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'set doctor.startup_ms 0' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'startup budget'* ]]
  }
  It 'reports startup time against the configured budget'
    When run budget_case
    The status should be success
  End
  zdot_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_STATE_HOME/marksharc/zdot" "$TEST_ROOT/empty-zdot"
    print -r -- 2 > "$XDG_STATE_HOME/marksharc/zdot/.version"
    print -r -- bad > "$XDG_STATE_HOME/marksharc/zdot/.zshrc"
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'stale generated stub'* ]]
  }
  It 'reports missing or altered generated ZDOTDIR stubs'
    When run zdot_case
    The status should be success
  End
  shell_foreign_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/fish"
    print -r -- 'foreign bash line' > "$HOME/.bashrc"
    print -r -- 'foreign fish line' > "$XDG_CONFIG_HOME/fish/config.fish"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'foreign bash line'* && $(<"$TEST_ROOT/out") == *'foreign fish line'* ]]
  }
  It 'lists foreign bash and fish configuration lines'
    When run shell_foreign_case
    The status should be success
  End
  timing_failure_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    # An empty .zshrc: the child starts without marksharc. With no startup files at all,
    # Debian's zsh opens the blocking zsh-newuser-install menu and the child times out.
    mkdir -p "$TEST_ROOT/empty-zdot"
    : > "$TEST_ROOT/empty-zdot/.zshrc"
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'startup failed'* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'reports a failed eligible interactive startup instead of a healthy time'
    When run timing_failure_case
    The status should be success
  End
  timing_timeout_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_mod slow module.conf 'describe slow'
    ms_mod slow init.zsh 'sleep 3'
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'set doctor.startup_timeout_ms 300' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'interactive startup timed out after 300 ms'* && $(<"$TEST_ROOT/out") != *'startup failed'* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'reports a startup that outlives the timeout as timed out, not failed'
    When run timing_timeout_case
    The status should be success
  End
  timing_notify_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    stub_command nohup 'printf "unexpected notify\n" >> "$OPLOG"; exit 1'
    ms_env
    env -i "${MS_ENV[@]}" MARKSHARC_NOTIFY=1 "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'interactive startup'* && ! -s $OPLOG ]]
  }
  It 'suppresses notification while timing an eligible interactive shell'
    When run timing_notify_case
    The status should be success
  End
  host_override_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$TEST_ROOT/global" "$TEST_ROOT/host" "$TEST_ROOT/empty-zdot" "$XDG_CONFIG_HOME/marksharc/hosts"
    print -r -- "set sync.repos '$TEST_ROOT/global'" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    print -r -- "set sync.repos '$TEST_ROOT/host'" > "$XDG_CONFIG_HOME/marksharc/hosts/testhost.conf"
    stub_command git "if [ \"\$2\" = '$TEST_ROOT/global' ]; then printf global >> '$OPLOG'; fi; exec '$REAL_GIT' \"\$@\""
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" MARKSHARC_HOST=testhost "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    [[ ! -s $OPLOG ]]
  }
  It 'does not inspect repositories replaced by the host configuration'
    When run host_override_case
    The status should be success
  End
End
