# Declarative .comp parser and four-target renderer (COMPLETION-SPEC sections 3, 5.1, 5.2).
Describe 'declarative .comp completion renderer'
  render_cli() {
    local -a extra=()
    while [[ ${1-} == [A-Za-z_]*=* ]]; do extra+=( "$1" ); shift; done
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb MARKSHARC_HOME="$MS_HOME" \
      MARKSHARC_CONFIG="${MARKSHARC_CONFIG:-$XDG_CONFIG_HOME/marksharc}" \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT" HOST=testhost MARKSHARC_HOST=testhost \
      "${extra[@]}" \
      /bin/zsh -f "$MS_HOME/core/cli/render" "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
  }

  write_rich_fixtures() {
    mkdir -p "$MS_HOME/core/completions"
    cat > "$MS_HOME/core/completions/democtl.comp" <<'EOF'
# Hierarchical subcommand spec covering flags, choices, and dynamic ms:* kinds
command democtl "Demo control CLI"
flag _ -h,--help "Show help [all]"
flag _ -V,--version "Show version"
subcommand sync "Sync checkouts"
flag sync --auto "Quiet background sync"
flag sync -y,--yes "Assume yes"
subcommand sync/timer "Manage sync timer"
flag sync/timer -h,--help "Timer help"
arg sync/timer 1 choices:on,off,status "Timer action"
subcommand hosts "Manage host inventory"
subcommand hosts/populate "Discover hosts"
flag hosts/populate --all "Add all hosts"
flag hosts/populate --source value choices:ssh,hc,all "Discovery source"
subcommand hosts/remove "Remove a host"
arg hosts/remove 1 ms:hosts "Host name"
subcommand module "Manage modules"
subcommand module/enable "Enable a module"
arg module/enable 1 ms:modules "Module name"
subcommand update "Run updates"
flag update --only value ms:update-steps "Run one step"
subcommand install "Run installer"
arg install 1 ms:installers "Installer name"
subcommand push "Push to hosts"
flag push --timeout value string "Timeout seconds"
arg push rest ms:hosts "Target hosts"
EOF

    ms_mod launchfix module.conf 'describe "Launch fixture"'
    ms_mod launchfix completions/ltool.comp 'command ltool "Launch tool"
mode _ flag-form-locks-positional
flag _ -h,--help "Show usage"
flag _ --host value ms:launch-hosts locks-positional "Choose host"
flag _ --repo value ms:base-repos-or-dir locks-positional "Choose repo"
flag _ --worktree value ms:worktrees locks-positional "Choose worktree"
flag _ --command value command locks-positional "Choose command"
flag _ --mux value choices:hc,herdr,tmux,herdr-core "Choose mux"
flag _ --env value string repeatable "Set env var"
flag _ --base-only "Base repos only"
arg _ 1 ms:launch-repo-target "Target"
arg _ 2 command "Command"
arg _ rest file "Arguments"
arg _ dash1 command "Dash command"
arg _ dash-rest file "Dash arguments"'

    ms_mod launchfix completions/stool.comp 'command stool "Session tool"
mode _ flag-form-locks-positional
flag _ --host value ms:launch-hosts locks-positional "Host"
flag _ --pwd value dir locks-positional "Directory"
flag _ --command value command locks-positional "Command"
arg _ 1 ms:launch-session-target "Target"
arg _ 2 command "Command"
arg _ rest file "Arguments"
arg _ dash1 command "Dash command"
arg _ dash-rest file "Dash arguments"'
  }

  golden_and_syntax_case() {
    emulate -L zsh
    ms_fixture
    # Put MS_HOME in a path with a space to verify safe POSIX quoting in all targets
    local spaced="$TEST_ROOT/ms home"
    mv "$MS_HOME" "$spaced"
    MS_HOME=$spaced
    export MS_HOME
    write_rich_fixtures

    render_cli || { cat "$TEST_ROOT/err"; return 1; }
    local cache="$XDG_CACHE_HOME/marksharc/testhost"
    local cmd zsh_f bash_f fish_f cara_f

    for cmd in democtl ltool stool; do
      zsh_f="$cache/completions/zsh/_$cmd"
      bash_f="$cache/completions/bash/$cmd.bash"
      fish_f="$cache/completions/fish/$cmd.fish"
      cara_f="$cache/completions/carapace/$cmd.yaml"
      [[ -r $zsh_f && -r $bash_f && -r $fish_f && -r $cara_f ]] || { print -r -- "MISSING $cmd"; return 2; }

      # Syntax checks
      /bin/zsh -n "$zsh_f" || { print -r -- "zsh -n failed: $zsh_f"; return 3; }
      "${MARKSHARC_TEST_BASH:-/bin/bash}" --noprofile --norc -n "$bash_f" || { print -r -- "bash -n failed: $bash_f"; return 4; }
      if [[ -n ${REAL_FISH-} && -x $REAL_FISH ]]; then
        "$REAL_FISH" --no-execute "$fish_f" || { print -r -- "fish --no-execute failed: $fish_f"; return 5; }
      fi
    done

    # Golden assertions: Zsh
    local z_demo=$(<"$cache/completions/zsh/_democtl")
    local z_ltool=$(<"$cache/completions/zsh/_ltool")
    [[ $z_demo == '#compdef democtl'* && $z_demo == *'_ms_comp_democtl_scope_sync_timer'* && $z_demo == *'_ms_comp_democtl_choices'*'on'*'off'*'status'* && $z_demo == *'_ms_comp_democtl_kind hosts'* ]] || { print -r -- "ZSH_DEMO=$z_demo"; return 6; }
    [[ $z_ltool == '#compdef ltool'* && $z_ltool == *'_ms_scan_locked'* && $z_ltool == *'_ms_scan_has_cmd'* && $z_ltool == *'compadd -r : -S :'* && $z_ltool == *'compset -P '\''*:'\'''* ]] || { print -r -- "ZSH_LTOOL=$z_ltool"; return 7; }

    # Golden assertions: Bash
    local b_demo=$(<"$cache/completions/bash/democtl.bash")
    local b_ltool=$(<"$cache/completions/bash/ltool.bash")
    [[ $b_demo == *'_ms_complete_democtl()'* && $b_demo == *"complete -o filenames -F _ms_complete_democtl 'democtl'"* && $b_demo == *"'hosts/populate'"* ]] || { print -r -- "BASH_DEMO=$b_demo"; return 8; }
    [[ $b_ltool == *'_ms_complete_ltool()'* && $b_ltool == *'_ms_bash_comp_launch_repo_target'* && $b_ltool == *'if (( ! flag_form )); then'* && $b_ltool == *'if (( has_command )); then'* ]] || { print -r -- "BASH_LTOOL=$b_ltool"; return 9; }

    # Golden assertions: Fish
    local f_demo=$(<"$cache/completions/fish/democtl.fish")
    local f_ltool=$(<"$cache/completions/fish/ltool.fish")
    [[ $f_demo == *"complete -c 'democtl' -f"* && $f_demo == *"'hosts/populate'"* && $f_demo == *"-l 'source'"* ]] || { print -r -- "FISH_DEMO=$f_demo"; return 10; }
    [[ $f_ltool == *"complete -c 'ltool' -f"* && $f_ltool == *'__ms_comp_ltool_kind launch-repo-target'* && $f_ltool == *'__ms_comp_ltool_ctx locked'* ]] || { print -r -- "FISH_LTOOL=$f_ltool"; return 11; }

    # Golden assertions: Carapace YAML
    local c_demo=$(<"$cache/completions/carapace/democtl.yaml")
    local c_ltool=$(<"$cache/completions/carapace/ltool.yaml")
    local c_stool=$(<"$cache/completions/carapace/stool.yaml")
    local helper_sq="'$MS_HOME/core/cli/complete'"
    [[ $c_demo == *'name: "democtl"'* && $c_demo == *'"-h, --help": "Show help [all]"'* && $c_demo == *"\$($helper_sq hosts --from-carapace)"* && $c_demo != *'$MARKSHARC_HOME'* ]] || { print -r -- "CARA_DEMO=$c_demo"; return 12; }
    [[ $c_ltool == *'"--env*=": "Set env var"'* && $c_ltool == *'"$directories"'* && $c_ltool == *'"$nospace(:)"'* && $c_ltool == *"\$($helper_sq launch-repo-target --from-carapace)"* && $c_ltool == *'"$carapace.shell.Executables"'* ]] || { print -r -- "CARA_LTOOL=$c_ltool"; return 13; }
    [[ $c_stool == *"\$($helper_sq launch-hosts --colon --from-carapace)"* && $c_stool == *'"$nospace(:)"'* ]] || { print -r -- "CARA_STOOL=$c_stool"; return 14; }

    # Functional Bash 4.4+ check on rendered democtl.bash and ltool.bash
    if ! bash_interactive_unavailable; then
      mkdir -p "$XDG_CONFIG_HOME/marksharc" "$cache/repos"
      print -r -- 'host sol sol.internal' > "$XDG_CONFIG_HOME/marksharc/hosts.conf"
      printf 'alpha\t/work/alpha\tbase\t/work/alpha\tmain\nwt1\t/work/alpha-wt/wt1\tworktree\t/work/alpha\tfeat\n' > "$cache/repos/local.tsv"
      printf 'rem\t/srv/rem\tbase\t/srv/rem\tmain\n' > "$cache/repos/sol.tsv"

      local bout
      bout=$(env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        MARKSHARC_HOME="$MS_HOME" MARKSHARC_HOST=testhost \
        "${MARKSHARC_TEST_BASH}" --noprofile --norc -c '
          source "$1"
          source "$2"
          COMP_WORDS=(democtl hosts remove ""); COMP_CWORD=3; _ms_complete_democtl democtl ""
          printf "H:%s\n" "${COMPREPLY[*]}"
          COMP_WORDS=(democtl sync timer ""); COMP_CWORD=3; _ms_complete_democtl democtl ""
          printf "T:%s\n" "${COMPREPLY[*]}"
          COMP_WORDS=(ltool --host sol --repo ""); COMP_CWORD=4; _ms_complete_ltool ltool ""
          printf "R:%s\n" "${COMPREPLY[*]}"
          COMP_WORDS=(ltool --host sol ""); COMP_CWORD=3; _ms_complete_ltool ltool ""
          printf "L:%s\n" "${COMPREPLY[*]}"
          COMP_WORDS=(ltool sol : ""); COMP_CWORD=3; _ms_complete_ltool ltool ""
          printf "C:%s\n" "${COMPREPLY[*]}"
        ' _ "$cache/completions/bash/democtl.bash" "$cache/completions/bash/ltool.bash") || return 15
      [[ $bout == *'H:sol'* && $bout == *'T:on off status'* && $bout == *'R:rem'* && $bout == *'L:'$'\n'* && $bout == *'C:rem'* ]] || { print -r -- "BOUT=$bout"; return 16; }
    fi

    # Real Carapace 1.8.5 YAML validation & dynamic execution when carapace is installed
    if [[ -n ${REAL_CARAPACE-} && -x $REAL_CARAPACE ]]; then
      mkdir -p "$XDG_CONFIG_HOME/carapace/specs" "$XDG_CONFIG_HOME/marksharc" "$cache/repos"
      print -r -- 'host sol sol.internal' > "$XDG_CONFIG_HOME/marksharc/hosts.conf"
      printf 'rem\t/srv/rem\tbase\t/srv/rem\tmain\n' > "$cache/repos/sol.tsv"
      for cmd in democtl ltool stool; do
        ln -sf "$cache/completions/carapace/$cmd.yaml" "$XDG_CONFIG_HOME/carapace/specs/$cmd.yaml"
      done
      local cout
      cout=$(env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        MARKSHARC_HOST=testhost "$REAL_CARAPACE" democtl export democtl hosts remove "") || return 17
      [[ $cout == *'"messages":[]'* && $cout == *'"value":"sol"'* ]] || { print -r -- "COUT_DEMO=$cout"; return 18; }
      cout=$(env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        MARKSHARC_HOST=testhost "$REAL_CARAPACE" ltool export ltool --host sol --repo "") || return 19
      [[ $cout == *'"messages":[]'* && $cout == *'"value":"rem"'* ]] || { print -r -- "COUT_LTOOL=$cout"; return 20; }
      cout=$(env -i HOME="$HOME" PATH="$PATH" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        MARKSHARC_HOST=testhost "$REAL_CARAPACE" stool export stool "") || return 21
      [[ $cout == *'"messages":[]'* && $cout == *'"value":"sol:"'* && $cout == *'"nospace":'*':'* ]] || { print -r -- "COUT_STOOL=$cout"; return 22; }
    fi
  }
  It 'renders valid golden completions for zsh, Bash, Fish, and Carapace even with spaces in MARKSHARC_HOME'
    When run golden_and_syntax_case
    The status should be success
  End

  validation_and_rollback_case() {
    emulate -L zsh
    ms_fixture
    local cache="$XDG_CACHE_HOME/marksharc/testhost"
    mkdir -p "$MS_HOME/core/completions"
    print -r -- $'command goodcmd "Good"\nflag _ --ok "OK"' > "$MS_HOME/core/completions/goodcmd.comp"
    render_cli || { cat "$TEST_ROOT/err"; return 1; }
    [[ -r $cache/completions/zsh/_goodcmd ]] || return 2

    local -a bad_specs=(
      'flag _ --orphan "Missing command"'
      $'command a "One"\ncommand b "Duplicate"'
      'command ../bad "Bad name"'
      $'command a\nsubcommand x/y "Missing parent"'
      $'command a\nsubcommand x\nsubcommand x "Duplicate"'
      $'command a\nsubcommand x//y "Empty seg"'
      $'command a\nflag noscope --ok "Unknown scope"'
      $'command a\nflag _ badflag "No dash"'
      $'command a\nflag _ --ok\nflag _ --ok "Dup flag"'
      $'command a\nflag _ --ok value "Missing kind"'
      $'command a\nflag _ --ok value ms:bogus "Bad kind"'
      $'command a\nflag _ --ok value choices: "Empty choices"'
      $'command a\nflag _ --ok value choices:a,,b "Blank choice"'
      $'command a\nflag _ --ok repeatable repeatable "Dup kw"'
      $'command a\nflag _ --ok "desc" extra "Extra tok"'
      $'command a\narg _ 0 string "Zero slot"'
      $'command a\narg _ 1 string\narg _ 1 file "Dup slot"'
      $'command a\nmode _ unknown-mode'
      $'command a\nmode _ flag-form-locks-positional\nmode _ flag-form-locks-positional'
      'command a "unclosed quote'
      $'command a\neval "touch pwned"'
    )
    local spec
    integer idx=0
    for spec in "${bad_specs[@]}"; do
      (( ++idx ))
      print -r -- "$spec" > "$MS_HOME/core/completions/bad.comp"
      if render_cli; then
        print -r -- "BAD SPEC #$idx UNEXPECTEDLY SUCCEEDED: $spec"
        return 3
      fi
      [[ -s $TEST_ROOT/err ]] || { print -r -- "NO STDERR ON SPEC #$idx"; return 4; }
      # Atomic rollback: previous good completion stays intact and no bad artifact leaked
      [[ -r $cache/completions/zsh/_goodcmd && ! -e $cache/completions/zsh/_a && ! -e $cache/completions/zsh/_bad ]] || { print -r -- "ROLLBACK FAILED ON #$idx"; return 5; }
    done
    rm -f "$MS_HOME/core/completions/bad.comp"
    render_cli || return 6
  }
  It 'rejects malformed .comp specs with diagnostics and preserves the previous rendered cache atomically'
    When run validation_and_rollback_case
    The status should be success
  End

  precedence_coexistence_and_envid_case() {
    emulate -L zsh
    ms_fixture
    local cache="$XDG_CACHE_HOME/marksharc/testhost"
    mkdir -p "$MS_HOME/core/completions" "$XDG_CONFIG_HOME/marksharc/modules/priv/completions"

    # External zsh + bash completion generators coexist cleanly with .comp
    stub_command ext-zsh 'printf "#compdef exttool\n# external zsh\n"'
    stub_command ext-bash 'printf "_exttool() { :; }\ncomplete -F _exttool exttool\n"'
    ms_mod extmod module.conf 'describe "External generator module"
order 50
completion exttool ext-zsh
completion-bash exttool ext-bash'

    # Precedence test: core < public module (order 80) < overlay module (order 10)
    print -r -- $'command overcmd "From core"\nflag _ --from-core "Core"' > "$MS_HOME/core/completions/overcmd.comp"
    ms_mod pubmod module.conf $'describe "Public"\norder 80'
    ms_mod pubmod completions/overcmd.comp $'command overcmd "From public"\nflag _ --from-public "Public"'
    ms_mod disabledmod module.conf 'describe "Disabled"'
    ms_mod disabledmod completions/disabledcmd.comp $'command disabledcmd "Should not render"'
    ms_mod otheros module.conf $'describe "Other OS"\nrequires os plan9'
    ms_mod otheros completions/plan9cmd.comp $'command plan9cmd "Should not render"'

    print -r -- 'module disabledmod off' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    render_cli || { cat "$TEST_ROOT/err"; return 1; }

    # Public beats core; disabled and OS-incompatible skipped; external generators intact
    [[ $(<"$cache/completions/carapace/overcmd.yaml") == *'From public'* ]] || return 2
    [[ ! -e $cache/completions/zsh/_disabledcmd && ! -e $cache/completions/zsh/_plan9cmd ]] || return 3
    [[ $(<"$cache/completions/zsh/_exttool") == *'# external zsh'* ]] || return 4
    [[ -r $cache/completions-bash/exttool.bash && ! -e $cache/completions/bash/exttool.bash ]] || return 5
    [[ -r $cache/completions/bash/overcmd.bash && ! -e $cache/completions-bash/overcmd.bash ]] || return 6

    local id1=$(<"$cache/render-id")

    # Overlay module (even with lower order 10) overrides public module (order 80) and invalidates envid
    print -r -- $'describe "Private"\norder 10' > "$XDG_CONFIG_HOME/marksharc/modules/priv/module.conf"
    print -r -- $'command overcmd "From overlay"\nflag _ --from-overlay "Overlay"' > "$XDG_CONFIG_HOME/marksharc/modules/priv/completions/overcmd.comp"
    render_cli || { cat "$TEST_ROOT/err"; return 7; }
    local id2=$(<"$cache/render-id")
    [[ $id2 != "$id1" ]] || { print -r -- "ENVID DID NOT CHANGE ON OVERLAY COMP ADD"; return 8; }
    [[ $(<"$cache/completions/carapace/overcmd.yaml") == *'From overlay'* ]] || return 9

    # Editing .comp changes envid; --env-only updates env without touching completions or completions-bash
    print -r -- $'command overcmd "Edited overlay"\nflag _ --edited "Edited"' > "$XDG_CONFIG_HOME/marksharc/modules/priv/completions/overcmd.comp"
    render_cli --env-only || { cat "$TEST_ROOT/err"; return 10; }
    local id3=$(<"$cache/render-id")
    [[ $id3 != "$id2" ]] || { print -r -- "ENVID DID NOT CHANGE ON COMP EDIT"; return 11; }
    # Completions must NOT be modified by --env-only
    [[ $(<"$cache/completions/carapace/overcmd.yaml") == *'From overlay'* ]] || return 12
    [[ -r $cache/completions-bash/exttool.bash && $(<"$cache/completions/zsh/_exttool") == *'# external zsh'* ]] || return 13

    # Full render picks up the edit
    render_cli || { cat "$TEST_ROOT/err"; return 14; }
    [[ $(<"$cache/completions/carapace/overcmd.yaml") == *'Edited overlay'* ]] || return 15
  }
  It 'honors core < public < overlay precedence, coexists with completion-bash, invalidates envid, and preserves completions on --env-only'
    When run precedence_coexistence_and_envid_case
    The status should be success
  End
End
