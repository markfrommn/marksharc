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
