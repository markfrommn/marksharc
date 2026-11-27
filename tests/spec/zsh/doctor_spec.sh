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
  altered_fish_stub_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_STATE_HOME/marksharc" "$XDG_CONFIG_HOME/fish/conf.d"
    print -r -- '# marksharc: managed stub' > "$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish"
    print -r -- "fish_stub=$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish"$'\n''fish_stub_sum=1 1' > "$XDG_STATE_HOME/marksharc/install.manifest"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'modified fish stub'* ]]
  }
  It 'detects edits to the fish installer stub'
    When run altered_fish_stub_case
    The status should be success
  End
  unchanged_fish_stub_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local stub=$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish
    mkdir -p "$XDG_STATE_HOME/marksharc" "${stub:h}"
    print -r -- '# marksharc: managed stub' > "$stub"
    print -r -- "fish_stub=$stub"$'\n'"fish_stub_sum=$(command cksum < "$stub" | tr -s ' ' ' ')" > "$XDG_STATE_HOME/marksharc/install.manifest"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") != *'fish stub'* && $(<"$TEST_ROOT/out") != *'foreign dotfile'*fish* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'accepts an unchanged fish installer stub by its manifest checksum'
    When run unchanged_fish_stub_case
    The status should be success
  End
  missing_fish_stub_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    local stub=$XDG_CONFIG_HOME/fish/conf.d/00-marksharc.fish
    mkdir -p "$XDG_STATE_HOME/marksharc"
    print -r -- "fish_stub=$stub"$'\n''fish_stub_sum=1 1' > "$XDG_STATE_HOME/marksharc/install.manifest"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *"missing or unmanaged fish stub: $stub"* ]] || { cat "$TEST_ROOT/out"; return 1; }
    mkdir -p "${stub:h}"
    print -r -- 'elsewhere' > "$TEST_ROOT/linked.fish"
    ln -s "$TEST_ROOT/linked.fish" "$stub"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *"missing or unmanaged fish stub: $stub"* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'reports a missing or symlinked fish installer stub'
    When run missing_fish_stub_case
    The status should be success
  End
  fisher_leftover_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_CONFIG_HOME/fish/functions"
    print -r -- 'jorgebucaran/fisher'$'\n''edc/bass' > "$XDG_CONFIG_HOME/fish/fish_plugins"
    print -r -- 'function fisher; end' > "$XDG_CONFIG_HOME/fish/functions/fisher.fish"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *"fisher leftover (marksharc pins its fish plugins): $XDG_CONFIG_HOME/fish/fish_plugins"* &&
       $out == *'2: edc/bass'* &&
       $out == *"fisher leftover (marksharc pins its fish plugins): $XDG_CONFIG_HOME/fish/functions/fisher.fish"* ]] || { print -r -- "$out"; return 1; }
  }
  It 'reports fisher leftovers so the host can drop fisher'
    When run fisher_leftover_case
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
    [[ $(<"$TEST_ROOT/out") != *'modified stub'* && $(<"$TEST_ROOT/out") != *'stale environment ID'* && $(<"$TEST_ROOT/out") != *'stale generated stub'* && $(<"$TEST_ROOT/out") != *"foreign dotfile: $HOME/.bashrc"* && $(<"$TEST_ROOT/out") != *"modified bash stub: $HOME/.bashrc"* && $(<"$TEST_ROOT/out") != *"modified bash stub: $HOME/.bash_profile"* && $(<"$TEST_ROOT/out") != *"missing or unmanaged bash stub: $HOME/"* ]] || { cat "$TEST_ROOT/out"; return 3; }
  }
  It 'accepts the installer stub and environment from a valid fresh install'
    When run installed_case
    The status should be success
  End
  bash_stub_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_STATE_HOME/marksharc"
    print -r -- '# marksharc: managed stub' > "$HOME/.bashrc"
    cp "$HOME/.bashrc" "$HOME/.bash_profile"
    print -r -- "bash_stub_sum=$(cksum < "$HOME/.bashrc")" > "$XDG_STATE_HOME/marksharc/install.manifest"
    print -r -- changed >> "$HOME/.bash_profile"
    stub_command cksum '/usr/bin/cksum "$@" | sed "s/ /   /g"'
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") != *"foreign dotfile: $HOME/.bashrc"* && $(<"$TEST_ROOT/out") != *"modified bash stub: $HOME/.bashrc"* && $(<"$TEST_ROOT/out") != *"missing or unmanaged bash stub: $HOME/.bashrc"* && $(<"$TEST_ROOT/out") == *"modified bash stub: $HOME/.bash_profile"* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'accepts an unchanged Bash stub and identifies a modified Bash profile'
    When run bash_stub_case
    The status should be success
  End
  missing_provider_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_copy_module cc-providers
    mkdir -p "$XDG_CONFIG_HOME/marksharc/providers"
    print -r -- 'legacy fixture' > "$XDG_CONFIG_HOME/marksharc/providers/a.provider"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'cc-providers'*'no .conf provider files'* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'diagnoses a default-enabled provider module with legacy files only'
    When run missing_provider_case
    The status should be success
  End
  optional_provider_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_copy_module cc-providers
    mkdir -p "$XDG_CONFIG_HOME/marksharc/providers"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") != *'no .conf provider files'* ]] || return 1
    print -r -- 'module cc-providers off' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    print -r -- legacy > "$XDG_CONFIG_HOME/marksharc/providers/a.provider"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") != *'no .conf provider files'* ]]
  }
  It 'keeps an unused or disabled provider module quiet'
    When run optional_provider_case
    The status should be success
  End
  configured_provider_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_copy_module cc-providers
    mkdir -p "$XDG_CONFIG_HOME/marksharc" "$TEST_ROOT/providers"
    print -rl -- 'module cc-providers' "set cc-providers.dir '$TEST_ROOT/providers'" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'no .conf provider files'* ]] || return 1
    print -r -- 'env TEST fixture' > "$TEST_ROOT/providers/a.conf"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") != *'cc-providers:'* ]]
  }
  It 'checks the configured provider directory and accepts a migrated definition'
    When run configured_provider_case
    The status should be success
  End
  bash_missing_symlink_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$XDG_STATE_HOME/marksharc"
    print -r -- 'bash_stub_sum=1 1' > "$XDG_STATE_HOME/marksharc/install.manifest"
    print -r -- foreign > "$TEST_ROOT/bash-target"
    ln -s "$TEST_ROOT/bash-target" "$HOME/.bashrc"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *"missing or unmanaged bash stub: $HOME/.bashrc"* && $(<"$TEST_ROOT/out") == *"missing or unmanaged bash stub: $HOME/.bash_profile"* && $(<"$TEST_ROOT/out") == *'1: foreign'* ]]
  }
  It 'reports a missing Bash profile and a symlinked Bash rc'
    When run bash_missing_symlink_case
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
  fish_plugin_missing_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_mod sample module.conf 'describe sample'
    ms_mod sample fish.plugins 'plugin fish-sample /not-used abc shell fish kind source'
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'missing plugin'*fish-sample*'(run marksharc update)'* ]]
  }
  It 'reports a missing fish plugin pin'
    When run fish_plugin_missing_case
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
    # The child starts without marksharc, so this .zshenv does marksharc's two startup
    # guards itself. Its presence stops Debian's blocking zsh-newuser-install menu (shown
    # when no startup files exist); skip_global_compinit stops Ubuntu's /etc/zsh/zshrc
    # compinit. Keep these guards: this case tests a plain failed startup, while
    # timing_compinit_case below deliberately exercises the real blocked prompt.
    mkdir -p "$TEST_ROOT/empty-zdot"
    print -r -- 'skip_global_compinit=1' > "$TEST_ROOT/empty-zdot/.zshenv"
    ms_env
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/empty-zdot" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") == *'startup failed'* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'reports a failed eligible interactive startup instead of a healthy time'
    When run timing_failure_case
    The status should be success
  End
  timing_prompt_fixture() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    mkdir -p "$TEST_ROOT/prompt-zdot" "$XDG_CONFIG_HOME/marksharc"
    print -r -- 'skip_global_compinit=1' > "$TEST_ROOT/prompt-zdot/.zshenv"
    ms_env
  }
  timing_prompt_report() {
    zmodload zsh/datetime
    local started=$EPOCHREALTIME
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/prompt-zdot" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *"doctor: interactive startup blocked waiting for input: $1"* &&
       $out != *'startup timed out'* && $out != *'startup failed'* ]] || { cat "$TEST_ROOT/out"; return 1; }
    # Generous allowance for a busy CI host; still below the default 5 s timeout.
    (( EPOCHREALTIME - started < 3 ))
  }
  timing_compinit_case() {
    timing_prompt_fixture
    mkdir -p "$TEST_ROOT/insecure" "$TEST_ROOT/trusted"
    chmod 777 "$TEST_ROOT/insecure"
    # Restrict FPATH to known fixture permissions, regardless of the CI image.
    local fn
    for fn in compinit compaudit; do
      local -a sources=( ${^fpath}/$fn(N-.) )
      cp "$sources[1]" "$TEST_ROOT/trusted/$fn"
    done
    print -r -- 'fpath=( "$TEST_ROOT/insecure" "$TEST_ROOT/trusted" )
autoload -Uz compinit
compinit' > "$TEST_ROOT/prompt-zdot/.zshrc"
    timing_prompt_report 'Ignore insecure directories and continue [y] or abort compinit [n]?'
  }
  It 'quickly names a real compinit prompt from an insecure fixture directory'
    When run timing_compinit_case
    The status should be success
  End
  timing_newuser_case() {
    timing_prompt_fixture
    print -r -- 'print -r -- $$ > "$TEST_ROOT/menu.pid"
LINES=24 COLUMNS=80
autoload -Uz zsh-newuser-install
zsh-newuser-install -f' > "$TEST_ROOT/prompt-zdot/.zshrc"
    timing_prompt_report '--- Type one of the keys in parentheses ---' || return 1
    # The menu traps HUP: deleting the zpty alone can leave it alive forever.
    ! kill -0 "$(<"$TEST_ROOT/menu.pid")" 2>/dev/null
  }
  It 'quickly names the real zsh-newuser-install menu prompt'
    When run timing_newuser_case
    The status should be success
  End
  timing_finished_prompt_case() {
    timing_prompt_fixture
    print -r -- 'set doctor.startup_ms 2000' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    print -r -- 'print -n -- "Ignore insecure directories and continue [y] or abort compinit [n]? "
sleep 0.1
print
sleep 0.35
MARKSHARC_SESSION=interactive' > "$TEST_ROOT/prompt-zdot/.zshrc"
    env -i "${MS_ENV[@]}" ZDOTDIR="$TEST_ROOT/prompt-zdot" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'doctor: interactive startup '* && $out != *'startup blocked'* &&
       $out != *'startup failed'* && $out != *'startup timed out'* ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'allows startup to continue when prompt-like output is followed by completion'
    When run timing_finished_prompt_case
    The status should be success
  End
  managed_global_compinit_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_copy_module completion
    mkdir -p "$TEST_ROOT/insecure" "$XDG_CONFIG_HOME/marksharc"
    # This tests guard ownership, not the speed of cold compinit on a CI host.
    print -r -- 'set doctor.startup_ms 2000' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    chmod 777 "$TEST_ROOT/insecure"
    # Coexist mode lets the fixture emulate Ubuntu's global zshrc before init.
    print -r -- 'export MARKSHARC_COEXIST=1
fpath=( "$TEST_ROOT/insecure" $fpath )' >> "$HOME/.zshenv"
    print -r -- 'if [[ -z $skip_global_compinit ]]; then
  print -r -- global-compinit-ran >> "$OPLOG"
  autoload -Uz compinit
  compinit
fi
source "$MARKSHARC_HOME/core/zsh/zshrc.zsh"' > "$HOME/.zshrc"
    ms_env
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'doctor: interactive startup '* && $out != *'startup blocked'* &&
       $out != *'startup failed'* && $out != *'startup timed out'* && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out"; return 1; }
  }
  It 'skips Ubuntu-style global compinit with an insecure FPATH in managed startup'
    When run managed_global_compinit_case
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
  mise_doctor_fixture() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_copy_module mise
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    ms_env
  }
  missing_mise_case() {
    mise_doctor_fixture
    print -r -- 'set mise.tools "node go"' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *mise*missing* || $out == *missing*mise* ]] || { print -r -- "$out"; return 1; }
    print -r -- 'set mise.tools ""' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    out=$(<"$TEST_ROOT/out")
    [[ $out != *mise*missing* && $out != *missing*mise* ]] || { print -r -- "$out"; return 2; }
    print -r -- 'set mise.tools "node go"' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    stub_command mise 'exit 0'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    out=$(<"$TEST_ROOT/out")
    [[ $out != *mise*missing* && $out != *missing*mise* ]] || { print -r -- "$out"; return 3; }
  }
  It 'diagnoses missing mise only for nonempty configured tools without requiring module listing'
    When run missing_mise_case
    The status should be success
  End

  uv_pin_case() {
    mise_doctor_fixture
    stub_command mise 'exit 0'
    print -r -- 'set mise.tools "python"' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    print -r -- 'cpython-3.13-any-any-any' > "$HOME/.python-version"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'.python-version'* && $out == *uv* && $out == *mise* ]] || { print -r -- "$out"; return 1; }
    print -r -- '3.13.0' > "$HOME/.python-version"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") != *'.python-version'* ]] || { cat "$TEST_ROOT/out"; return 2; }
    print -r -- 'cpython-3.13-any-any-any' > "$HOME/.python-version"
    print -r -- 'set mise.tools "node"' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    [[ $(<"$TEST_ROOT/out") != *'.python-version'* ]] || { cat "$TEST_ROOT/out"; return 3; }
  }
  It 'warns about a uv Python pin only while mise owns Python'
    When run uv_pin_case
    The status should be success
  End

  carapace_doctor_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    ms_copy_module completion-carapace completion-fzf-tab
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    ms_env
    # Default off: missing carapace is quiet.
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    local out=$(<"$TEST_ROOT/out")
    [[ $out != *'missing command: carapace'* && $out == *'missing plugin'*fzf-tab* ]] || { print -r -- "$out"; return 1; }
    # Opted in without carapace: reports missing command once and still checks fzf-tab fallback plugin.
    print -r -- 'set completion-carapace.enable on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    out=$(<"$TEST_ROOT/out")
    [[ $(grep -c 'missing command: carapace (completion-carapace)' "$TEST_ROOT/out") == 1 && $out == *'missing plugin'*fzf-tab* ]] || { print -r -- "$out"; return 2; }
    # Opted in with carapace present: no missing command and suppressed fzf-tab clone is not demanded.
    stub_command carapace 'exit 0'
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    out=$(<"$TEST_ROOT/out")
    [[ $out != *'missing command: carapace'* && $out != *'missing plugin'*fzf-tab* ]] || { print -r -- "$out"; return 3; }
    # Forcing both restores the fzf-tab plugin check.
    printf 'set completion-carapace.enable on\nset completion-carapace.allow_fzf_tab on\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    out=$(<"$TEST_ROOT/out")
    [[ $out == *'missing plugin'*fzf-tab* ]] || { print -r -- "$out"; return 4; }
  }
  It 'diagnoses missing carapace only when enabled and skips suppressed fzf-tab plugin checks'
    When run carapace_doctor_case
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

  coexist_doctor_case() {
    ms_fixture
    cp -R "$MARKSHARC_ROOT/bin" "$MS_HOME/bin"
    cp -R "$MARKSHARC_ROOT/templates" "$MS_HOME/templates"
    rm -f "$HOME/.zshenv"
    print -r -- 'export USER_ENV=1' > "$HOME/.zshenv"
    print -r -- 'alias user_alias="echo ok"' > "$HOME/.zshrc"
    print -r -- 'user bash' > "$HOME/.bashrc"
    ms_env
    env -i "${MS_ENV[@]}" PATH="$PATH:${REAL_GIT:h}" sh "$MARKSHARC_ROOT/install.sh" --home "$MS_HOME" --coexist --no-plugins > "$TEST_ROOT/install-out" 2> "$TEST_ROOT/install-err" || { cat "$TEST_ROOT/install-err"; return 1; }
    # Healthy coexist install: no stub/zdot/foreign-dotfile complaints, 0 issues.
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 2
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'doctor: 0 issue(s)'* && $out != *'stale generated stub'* && $out != *'foreign dotfile'* && $out != *'missing coexist'* && $out != *'modified coexist'* ]] || { print -r -- "$out"; return 3; }
    # Modifying a coexist stub is detected.
    print -r -- '# edited' >> "$XDG_STATE_HOME/marksharc/coexist/zshrc.zsh"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 4
    [[ $(<"$TEST_ROOT/out") == *'modified coexist stub'* ]] || { cat "$TEST_ROOT/out"; return 5; }
    # Removing the coexist source line from ~/.zshrc is detected.
    print -r -- 'alias user_alias="echo ok"' > "$HOME/.zshrc"
    env -i "${MS_ENV[@]}" "$MS_HOME/bin/marksharc" doctor > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 6
    [[ $(<"$TEST_ROOT/out") == *"missing coexist source line: $HOME/.zshrc"* ]] || { cat "$TEST_ROOT/out"; return 7; }
  }
  It 'accepts a healthy coexist install and diagnoses modified coexist stubs or missing source lines'
    When run coexist_doctor_case
    The status should be success
  End
End
