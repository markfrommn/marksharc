Describe 'Bash interactive runtime'
  prepare_bash_runtime() {
    config="$HOME/config with spaces"
    module="$config/modules/probe"
    mkdir -p "$module/functions/bash" "$module/completions/bash" "$config/local" "$HOME/probe bin"
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$config" MARKSHARC_NOTIFY=0
    stub_command herdr 'case "$*" in
      "completion zsh") printf "#compdef herdr\n" ;;
      "session list") printf "SESSION STATE PID SOCKET\n" ;;
      *) exit 99 ;;
    esac'
    printf '%s\n' 'source "$MARKSHARC_HOME/core/bash/bashrc.bash"' > "$HOME/.bashrc"
    cp "$HOME/.bashrc" "$HOME/.bash_profile"
    printf '%s\n' 'set probe.choice "chosen value"' 'set agent.markers LOCAL_AGENT' \
      'module prompt-starship off' 'module history-atuin off' 'module zoxide off' > "$config/config.conf"
    cat > "$module/module.conf" <<'EOF'
describe "Bash contract probe"
order 90
option choice default
env PROBE_ENV "native value"
path user "$HOME/probe bin"
alias probe_alias "printf ready" when command grep
alias missing_alias "printf wrong" when command dev80-absent-command
EOF
    cat > "$module/init.bash" <<'EOF'
[[ $(probe_fn) == owned ]] || return 1
_ms_bash_set_env PROBE_INIT "$_ms_opt_probe_choice"
probe_remove() { printf 'cleanup\n' >> "$TEST_ROOT/cleanups"; }
probe_prompt() { :; }
_ms_bash_register_cleanup probe_remove
_ms_bash_register_prompt probe_prompt
EOF
    cat > "$module/functions/bash/probe_fn.bash" <<'EOF'
function probe_fn { printf owned; }
EOF
    printf '%s\n' 'complete -W one probe' > "$module/completions/bash/probe.bash"
    cat > "$config/local/post.bash" <<'EOF'
