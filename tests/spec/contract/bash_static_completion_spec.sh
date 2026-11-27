Describe 'Bash declarative completions'
  Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable

  render_declarative_fixture() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_HOST=fixture
    config="$XDG_CONFIG_HOME/marksharc"
    mkdir -p "$config/modules/custom-mod"
    cat > "$config/config.conf" <<'EOF'
module launch
module cwf
module custom-mod
EOF
    cat > "$config/hosts.conf" <<'EOF'
host alpha ops@alpha
host builder ops@builder
EOF
    cat > "$config/modules/custom-mod/module.conf" <<'EOF'
describe "Custom overlay module"
installer demo-tool ./install.sh
update custom-step echo ok
EOF
    printf '#!/bin/sh\nexit 0\n' > "$config/modules/custom-mod/install.sh"
    chmod +x "$config/modules/custom-mod/install.sh"
    HOST=fixture "$MARKSHARC_HOME/bin/marksharc" render >/dev/null
  }

  static_candidates() {
    render_declarative_fixture || return
    inventory="$XDG_CACHE_HOME/marksharc/fixture/repos"
    compdir="$XDG_CACHE_HOME/marksharc/fixture/completions/bash"
    mkdir -p "$inventory" "$TEST_ROOT/dir space'quote" "$TEST_ROOT/project"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "api team's" "/repos/api team's" base "/repos/api team's" '' \
      "review copy's" "/worktrees/review copy's" worktree "/repos/api team's" 'review/changes' \
      'other review' '/worktrees/other review' worktree '/repos/unrelated' 'review/other' > "$inventory/builder.tsv"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      'alpha' '/repos/alpha' base '/repos/alpha' 'main' \
      'wt1' '/worktrees/wt1' worktree '/repos/alpha' 'feat' > "$inventory/local.tsv"
    git -C "$TEST_ROOT/project" init -q || return
    git -C "$TEST_ROOT/project" -c user.name=Test -c user.email=test@example.invalid commit -qm initial --allow-empty || return
    git -C "$TEST_ROOT/project" branch review/changes || return
    COMPDIR="$compdir" "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$COMPDIR/launch-repo.bash"
      source "$COMPDIR/launch-session.bash"
      source "$COMPDIR/cwf-new.bash"
      source "$COMPDIR/marksharc.bash"
      cd "$TEST_ROOT" || exit 1
      COMP_WORDS=(launch-session --pwd "dir\\ sp") COMP_CWORD=2
      _ms_complete_launch_session launch-session "" --pwd
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == "dir space'"'"'quote" ]] || exit 2
      COMP_WORDS=(launch-repo builder : api) COMP_CWORD=3
      _ms_complete_launch_repo launch-repo api :
      [[ ${#COMPREPLY[@]} == 3 && ${COMPREPLY[0]} == "api team'"'"'s" ]] || exit 3
      COMP_WORDS=(launch-repo --host builder --repo "\"api team'"'"'s\"" --worktree review) COMP_CWORD=6
      _ms_complete_launch_repo launch-repo review --worktree
      [[ ${#COMPREPLY[@]} == 2 && ${COMPREPLY[0]} == "review copy'"'"'s" && ${COMPREPLY[1]} == review/changes ]] || exit 4
      COMP_WORDS=(launch-repo --base-only al) COMP_CWORD=2
      _ms_complete_launch_repo launch-repo al --base-only
      [[ " ${COMPREPLY[*]} " == *" alpha "* && " ${COMPREPLY[*]} " != *" alpha/wt1 "* && " ${COMPREPLY[*]} " != *" alpha/feat "* ]] || exit 5
      COMP_WORDS=(launch-repo --host builder api) COMP_CWORD=3
      _ms_complete_launch_repo launch-repo api builder
      [[ ${#COMPREPLY[@]} == 0 ]] || exit 6
      COMP_WORDS=(cwf-new --host builder --repo api) COMP_CWORD=4
      _ms_complete_cwf_new cwf-new api --repo
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == "api team'"'"'s" ]] || exit 7
      cd "$TEST_ROOT/project" || exit 8
      COMP_WORDS=(cwf-new --place tab rev) COMP_CWORD=3
      _ms_complete_cwf_new cwf-new rev tab
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == review/changes ]] || exit 9

      # Rendered marksharc command hierarchy, flags, choices, and dynamic candidates
      COMP_WORDS=(marksharc "") COMP_CWORD=1
      _ms_complete_marksharc marksharc ""
      [[ ${#COMPREPLY[@]} == 13 && " ${COMPREPLY[*]} " == *" reload "* && " ${COMPREPLY[*]} " == *" install "* ]] || exit 10
      COMP_WORDS=(marksharc --v) COMP_CWORD=1
      _ms_complete_marksharc marksharc --v
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == --version ]] || exit 11
      COMP_WORDS=(marksharc doctor --v) COMP_CWORD=2
      _ms_complete_marksharc marksharc --v doctor
      [[ ${#COMPREPLY[@]} == 0 ]] || exit 12
      COMP_WORDS=(marksharc sync timer "") COMP_CWORD=3
      _ms_complete_marksharc marksharc "" timer
      [[ "${COMPREPLY[*]}" == "on off status" ]] || exit 13
      COMP_WORDS=(marksharc hosts populate --source "") COMP_CWORD=4
      _ms_complete_marksharc marksharc "" --source
      [[ "${COMPREPLY[*]}" == "ssh hc all" ]] || exit 14
      COMP_WORDS=(marksharc hosts remove al) COMP_CWORD=3
      _ms_complete_marksharc marksharc al remove
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == alpha ]] || exit 15
      COMP_WORDS=(marksharc module enable custom-) COMP_CWORD=3
      _ms_complete_marksharc marksharc custom- enable
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == custom-mod ]] || exit 16
      COMP_WORDS=(marksharc install demo-) COMP_CWORD=2
      _ms_complete_marksharc marksharc demo- install
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == demo-tool ]] || exit 17
      COMP_WORDS=(marksharc update --only custom-) COMP_CWORD=3
      _ms_complete_marksharc marksharc custom- --only
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == custom-step ]] || exit 18
      COMP_WORDS=(marksharc push bu) COMP_CWORD=2
      _ms_complete_marksharc marksharc bu push
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == builder ]] || exit 19
    '
  }
  It 'preserves literal paths, repository names, worktree names, branch names, and completes the marksharc hierarchy'
    When run static_candidates
    The status should be success
  End

  quoted_completion() {
    render_declarative_fixture || return
    export INPUTRC=/dev/null TERM=dumb
    inventory="$XDG_CACHE_HOME/marksharc/fixture/repos"
    compdir="$XDG_CACHE_HOME/marksharc/fixture/completions/bash"
    mkdir -p "$TEST_ROOT/dir space'quote" "$inventory"
    printf '%s\t%s\t%s\t%s\t\n' "api team's" "/repos/api team's" base "/repos/api team's" > "$inventory/builder.tsv"
    cd "$TEST_ROOT" || return
    cat > "$HOME/.bashrc" <<EOF
PS1='' PS2=''
source "$compdir/launch-session.bash"
source "$compdir/launch-repo.bash"
launch-session() { printf 'ARG:<%s>\n' "\$@"; }
launch-repo() { printf 'ARG:<%s>\n' "\$@"; }
EOF
    PTY_INPUT=$(printf 'launch-session --pwd "dir sp\t\nlaunch-repo "builder:api te\t\nexit\n')
    PTY_INPUT="$PTY_INPUT
" "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" -i \
      > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
    grep -Fx -e "ARG:<dir space'quote/>" -e "ARG:<builder:api team's>" "$TEST_ROOT/out" || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'inserts quoted directory and remote repository names as single Readline arguments'
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run quoted_completion
    The status should be success
    The line 1 of output should equal "ARG:<dir space'quote/>"
    The line 2 of output should equal "ARG:<builder:api team's>"
  End

  interactive_loading_and_reload() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config" MARKSHARC_NOTIFY=0
    mkdir -p "$MARKSHARC_CONFIG"
    printf 'module path\nmodule launch\nmodule cwf\n' > "$MARKSHARC_CONFIG/config.conf"
    printf '%s\n' 'source "$MARKSHARC_HOME/core/bash/bashrc.bash"' > "$HOME/.bashrc"
    "$MARKSHARC_HOME/bin/marksharc" render >/dev/null || return 1
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" -ic '
      [[ $(complete -p marksharc) == *"-F _ms_complete_marksharc marksharc" ]] || exit 10
      [[ $(complete -p launch-session) == *"-F _ms_complete_launch_session launch-session" ]] || exit 11
      [[ $(complete -p launch-repo) == *"-F _ms_complete_launch_repo launch-repo" ]] || exit 12
      [[ $(complete -p cwf-new) == *"-F _ms_complete_cwf_new cwf-new" ]] || exit 13
      printf "module path\nmodule launch off\nmodule cwf off\n" > "$MARKSHARC_CONFIG/config.conf"
      marksharc reload >/dev/null || exit 14
      [[ $(complete -p marksharc) == *"-F _ms_complete_marksharc marksharc" ]] || exit 15
      ! complete -p launch-session >/dev/null 2>&1 || exit 16
      ! complete -p launch-repo >/dev/null 2>&1 || exit 17
      ! complete -p cwf-new >/dev/null 2>&1 || exit 18
    ' > "$TEST_ROOT/out" 2>&1 || { status=$?; cat "$TEST_ROOT/out"; return "$status"; }
  }
  It 'loads rendered completions in interactive Bash and cleans up disabled module completions on reload'
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run interactive_loading_and_reload
    The status should be success
  End

  generated_completion() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config with spaces" MARKSHARC_NOTIFY=0
    mkdir -p "$MARKSHARC_CONFIG"
    export COMMON_DEV_TOOLS="$TEST_ROOT"
    printf 'module path\nmodule herdr\nmodule cwf\n' > "$MARKSHARC_CONFIG/config.conf"
    printf '%s\n' 'source "$MARKSHARC_HOME/core/bash/bashrc.bash"' > "$HOME/.bashrc"
    stub_command herdr 'case "$*" in
      "completion zsh") printf "#compdef herdr\n" ;;
      "completion bash")
        printf "bash generator\n" >> "$OPLOG"
        printf "%s\n" "_test_herdr() { COMPREPLY=(session); }" "complete -F _test_herdr herdr" ;;
      "session list") printf "SESSION STATE PID SOCKET\n" ;;
      *) exit 1 ;;
    esac'
    stub_command cwf 'case "$*" in
      "shell zsh"|"shell bash") printf "# cwf shell integration\n" ;;
      "completion bash") printf "%s\n" "complete -F _get_comp_words_by_ref cwf" ;;
      *) exit 1 ;;
    esac'
    "$MARKSHARC_HOME/bin/marksharc" render --env-only || return
    # The first real interactive shell also leaves the generator untouched.
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" -ic \
      '[[ $MARKSHARC_SESSION == interactive ]] && ! complete -p herdr >/dev/null 2>&1' \
      > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
    [ ! -s "$OPLOG" ] || return 2
    "$MARKSHARC_HOME/bin/marksharc" render || return
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" -ic \
      '[[ $(complete -p herdr) == *"-F _test_herdr herdr" ]] &&
       _test_herdr && [[ ${COMPREPLY[0]} == session ]] && ! complete -p cwf >/dev/null 2>&1' \
      > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 3; }
    cat "$OPLOG"
  }
  It 'loads the Herdr completion from explicit render without invoking its generator at startup'
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run generated_completion
    The status should be success
    The output should equal 'bash generator'
  End
End
