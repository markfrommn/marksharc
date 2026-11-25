Describe 'completion-carapace opt-in module and fzf-tab mutual exclusion (spec 6.9)'
  FZF_TAB_SHA=24105b15714bfec37989ed5c5b6e60f572253019

  carapace_fixture() {
    ms_fixture_full
    print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
    stub_command git 'echo "FORBIDDEN git $*" >> "$OPLOG"; exit 99'
    local fzf_root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    mkdir -p "$fzf_root" "$XDG_CONFIG_HOME/marksharc" "$TEST_ROOT/fs"
    print -r -- 'print -r -- PLUGIN:fzf-tab >> "$OPLOG"' > "$fzf_root/fzf-tab.plugin.zsh"
  }

  # Point system path probes at an empty fixture root so host Homebrew/Linuxbrew
  # binaries (carapace, starship, etc.) never leak into hermetic PATH checks.
  carapace_pty() { ms_pty _ms_fs_root="$TEST_ROOT/fs" "$@"; }
  carapace_run() { ms_run _ms_fs_root="$TEST_ROOT/fs" "$@"; }

  stub_carapace() {
    stub_command carapace '
printf "CARAPACE_GEN:%s|B=%s|E=%s\n" "$*" "${CARAPACE_BRIDGES-unset}" "${CARAPACE_EXCLUDES-unset}" >> "$OPLOG"
printf "print -r -- CARAPACE_INIT >> \"\$OPLOG\"\n"
'
  }

  opt_in_default_case() {
    emulate -L zsh
    carapace_fixture
    stub_carapace
    carapace_pty -dic 'print -r -- "UI=$(completion-ui status) B=${CARAPACE_BRIDGES-unset} E=${CARAPACE_EXCLUDES-unset}"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out") log=$(<"$OPLOG")
    [[ $out == *READY* && $out == *'UI=completion-ui: active=fzf-tab B=unset E=unset'* ]] || { print -r -- "$out"; return 2; }
    [[ $log == *'PLUGIN:fzf-tab'* && $log != *'CARAPACE_'* ]] || { print -r -- "$log"; return 3; }
  }
  It 'stays off by default even when carapace is installed, leaving fzf-tab active'
    When run opt_in_default_case
    The status should be success
  End

  mutual_exclusion_case() {
    emulate -L zsh
    carapace_fixture
    stub_carapace
    print -r -- 'set completion-carapace.enable on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty -dic 'print -r -- "UI=$(completion-ui status) B=${CARAPACE_BRIDGES-unset} E=${CARAPACE_EXCLUDES-unset}"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out") log=$(<"$OPLOG")
    [[ $out == *READY* && $out == *'UI=completion-ui: active=carapace B=zsh,fish,bash E=unset'* ]] || { print -r -- "$out"; return 2; }
    [[ $log == *'CARAPACE_GEN:_carapace zsh|B=zsh,fish,bash|E=unset'* && $log == *'CARAPACE_INIT'* && $log != *'PLUGIN:fzf-tab'* ]] || { print -r -- "$log"; return 3; }
  }
  It 'activates carapace with default bridges and suppresses fzf-tab when enabled'
    When run mutual_exclusion_case
    The status should be success
  End

  explicit_module_list_case() {
    emulate -L zsh
    carapace_fixture
    stub_carapace
    printf 'module completion\nmodule completion-fzf-tab\nmodule completion-carapace\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty -dic 'print -r -- "UI=$(completion-ui status)"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out") log=$(<"$OPLOG")
    [[ $out == *'UI=completion-ui: active=carapace'* && $log == *'CARAPACE_INIT'* && $log != *'PLUGIN:fzf-tab'* ]] || { print -r -- "$out | $log"; return 2; }
    # An explicit option off still disables Carapace in an explicit module list.
    : > "$OPLOG"
    printf 'module completion\nmodule completion-fzf-tab\nmodule completion-carapace\nset completion-carapace.enable off\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty -dic 'print -r -- "UI=$(completion-ui status)"; print READY' || { cat "$TEST_ROOT/out"; return 3; }
    out=$(<"$TEST_ROOT/out"); log=$(<"$OPLOG")
    [[ $out == *'UI=completion-ui: active=fzf-tab'* && $log == *'PLUGIN:fzf-tab'* && $log != *'CARAPACE_'* ]] || { print -r -- "$out | $log"; return 4; }
  }
  It 'activates via explicit module listing and honors an explicit enable off override'
    When run explicit_module_list_case
    The status should be success
  End

  force_both_case() {
    emulate -L zsh
    carapace_fixture
    stub_carapace
    printf 'set completion-carapace.enable on\nset completion-carapace.allow_fzf_tab on\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty -dic 'print -r -- "UI=$(completion-ui status)"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out") log=$(<"$OPLOG")
    [[ $out == *READY* && $out == *'UI=completion-ui: active=both'* ]] || { print -r -- "$out"; return 2; }
    local seq=${(j: :)${(M)${(f)log}:#(PLUGIN:fzf-tab|CARAPACE_INIT)}}
    [[ $seq == 'PLUGIN:fzf-tab CARAPACE_INIT' ]] || { print -r -- "$log"; return 3; }
  }
  It 'loads both fzf-tab and carapace in order when the overlay forces both'
    When run force_both_case
    The status should be success
  End

  missing_binary_case() {
    emulate -L zsh
    carapace_fixture
    # No carapace binary on PATH, even though the overlay enables it.
    print -r -- 'set completion-carapace.enable on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty -dic 'print -r -- "UI=$(completion-ui status) B=${CARAPACE_BRIDGES-unset}"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out") log=$(<"$OPLOG")
    [[ $out == *READY* && $out == *'UI=completion-ui: active=fzf-tab B=unset'* ]] || { print -r -- "$out"; return 2; }
    [[ $out != *'not found'* && $out != *'error'* ]] || { print -r -- "$out"; return 3; }
    [[ $log == *'PLUGIN:fzf-tab'* && $log != *'CARAPACE_'* ]] || { print -r -- "$log"; return 4; }
  }
  It 'falls back silently to fzf-tab when the carapace binary is missing'
    When run missing_binary_case
    The status should be success
  End

  options_and_cache_case() {
    emulate -L zsh
    carapace_fixture
    stub_carapace
    printf 'set completion-carapace.enable on\nset completion-carapace.bridges "zsh bash"\nset completion-carapace.excludes "git, docker"\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty -dic 'print -r -- "B=${CARAPACE_BRIDGES-unset} E=${CARAPACE_EXCLUDES-unset}"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out") log=$(<"$OPLOG")
    [[ $out == *'B=zsh,bash E=git,docker'* && $log == *'CARAPACE_GEN:_carapace zsh|B=zsh,bash|E=git,docker'* ]] || { print -r -- "$out | $log"; return 2; }
    # Second shell with unchanged options hits init cache without spawning carapace again.
    : > "$OPLOG"
    carapace_pty -dic 'print -r -- "B=${CARAPACE_BRIDGES-unset} E=${CARAPACE_EXCLUDES-unset}"; print READY' || { cat "$TEST_ROOT/out"; return 3; }
    log=$(<"$OPLOG")
    [[ $log == *'CARAPACE_INIT'* && $log != *'CARAPACE_GEN:'* ]] || { print -r -- "$log"; return 4; }
    # Changing excludes invalidates the init cache and passes the new value; bridges off unsets CARAPACE_BRIDGES.
    : > "$OPLOG"
    printf 'set completion-carapace.enable on\nset completion-carapace.bridges off\nset completion-carapace.excludes "kubectl"\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty -dic 'print -r -- "B=${CARAPACE_BRIDGES-unset} E=${CARAPACE_EXCLUDES-unset}"; print READY' || { cat "$TEST_ROOT/out"; return 5; }
    out=$(<"$TEST_ROOT/out"); log=$(<"$OPLOG")
    [[ $out == *'B=unset E=kubectl'* && $log == *'CARAPACE_GEN:_carapace zsh|B=unset|E=kubectl'* ]] || { print -r -- "$out | $log"; return 6; }
  }
  It 'normalizes bridges and excludes, caches init on hits, and invalidates on option changes'
    When run options_and_cache_case
    The status should be success
  End

  switching_case() {
    emulate -L zsh
    carapace_fixture
    stub_carapace
    # Default overlay (fzf-tab): MARKSHARC_COMPLETION_UI=carapace activates carapace and suppresses fzf-tab.
    carapace_pty MARKSHARC_COMPLETION_UI=carapace -dic 'print -r -- "UI=$(completion-ui status)"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out") log=$(<"$OPLOG")
    [[ $out == *'UI=completion-ui: active=carapace override=carapace'* && $log == *'CARAPACE_INIT'* && $log != *'PLUGIN:fzf-tab'* ]] || { print -r -- "$out | $log"; return 2; }
    # Even with carapace enabled in config, MARKSHARC_COMPLETION_UI=fzf-tab switches back to fzf-tab.
    : > "$OPLOG"
    print -r -- 'set completion-carapace.enable on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty MARKSHARC_COMPLETION_UI=fzf-tab -dic 'print -r -- "UI=$(completion-ui status)"; print READY' || { cat "$TEST_ROOT/out"; return 3; }
    out=$(<"$TEST_ROOT/out"); log=$(<"$OPLOG")
    [[ $out == *'UI=completion-ui: active=fzf-tab override=fzf-tab'* && $log == *'PLUGIN:fzf-tab'* && $log != *'CARAPACE_'* ]] || { print -r -- "$out | $log"; return 4; }
    # MARKSHARC_COMPLETION_UI=both loads both; native disables both.
    : > "$OPLOG"
    carapace_pty MARKSHARC_COMPLETION_UI=both -dic 'print -r -- "UI=$(completion-ui status)"; print READY' || { cat "$TEST_ROOT/out"; return 5; }
    out=$(<"$TEST_ROOT/out"); log=$(<"$OPLOG")
    [[ $out == *'UI=completion-ui: active=both override=both'* && $log == *'PLUGIN:fzf-tab'* && $log == *'CARAPACE_INIT'* ]] || { print -r -- "$out | $log"; return 6; }
    : > "$OPLOG"
    carapace_pty MARKSHARC_COMPLETION_UI=native -dic 'print -r -- "UI=$(completion-ui status)"; print READY' || { cat "$TEST_ROOT/out"; return 7; }
    out=$(<"$TEST_ROOT/out"); log=$(<"$OPLOG")
    [[ $out == *'UI=completion-ui: active=native override=native'* && $log != *'PLUGIN:fzf-tab'* && $log != *'CARAPACE_'* ]] || { print -r -- "$out | $log"; return 8; }
    # MARKSHARC_COMPLETION_UI=carapace suppresses fzf-tab even when allow_fzf_tab is on in config.
    : > "$OPLOG"
    printf 'set completion-carapace.enable on\nset completion-carapace.allow_fzf_tab on\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty MARKSHARC_COMPLETION_UI=carapace -dic 'print -r -- "UI=$(completion-ui status)"; print READY' || { cat "$TEST_ROOT/out"; return 9; }
    out=$(<"$TEST_ROOT/out"); log=$(<"$OPLOG")
    [[ $out == *'UI=completion-ui: active=carapace override=carapace'* && $log == *'CARAPACE_INIT'* && $log != *'PLUGIN:fzf-tab'* ]] || { print -r -- "$out | $log"; return 10; }
  }
  It 'switches completion UI per session via MARKSHARC_COMPLETION_UI'
    When run switching_case
    The status should be success
  End

  helper_command_case() {
    emulate -L zsh
    carapace_fixture
    # Without carapace binary, switching to carapace fails with guidance.
    carapace_pty -dic 'completion-ui carapace; print -r -- "RC=$? OVERRIDE=${MARKSHARC_COMPLETION_UI-unset}"; completion-ui bogus; print -r -- "BAD=$?"' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'carapace is not installed'* && $out == *'RC=1 OVERRIDE=unset'* && $out == *'BAD=2'* ]] || { print -r -- "$out"; return 2; }
    # With carapace present, completion-ui exports MARKSHARC_COMPLETION_UI, suggests exec zsh -l, and reset clears it.
    stub_carapace
    carapace_pty -dic 'completion-ui carapace; print -r -- "AFTER=${MARKSHARC_COMPLETION_UI-unset}"; completion-ui reset; print -r -- "CLEARED=${MARKSHARC_COMPLETION_UI-unset}"' || { cat "$TEST_ROOT/out"; return 3; }
    out=$(<"$TEST_ROOT/out")
    [[ $out == *"exec zsh -l"* && $out == *'AFTER=carapace'* && $out == *'CLEARED=unset'* ]] || { print -r -- "$out"; return 4; }
  }
  It 'provides completion-ui to inspect, switch with exec zsh -l guidance, and reset'
    When run helper_command_case
    The status should be success
  End

  reload_and_exec_cleanup_case() {
    emulate -L zsh
    carapace_fixture
    stub_carapace
    printf 'set completion-carapace.enable on\nset completion-carapace.excludes git\n' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty -dic 'eval cs >/dev/null 2>&1; print -r -- "UI=$(completion-ui status) B=${CARAPACE_BRIDGES-unset} E=${CARAPACE_EXCLUDES-unset}"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out") log=$(<"$OPLOG")
    [[ $out == *'UI=completion-ui: active=carapace B=zsh,fish,bash E=git'* ]] || { print -r -- "$out"; return 2; }
    [[ $(grep -c '^CARAPACE_INIT$' "$OPLOG") == 1 ]] || { print -r -- "$log"; return 3; }
    # Simulating exec zsh -l after switching off clears stale inherited module-owned exports.
    print -r -- 'module completion-carapace off' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_pty MARKSHARC_CARAPACE_ACTIVE=1 CARAPACE_BRIDGES=zsh CARAPACE_EXCLUDES=git -dic 'print -r -- "B=${CARAPACE_BRIDGES-unset} E=${CARAPACE_EXCLUDES-unset} A=${MARKSHARC_CARAPACE_ACTIVE-unset}"; print READY' || { cat "$TEST_ROOT/out"; return 4; }
    out=$(<"$TEST_ROOT/out")
    [[ $out == *'B=unset E=unset A=unset'* ]] || { print -r -- "$out"; return 5; }
  }
  It 'does not re-run carapace on reload and clears inherited exports after switching off'
    When run reload_and_exec_cleanup_case
    The status should be success
  End

  batch_agent_quiet_case() {
    emulate -L zsh
    carapace_fixture
    stub_carapace
    print -r -- 'set completion-carapace.enable on' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    carapace_run -c 'print -r -- "B=${CARAPACE_BRIDGES-unset}"' || return 1
    [[ $(<"$TEST_ROOT/out") == 'B=unset' && ! -s $TEST_ROOT/err && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err" "$OPLOG"; return 2; }
    carapace_run CLAUDECODE=1 -ic 'print -r -- "B=${CARAPACE_BRIDGES-unset}"' || return 3
    [[ $(<"$TEST_ROOT/out") == 'B=unset' && ! -s $TEST_ROOT/err && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err" "$OPLOG"; return 4; }
  }
  It 'stays silent and skips carapace in batch and agent shells'
    When run batch_agent_quiet_case
    The status should be success
  End
End
