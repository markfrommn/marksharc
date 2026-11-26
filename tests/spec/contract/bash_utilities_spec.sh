Describe 'Bash utility modules'
  utility_case() {
    config="$HOME/utility config"
    mkdir -p "$config" "$TEST_ROOT/bin"
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$config" MARKSHARC_NOTIFY=0
    cat > "$HOME/.bashrc" <<'EOF'
# Some platforms install a command-not-found handler before MarkSharc starts.
command_not_found_handle() { printf 'foreign handler: %s\n' "$1"; }
source "$MARKSHARC_HOME/core/bash/bashrc.bash"
EOF
    printf '%s\n' 'module prompt-starship off' 'module history-atuin off' 'module zoxide off' \
      'set theme.delta on' 'set editor.command "custom editor"' > "$config/config.conf"
    stub_command eza ':'
    stub_command emacs ':'
    stub_command less 'cat'
    stub_command vivid 'echo vivid >> "$TEST_ROOT/vivid-log"; echo "di=blue"'
    stub_command bat ':'
    stub_command col ':'
    stub_command delta ':'
    stub_command fd ':'
    stub_command ps 'printf "  PID PPID USER STAT ELAPSED COMMAND\n  42 1 me S 00:01 sshd\n"'
    stub_command procs 'printf "%s\n" "$*"'
    stub_command herdr 'case "$*" in "completion zsh") printf "#compdef herdr\n" ;; "session list") printf "SESSION STATE PID SOCKET\n" ;; *) exit 99 ;; esac'
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" -ic '
      [[ $EDITOR == "custom editor" && $LESS == -FRX && $LS_COLORS == di=blue ]] || { declare -p EDITOR LESS LS_COLORS; exit 10; }
      [[ $MANPAGER == "sh -c '\''col -bx | bat -l man -p'\''" && $GIT_CONFIG_KEY_0 == include.path ]] || exit 11
      [[ ${BASH_ALIASES[ll]} == "eza -lA" && -z ${BASH_ALIASES[ls]+x} ]] || exit 12
      declare -F command_not_found_handle >/dev/null &&
        [[ $(declare -f command_not_found_handle) != *"foreign handler:"* ]] || exit 26
      [[ $(pss sshd) == "--or 42" && $(pssuj sshd) == "--insert Ppid --insert Pgid --insert State --or 42" ]] || exit 13
      _ms_opt_ps_procs=off
      [[ $(pss sshd) == *sshd* ]] || exit 14
      EDITOR=user-editor
      alias ll="printf user"
      printf "%s\n" "module ls off" "module ps off" "module pager off" "module editor off" "module theme off" "module command-not-found off" "module prompt-starship off" "module history-atuin off" "module zoxide off" > "$MARKSHARC_CONFIG/config.conf"
      marksharc reload || exit 15
      [[ $EDITOR == user-editor && ${BASH_ALIASES[ll]} == "printf user" ]] || exit 16
      [[ -z ${LS_COLORS+x} && -z ${GIT_CONFIG_COUNT+x} && -z ${LESS+x} ]] || exit 17
      if declare -F pss >/dev/null || declare -F diffcp >/dev/null; then exit 18; fi
      [[ $(command_not_found_handle fixture-command) == "foreign handler: fixture-command" ]] || exit 27
      printf "%s\n" "module theme on" "set theme.delta on" "module prompt-starship off" "module history-atuin off" "module zoxide off" > "$MARKSHARC_CONFIG/config.conf"
      marksharc reload || exit 19
      export GIT_CONFIG_KEY_1=user.key GIT_CONFIG_VALUE_1=user-value GIT_CONFIG_COUNT=2
      marksharc reload || exit 22
      marksharc reload || exit 23
      [[ $GIT_CONFIG_COUNT == 2 && $GIT_CONFIG_KEY_0 == include.path && $GIT_CONFIG_KEY_1 == user.key ]] || exit 24
      printf "%s\n" "module theme off" "module prompt-starship off" "module history-atuin off" "module zoxide off" > "$MARKSHARC_CONFIG/config.conf"
      marksharc reload || exit 20
      [[ $GIT_CONFIG_COUNT == 2 && $GIT_CONFIG_KEY_0 == include.path && $GIT_CONFIG_KEY_1 == user.key ]] || exit 21
    ' > "$TEST_ROOT/out" 2>&1 || { status=$?; cat "$TEST_ROOT/out"; return "$status"; }
    [ "$(wc -l < "$TEST_ROOT/vivid-log")" -eq 1 ]
  }
  It 'loads optional tools, honors ps settings, and retires owned state on reload'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run utility_case
    The status should be success
  End

  delta_counts_case() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT"
    stub_command delta ':'
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_HOME/core/bash/ownership.bash"
      _ms_bash_register_cleanup() { :; }
      _ms_opt_theme_delta=on _ms_opt_theme_ls_colors=off _ms_opt_theme_fzf=off _ms_opt_theme_man_pager=off
      theme=$MARKSHARC_HOME/modules/theme/init.bash
      ( export GIT_CONFIG_COUNT=08; source "$theme"; [[ $GIT_CONFIG_COUNT == 9 && $GIT_CONFIG_KEY_8 == include.path ]] ) || exit 1
      ( export GIT_CONFIG_COUNT=bad; source "$theme"; [[ $GIT_CONFIG_COUNT == bad && -z ${GIT_CONFIG_KEY_0+x} ]] ) || exit 2
      ( export GIT_CONFIG_COUNT=100000; source "$theme"; [[ $GIT_CONFIG_COUNT == 100000 && -z ${GIT_CONFIG_KEY_100000+x} ]] ) || exit 3
      ( export GIT_CONFIG_COUNT=0 GIT_CONFIG_KEY_0=user; source "$theme"; [[ $GIT_CONFIG_COUNT == 0 && $GIT_CONFIG_KEY_0 == user && -z ${GIT_CONFIG_VALUE_0+x} ]] ) || exit 4
      ( readonly GIT_CONFIG_COUNT=0; source "$theme"; [[ $GIT_CONFIG_COUNT == 0 && -z ${GIT_CONFIG_KEY_0+x} && -z ${GIT_CONFIG_VALUE_0+x} ]] ) || exit 5
      ( _ms_bash_replaced[variable:GIT_CONFIG_VALUE_0]=1; source "$theme"; [[ -z ${GIT_CONFIG_COUNT+x} && -z ${GIT_CONFIG_KEY_0+x} ]] ) || exit 6
    '
  }
  It 'handles decimal counts and skips unsafe Git state without partial exports'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    When run delta_counts_case
    The status should be success
  End

  missing_tools_case() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT"
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_HOME/core/bash/ownership.bash"
      PATH=/nonexistent MARKSHARC_OS=darwin
      source "$MARKSHARC_HOME/modules/editor/init.bash"
      source "$MARKSHARC_HOME/modules/ls/init.bash"
      _ms_opt_theme_delta=on
      source "$MARKSHARC_HOME/modules/theme/init.bash"
      [[ $EDITOR == vi && ${BASH_ALIASES[ls]} == "ls -G" ]] || exit 1
      [[ -z ${LS_COLORS+x} && -z ${MANPAGER+x} && -z ${GIT_CONFIG_COUNT+x} ]] || exit 2
      [[ $FZF_CTRL_T_OPTS == "--preview '\''head -n 300 {}'\''" ]] || exit 3
    '
  }
  It 'keeps usable native defaults without optional tools'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    When run missing_tools_case
    The status should be success
  End
End
