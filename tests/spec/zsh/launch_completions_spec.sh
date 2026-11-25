Describe 'launch-session completion'
  completion_case() {
    emulate -L zsh
    printf 'host\talpha\tops@alpha\nhost with:colon\n' > "$HOME/hosts.conf"
    mkdir -m 777 "$HOME/insecure-completions"
    cat > "$HOME/.zshrc" <<'DATA'
fpath=( "$MARKSHARC_HOME/modules/launch/completions/zsh" "$HOME/insecure-completions" $fpath )
autoload -Uz compinit
# Match MarkSharc startup by skipping insecure completion directories without prompting.
compinit -i -D
launch-session() { printf '%s\n' "$*" >> "$OPLOG"; }
DATA
    local typed=$'launch-session --host al\t\nlaunch-session --host with\t\nlaunch-session al\t\nlaunch-session --mux tm\t\nlaunch-session --place hi\t\nlaunch-session --in-sh\t\nexit\n'
    PTY_INPUT=$typed ms_pty MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME" -di ||
      { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$OPLOG") == $'--host alpha\n--host with:colon\nalpha:\n--mux tmux\n--place hidden\n--in-shell' ]] ||
      { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
  }
  It 'completes launch hosts, mux kinds, placements and options'
    When run completion_case
    The status should be success
  End
End
Describe 'cwf-new completion'
  cwf_completion_case() {
    emulate -L zsh
    mkdir -p "$HOME/.cache/marksharc/test/repos"
    printf 'alpha\t/tmp/alpha\tbase\t/tmp/alpha\tmain\nlinked\t/tmp/linked\tworktree\t/tmp/alpha\tfeature\n' > "$HOME/.cache/marksharc/test/repos/local.tsv"
    cat > "$HOME/.zshrc" <<'DATA'
fpath=( "$MARKSHARC_ROOT/modules/cwf/completions/zsh" $fpath )
autoload -Uz compinit
compinit -i -D
cwf-new() { printf '%s\n' "$*" >> "$OPLOG"; }
DATA
    local typed=$'cwf-new --repo al\t\ncwf-new --mux tmu\t\ncwf-new --place hi\t\ncwf-new --lau\t\nexit\n'
    PTY_INPUT=$typed ms_pty MARKSHARC_ROOT="$MARKSHARC_ROOT" MARKSHARC_HOST=test XDG_CACHE_HOME="$HOME/.cache" -di || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$OPLOG") == $'--repo alpha\n--mux tmux\n--place hidden\n--launch' ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
  }
  It 'completes cached base repositories and launch options'
    When run cwf_completion_case
    The status should be success
  End
End