printf '%s:%s\n' "$BASHPID" "$PROBE_INIT" >> "$TEST_ROOT/starts"
function post_fn { :; }
EOF
  }

  bash_terminal() {
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" "$@"
  }

  entry_case() {
    prepare_bash_runtime
    bash_terminal "$1" -c '
      [[ $MARKSHARC_SESSION == interactive && $PROBE_INIT == "chosen value" && $PROBE_ENV == "native value" ]] || exit 10
      [[ $(type -t marksharc) == function && $(type -t cwf-new) == function ]] || exit 11
      [[ $(type -t probe_alias) == alias && -z $(type -t missing_alias) ]] || exit 12
      complete -p probe >/dev/null || exit 13
      source "$HOME/.bash_profile"
      source "$HOME/.bashrc"
      [[ $(wc -l < "$TEST_ROOT/starts") == 1 ]] || exit 14
      "$BASH" -ic '"'"'[[ $(type -t post_fn) == function && $_ms_opt_probe_choice == "chosen value" ]]'"'"' || exit 15
      [[ $(sort -u "$TEST_ROOT/starts" | wc -l) == 2 ]] || exit 16
    ' > "$TEST_ROOT/out" 2>&1 || { status=$?; cat "$TEST_ROOT/out"; return "$status"; }
    ! grep -E 'marksharc:|command not found|unbound variable' "$TEST_ROOT/out"
  }
  It 'initializes an interactive login shell once and initializes its inheriting child'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run entry_case -il
    The status should be success
  End
  It 'initializes an interactive non-login shell once and initializes its inheriting child'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run entry_case -i
    The status should be success
  End

  env_only_case() {
    prepare_bash_runtime
    bash_bin=${MARKSHARC_TEST_BASH:-bash}
    "$bash_bin" -lc '[[ $PROBE_ENV == "native value" && $(type -t marksharc) == file && $MARKSHARC_SESSION == batch ]]' || return 1
    BASH_ENV="$MARKSHARC_ROOT/core/bash/env.bash" "$bash_bin" -c \
      '[[ $PROBE_ENV == "native value" && $(type -t marksharc) == file && $MARKSHARC_SESSION == batch ]]' || return 2
    "$bash_bin" -ic '[[ $PROBE_ENV == "native value" && $(type -t marksharc) == file && $MARKSHARC_SESSION == batch ]]' \
      < /dev/null > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 3
    [ ! -s "$TEST_ROOT/out" ] || return 4
    ! grep -E 'marksharc:|command not found' "$TEST_ROOT/err" || return 5
    if [ -n "$PYTHON" ]; then
      LOCAL_AGENT=1 bash_terminal -ic \
        '[[ $PROBE_ENV == "native value" && $(type -t marksharc) == file && $MARKSHARC_SESSION == agent ]]' \
        > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 6; }
      if bash_interactive_unavailable; then
        bash_terminal -ic '[[ $PROBE_ENV == "native value" && $(type -t marksharc) == file ]]' \
          > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 7; }
      fi
    fi
    [ ! -e "$TEST_ROOT/starts" ]
  }
  It 'keeps batch, no-TTY, agent, BASH_ENV and older Bash sessions env-only'
    When run env_only_case
    The status should be success
  End

  reload_case() {
    prepare_bash_runtime
    cat > "$HOME/.bashrc" <<'EOF'
alias restored_alias='printf user'
PROBE_BASELINE=before
source "$MARKSHARC_HOME/core/bash/bashrc.bash"
EOF
    cat >> "$module/init.bash" <<'EOF'
function kept_fn { printf module; }
alias kept_alias='printf module'
alias restored_alias='printf module'
_ms_bash_set_env PROBE_REPLACED module
_ms_bash_set_env PROBE_BASELINE module
EOF
    bash_terminal -ic '
      [[ $(probe_fn) == owned ]] || exit 10
      function kept_fn { printf user; }
      alias kept_alias="printf user"
      export PROBE_REPLACED=user
      PROMPT_COMMAND=": foreign"
      PATH="$HOME/user bin:$PATH"
      complete -W user probe
      command touch "$TEST_ROOT/cache-blocked"
      XDG_CACHE_HOME="$TEST_ROOT/cache-blocked" marksharc reload && exit 11
      [[ $(probe_fn) == owned && $PROBE_REPLACED == user && ! -e $TEST_ROOT/cleanups ]] || exit 12
      marksharc reload --bad && exit 13
      [[ $(probe_fn) == owned && ! -e $TEST_ROOT/cleanups ]] || exit 14
      marksharc reload >/dev/null || exit 15
      [[ $MARKSHARC_SESSION == interactive && $(kept_fn) == user && ${BASH_ALIASES[kept_alias]} == "printf user" && $PROBE_REPLACED == user ]] || exit 16
      printf "%s\n" "module probe off" "module prompt-starship off" "module history-atuin off" "module zoxide off" "module nav off" "module titles off" > "$MARKSHARC_CONFIG/config.conf"
      marksharc reload || exit 17
      if [[ -n $(type -t probe_fn) || -n $(type -t probe_alias) || -n ${PROBE_ENV+x} || -n ${PROBE_INIT+x} ]]; then
        type -t probe_fn probe_alias
        declare -p PROBE_ENV PROBE_INIT 2>/dev/null
        exit 18
      fi
      [[ :$PATH: != *":$HOME/probe bin:"* && :$PATH: == *":$HOME/user bin:"* ]] || exit 19
      [[ $(kept_fn) == user && ${BASH_ALIASES[kept_alias]} == "printf user" && $PROBE_REPLACED == user ]] || exit 20
      [[ $(complete -p probe) == *user* ]] || exit 21
      [[ $PROMPT_COMMAND == ": foreign" && $(wc -l < "$TEST_ROOT/cleanups") == 2 ]] || exit 22
      cs >/dev/null 2>&1 && li >/dev/null 2>&1 || exit 23
      [[ $(wc -l < "$TEST_ROOT/cleanups") == 2 ]] || exit 24
      [[ ${BASH_ALIASES[restored_alias]} == "printf user" && $(declare -p PROBE_BASELINE) == "declare -- PROBE_BASELINE=\"before\"" ]] || exit 25
    ' > "$TEST_ROOT/out" 2>&1 || { status=$?; cat "$TEST_ROOT/out"; return "$status"; }
  }
  It 'reloads in place, cleans up disabled effects and retains later shell state'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run reload_case
    The status should be success
  End

  stale_init_case() {
    prepare_bash_runtime
    "$MARKSHARC_HOME/bin/marksharc" render --env-only || return 1
    init=$(find "$XDG_CACHE_HOME" -name init.bash)
    [ -n "$init" ] || return 2
    printf '# stale\n' > "$init"
    bash_terminal -ic '[[ $(type -t probe_fn) == function ]]' > "$TEST_ROOT/out" 2>&1 ||
      { cat "$TEST_ROOT/out"; return 3; }
    grep '^# render id:' "$init" > /dev/null
  }
  It 'rebuilds a stale Bash init artifact before loading it'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run stale_init_case
    The status should be success
  End

  unavailable_cache_case() {
    prepare_bash_runtime
    : > "$XDG_CACHE_HOME"
    bash_terminal -ic '[[ -z $(type -t probe_fn) && -z $(declare -F _ms_bash_hooks_install) ]]' > "$TEST_ROOT/out" 2>&1 ||
      { cat "$TEST_ROOT/out"; return 1; }
    [ ! -e "$TEST_ROOT/starts" ] && ! grep -E 'marksharc:|command not found|error' "$TEST_ROOT/out"
  }
  It 'starts quietly without interactive effects when it cannot produce a valid cache'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run unavailable_cache_case
    The status should be success
  End
End
