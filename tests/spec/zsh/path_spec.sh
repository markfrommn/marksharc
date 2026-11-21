Describe 'path module: tiered PATH builder'
  # Unit-style: the module file runs under zsh -f with preset facts and a fixture
  # directory tree. System paths are probed under _ms_fs_root; paths below HOME as they are.
  path_layout() {
    local root="$TEST_ROOT/root"
    mkdir -p "$root"/{bin,usr/bin,sbin,usr/sbin,usr/local/bin,opt/homebrew/bin,opt/homebrew/sbin,opt/bin}
    mkdir -p "$HOME"/{bin/bin.Darwin.arm64,bin/bin.Linux.x86_64,.local/bin,.krew/bin,.opencode/bin}
  }
  PRE='source "$MARKSHARC_HOME/modules/path/env.zsh"; _ms_opt_core_dot_in_path=${_ms_opt_core_dot_in_path-on}'
  show() { print -r -- "GOT:"; print -l -- "$@"; }
  golden_macos_case() {
    emulate -L zsh
    path_layout
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root
      path=( /usr/bin /bin )
      $PRE
      _ms_path_add brew /opt/homebrew/bin /opt/homebrew/sbin
      _ms_path_finalize
      print -l -- \"\$path[@]\"" || return 1
    local -a want=( /opt/homebrew/bin /opt/homebrew/sbin /usr/local/bin /opt/bin "$HOME/.opencode/bin" /bin /usr/bin /sbin /usr/sbin
      "$HOME/bin" "$HOME/bin/bin.Darwin.arm64" "$HOME/.local/bin" "$HOME/.krew/bin" . )
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ "${(j:|:)got}" == "${(j:|:)want}" ]] || { show $got; print -r -- WANT:; print -l -- $want; cat "$TEST_ROOT/err"; return 2; }
  }
  It 'builds the macOS tier order from a directory-layout fixture'
    When run golden_macos_case
    The status should be success
  End
  golden_linux_case() {
    emulate -L zsh
    path_layout
    mkdir -p "$TEST_ROOT/root/usr/local/cuda/bin"
    ms_unit "ostype=Linux hwtype=x86_64 MARKSHARC_OS=linux uid=1000 _ms_fs_root=$TEST_ROOT/root
      path=( /usr/bin /bin )
      $PRE
      _ms_path_add app /usr/local/cuda/bin
      _ms_path_finalize
      print -l -- \"\$path[@]\"" || return 1
    # Linux keeps today's order: local after user and app.
    local -a want=( /bin /usr/bin /sbin /usr/sbin "$HOME/bin" "$HOME/bin/bin.Linux.x86_64" "$HOME/.local/bin" "$HOME/.krew/bin"
      /usr/local/cuda/bin /usr/local/bin /opt/bin "$HOME/.opencode/bin" . )
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ "${(j:|:)got}" == "${(j:|:)want}" ]] || { show $got; print -r -- WANT:; print -l -- $want; cat "$TEST_ROOT/err"; return 2; }
  }
  It 'builds the Linux tier order from a directory-layout fixture'
    When run golden_linux_case
    The status should be success
  End
  golden_linux_modules_case() {
    emulate -L zsh
    path_layout
    mkdir -p "$TEST_ROOT/root/usr/local/cuda/bin" "$TEST_ROOT/root/home/linuxbrew/.linuxbrew/bin" "$TEST_ROOT/root/home/linuxbrew/.linuxbrew/sbin" "$TEST_ROOT/root/opt/dell/bin" "$HOME/.lmstudio/bin" "$HOME/mgr-nvm" "$HOME/mgr-gvm"
    mkdir -p "$TEST_ROOT/root/dev"; : > "$TEST_ROOT/root/dev/nvidiactl"
    rm -rf "$TEST_ROOT/root/opt/homebrew"   # a Linux host has no /opt/homebrew
    ms_unit "ostype=Linux hwtype=x86_64 MARKSHARC_OS=linux uid=1000 _ms_fs_root=$TEST_ROOT/root
      path=( /usr/bin /bin )
      $PRE
      source \"\$MARKSHARC_HOME/modules/brew/env.zsh\"
      _ms_path_add manager $HOME/mgr-nvm $HOME/mgr-gvm
      source \"\$MARKSHARC_HOME/modules/cuda/env.zsh\"
      source \"\$MARKSHARC_HOME/modules/lmstudio/env.zsh\"
      _ms_path_finalize
      print -l -- \"\$path[@]\"" || return 1
    # Today's Linux order: managers, system, user, app (CUDA, LM Studio), then local
    # (/usr/local, /opt, Linuxbrew, /opt/dell, opencode), then the dot.
    local -a want=( "$HOME/mgr-nvm" "$HOME/mgr-gvm" /bin /usr/bin /sbin /usr/sbin "$HOME/bin" "$HOME/bin/bin.Linux.x86_64" "$HOME/.local/bin" "$HOME/.krew/bin"
      /usr/local/cuda/bin "$HOME/.lmstudio/bin" /usr/local/bin /opt/bin /home/linuxbrew/.linuxbrew/bin /home/linuxbrew/.linuxbrew/sbin "$HOME/.opencode/bin" . )
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ "${(j:|:)got}" == "${(j:|:)want}" ]] || { show $got; print -r -- WANT:; print -l -- $want; cat "$TEST_ROOT/err"; return 2; }
  }
  It 'keeps the old Linux order with managers, Linuxbrew, LM Studio and CUDA from their modules'
    When run golden_linux_modules_case
    The status should be success
  End
  placement_case() {
    emulate -L zsh
    path_layout
    mkdir -p "$HOME/venv/bin" "$HOME/tool-after" "$HOME/over" "$HOME/mgr"
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root
      path=( $HOME/venv/bin /usr/bin /bin $HOME/tool-after )
      $PRE
      _ms_path_add first $HOME/over
      _ms_path_add manager $HOME/mgr
      _ms_path_add brew /opt/homebrew/bin
      _ms_path_finalize
      print -l -- \"\$path[@]\"" || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    # first, inherited-before, manager, brew, ..., inherited-after, last
    [[ $got[1] == "$HOME/over" && $got[2] == "$HOME/venv/bin" && $got[3] == "$HOME/mgr" && $got[4] == /opt/homebrew/bin ]] || { show $got; return 2; }
    [[ $got[-1] == . && $got[-2] == "$HOME/tool-after" ]] || { show $got; return 3; }
    local -a dupes=( ${(M)got:#/usr/bin} ${(M)got:#/bin} )
    (( $#dupes == 2 )) || { show $got; return 4; }
  }
  It 'places first, inherited-before, manager, brew, inherited-after and last entries and deduplicates'
    When run placement_case
    The status should be success
  End
  reload_case() {
    emulate -L zsh
    path_layout
    mkdir -p "$HOME/vanishing" "$HOME/tool-new"
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root
      path=( /usr/bin /bin )
      $PRE
      _ms_path_add user $HOME/vanishing
      _ms_path_finalize
      [[ \$PATH == *vanishing* ]] || exit 11
      # A tool prepends a directory and appends another after the managed block.
      path=( $HOME/tool-new \"\$path[@]\" /tool-suffix )
      rm -r $HOME/vanishing
      # A reload: the module runs again (the vanished directory is not contributed).
      $PRE
      _ms_path_finalize
      [[ \$PATH != *vanishing* ]] || exit 12
      [[ \$path[1] == $HOME/tool-new ]] || exit 13
      [[ \$path[-2] == /tool-suffix && \$path[-1] == . ]] || exit 14
      print ok" || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 1; }
  }
  It 'keeps unmanaged entries and drops vanished managed directories on reload'
    When run reload_case
    The status should be success
  End
  dot_case() {
    emulate -L zsh
    path_layout
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=0 _ms_fs_root=$TEST_ROOT/root
      path=( /usr/bin . /bin '' )
      $PRE
      _ms_path_finalize
      print -r -- \"\${(j:|:)path}\"" || return 1
    [[ $(<"$TEST_ROOT/out") != *'|.|'* && $(<"$TEST_ROOT/out") != *'|.' && $(<"$TEST_ROOT/out") != *'||'* ]] || { cat "$TEST_ROOT/out"; return 2; }
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root _ms_opt_core_dot_in_path=off
      path=( /usr/bin /bin . )
      $PRE
      _ms_path_finalize
      print -r -- \"\${(j:|:)path}\"" || return 3
    [[ $(<"$TEST_ROOT/out") != *'|.'* && $(<"$TEST_ROOT/out") != '.|'* ]] || { cat "$TEST_ROOT/out"; return 4; }
  }
  It 'excludes . for root and when dot_in_path is off, and drops empty entries'
    When run dot_case
    The status should be success
  End
  spaced_case() {
    emulate -L zsh
    path_layout
    mkdir -p "$HOME/my tools/bin" "$HOME/inherited space"
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root
      path=( '$HOME/inherited space' /usr/bin /bin )
      $PRE
      _ms_path_add_bindirs user '$HOME/my tools'
      _ms_path_finalize
      print -l -- \"\$path[@]\"" || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ $got[1] == "$HOME/inherited space" && ${got[(Ie)$HOME/my tools/bin]} -gt 0 ]] || { show $got; return 2; }
  }
  It 'preserves spaces in contributed and inherited directories'
    When run spaced_case
    The status should be success
  End
  rebuild_zero_case() {
    emulate -L zsh
    path_layout
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root
      path=( /usr/bin /bin ); first=\$PATH
      _ms_env_rebuild=0
      $PRE
      _ms_path_add user $HOME/bin
      _ms_path_finalize
      [[ \$PATH == \$first && \${#_ms_path_tier_user} == 0 ]] && print inherited" || return 1
    [[ $(<"$TEST_ROOT/out") == inherited ]]
  }
  It 'leaves an inherited PATH alone when the env phase does not rebuild'
    When run rebuild_zero_case
    The status should be success
  End
  legacy_dirs_case() {
    emulate -L zsh
    path_layout
    local d
    for d in usr/X11R6/bin usr/ucb usr/openwin/bin opt/openwin/bin usr/xpg4/bin usr/ccs/bin; do mkdir -p "$TEST_ROOT/root/$d"; done
    # Inherited user entries survive; the removed legacy directories are never generated.
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root
      path=( /usr/bin /bin /usr/X11R6/bin /usr/ucb )
      $PRE
      _ms_path_finalize
      first=\$PATH
      path=( /usr/bin /bin )
      $PRE
      _ms_path_finalize
      print -l -- \"\$path[@]\"
      print -r -- \"FIRST=\$first\"" || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ $got[-1] == *'/usr/X11R6/bin:/usr/ucb'* ]] || { show $got; return 2; }
    for d in /usr/X11R6/bin /usr/ucb /usr/openwin/bin /opt/openwin/bin /usr/xpg4/bin /usr/ccs/bin; do
      (( ${got[1,-2][(Ie)$d]} == 0 )) || { show $got; return 3; }
    done
  }
  It 'omits legacy generated paths while retaining inherited entries'
    When run legacy_dirs_case
    The status should be success
  End
  tiers_option_case() {
    emulate -L zsh
    path_layout
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root _ms_opt_path_tiers='first system local user brew'
      path=( /usr/bin /bin )
      $PRE
      _ms_path_add brew /opt/homebrew/bin
      _ms_path_finalize
      print -l -- \"\$path[@]\"" || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    (( ${got[(Ie)/opt/homebrew/bin]} > ${got[(Ie)$HOME/bin]} )) || { show $got; return 2; }
  }
  It 'lets the tiers option override the order'
    When run tiers_option_case
    The status should be success
  End
  last_tier_case() {
    emulate -L zsh
    path_layout
    mkdir -p "$HOME/lastdir"
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root
      path=( /usr/bin /bin $HOME/tool-after )
      $PRE
      _ms_path_add last $HOME/lastdir
      _ms_path_finalize
      print -l -- \"\$path[@]\"" || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ $got[-1] == . && $got[-2] == "$HOME/lastdir" ]] || { show $got; return 2; }
  }
  It 'lands last-tier directories before the dot'
    When run last_tier_case
    The status should be success
  End
  tiers_omitted_case() {
    emulate -L zsh
    path_layout
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501 _ms_fs_root=$TEST_ROOT/root _ms_opt_path_tiers='first system'
      path=( /usr/bin /bin )
      $PRE
      _ms_path_add brew /opt/homebrew/bin
      _ms_path_add manager /usr/local/bin
      _ms_path_finalize
      print -l -- \"\$path[@]\"" || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    # Listed tiers come first; a tier the option omits follows in the default order, so
    # nothing a module contributed (and _ms_command_pending can see) is dropped.
    (( ${got[(Ie)/bin]} > 0 && ${got[(Ie)/bin]} < ${got[(Ie)/usr/local/bin]} && ${got[(Ie)/usr/local/bin]} < ${got[(Ie)/opt/homebrew/bin]} && ${got[(Ie)$HOME/bin]} > ${got[(Ie)/bin]} )) || { show $got; return 2; }
  }
  It 'appends tiers that a tiers option omits, in the default order'
    When run tiers_omitted_case
    The status should be success
  End
  pending_case() {
    emulate -L zsh
    mkdir -p "$HOME/pend/bin"; printf '#!/bin/sh\n' > "$HOME/pend/bin/pendtool"; chmod +x "$HOME/pend/bin/pendtool"
    ms_unit "ostype=Darwin hwtype=arm64 MARKSHARC_OS=darwin uid=501
      path=( /usr/bin /bin )
      $PRE
      _ms_command_pending pendtool && exit 11
      _ms_path_add brew $HOME/pend/bin
      _ms_command_pending pendtool || exit 12
      _ms_command_pending /usr/bin/env || exit 13
      _ms_command_pending nosuchtool-xyz && exit 14
      print ok" || { cat "$TEST_ROOT/err"; return 1; }
    [[ $(<"$TEST_ROOT/out") == ok ]]
  }
  It 'finds a command in a PATH directory that is only pending in a tier'
    When run pending_case
    The status should be success
  End
End

Describe 'core hooks for the path module'
  finalizer_case() {
    emulate -L zsh
    ms_fixture
    ms_mod aa module.conf $'describe "aa"\norder 10'
    ms_mod aa env.zsh 'print -r -- aa:env >> "$OPLOG"; _ms_env_finalizers+=( aa_fin ); aa_fin() { print -r -- aa:fin >> "$OPLOG"; }'
    ms_mod zz module.conf $'describe "zz"\norder 90'
    ms_mod zz env.zsh 'print -r -- zz:env >> "$OPLOG"; _ms_env_finalizers+=( zz_fin ); zz_fin() { print -r -- zz:fin >> "$OPLOG"; false; }'
    ms_run -c ':' || return 1
    [[ $(<"$OPLOG") == $'aa:env\nzz:env\naa:fin\nzz:fin' && ! -s $TEST_ROOT/err ]] || { cat "$OPLOG" "$TEST_ROOT/err"; return 2; }
    # A failing finalizer does not stop the shell, and reload does not register twice.
    : > "$OPLOG"
    ms_pty -dic 'eval cs; print READY' || return 3
    [[ $(grep -c '^aa:fin$' "$OPLOG") == 2 ]] || { cat "$OPLOG"; return 4; }
  }
  It 'runs env finalizers once, after every env-phase module'
    When run finalizer_case
    The status should be success
  End
  requires_after_brew_case() {
    emulate -L zsh
    ms_fixture
    ms_copy_module path
    mkdir -p "$HOME/brewprefix/bin"
    printf '#!/bin/sh\n' > "$HOME/brewprefix/bin/brewtool"; chmod +x "$HOME/brewprefix/bin/brewtool"
    ms_mod brewish module.conf $'describe "brewish"\norder 10'
    ms_mod brewish env.zsh '_ms_path_add brew "$HOME/brewprefix/bin"'
    ms_mod needs module.conf $'describe "needs"\norder 50\nrequires command brewtool'
    ms_mod needs env.zsh 'print -r -- needs:env >> "$OPLOG"'
    ms_mod needs-missing module.conf $'describe "nm"\norder 50\nrequires command nosuchtool-xyz'
    ms_mod needs-missing env.zsh 'print -r -- missing:env >> "$OPLOG"'
    # A minimal PATH that does not hold the Homebrew-style directory.
    ms_run PATH=/usr/bin:/bin MARKSHARC_VERBOSE=1 -c 'print -r -- "$commands[brewtool]"' || return 1
    [[ $(<"$OPLOG") == needs:env ]] || { cat "$OPLOG" "$TEST_ROOT/err"; return 2; }
    [[ $(<"$TEST_ROOT/err") == *'module needs-missing: skipped (requires command nosuchtool-xyz)'* ]] || { cat "$TEST_ROOT/err"; return 3; }
    # The final PATH holds the contributed directory, so the tool is found afterwards.
    [[ $(<"$TEST_ROOT/out") == "$HOME/brewprefix/bin/brewtool" ]] || { cat "$TEST_ROOT/out"; return 4; }
  }
  It 'checks requires command at the module turn, after brew contributed its directories'
    When run requires_after_brew_case
    The status should be success
  End
End
