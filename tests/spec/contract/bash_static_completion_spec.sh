Describe 'Bash workflow completions'
  Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable

  static_candidates() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_HOST=fixture
    inventory="$XDG_CACHE_HOME/marksharc/fixture/repos"
    mkdir -p "$inventory" "$TEST_ROOT/dir space'quote" "$TEST_ROOT/project"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "api team's" "/repos/api team's" base "/repos/api team's" '' \
      "review copy's" "/worktrees/review copy's" worktree "/repos/api team's" 'review/changes' \
      'other review' '/worktrees/other review' worktree '/repos/unrelated' 'review/other' > "$inventory/builder.tsv"
    git -C "$TEST_ROOT/project" init -q || return
    git -C "$TEST_ROOT/project" -c user.name=Test -c user.email=test@example.invalid commit -qm initial --allow-empty || return
    git -C "$TEST_ROOT/project" branch review/changes || return
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/modules/launch/completions/bash/launch-repo.bash"
      source "$MARKSHARC_ROOT/modules/launch/completions/bash/launch-session.bash"
      source "$MARKSHARC_ROOT/modules/cwf/completions/bash/cwf-new.bash"
      cd "$TEST_ROOT" || exit 1
      COMP_WORDS=(launch-session --pwd "dir\\ sp") COMP_CWORD=2
      _ms_workflow_complete launch-session "" --pwd
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == "dir space'"'"'quote" ]] || exit 2
      COMP_WORDS=(launch-repo builder : api) COMP_CWORD=3
      _ms_workflow_complete launch-repo api :
      [[ ${#COMPREPLY[@]} == 3 && ${COMPREPLY[0]} == "api team'"'"'s" ]] || exit 3
      COMP_WORDS=(launch-repo --host builder --repo "\"api team'"'"'s\"" --worktree review) COMP_CWORD=6
      _ms_workflow_complete launch-repo review --worktree
      [[ ${#COMPREPLY[@]} == 2 && ${COMPREPLY[0]} == "review copy'"'"'s" && ${COMPREPLY[1]} == review/changes ]] || exit 4
      COMP_WORDS=(cwf-new --host builder --repo api) COMP_CWORD=4
      _ms_workflow_complete cwf-new api --repo
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == "api team'"'"'s" ]] || exit 5
      cd "$TEST_ROOT/project" || exit 6
      COMP_WORDS=(cwf-new --place tab rev) COMP_CWORD=3
      _ms_workflow_complete cwf-new rev tab
      [[ ${#COMPREPLY[@]} == 1 && ${COMPREPLY[0]} == review/changes ]]
    '
  }
  It 'preserves literal paths, repository names, worktree names and branch names'
    When run static_candidates
    The status should be success
  End

  quoted_completion() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_HOST=fixture INPUTRC=/dev/null TERM=dumb
    inventory="$XDG_CACHE_HOME/marksharc/fixture/repos"
    mkdir -p "$TEST_ROOT/dir space'quote" "$inventory"
    printf '%s\t%s\t%s\t%s\t\n' "api team's" "/repos/api team's" base "/repos/api team's" > "$inventory/builder.tsv"
    cd "$TEST_ROOT" || return
    cat > "$HOME/.bashrc" <<'EOF'
source "$MARKSHARC_HOME/modules/launch/completions/bash/launch-session.bash"
source "$MARKSHARC_HOME/modules/launch/completions/bash/launch-repo.bash"
launch-session() { printf 'ARG:<%s>\n' "$@"; }
launch-repo() { printf 'ARG:<%s>\n' "$@"; }
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
