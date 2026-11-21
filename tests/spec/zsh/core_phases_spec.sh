Describe 'core phases driven through modules'
  zdot_chain_case() {
    emulate -L zsh
    ms_fixture
    ms_env; local zdot="$XDG_STATE_HOME/marksharc/zdot"
    ms_mod probe module.conf 'describe "probe"'
    ms_mod probe init.zsh 'print -r -- INIT_RAN >> "$OPLOG"'
    # User dotfiles in HOME must stay unread.
    print -r -- 'print -r -- HOME_ZSHRC >> "$OPLOG"' > "$HOME/.zshrc"
    print -r -- 'print -r -- HOME_ZPROFILE >> "$OPLOG"' > "$HOME/.zprofile"
    ms_pty -dic 'exit' || return 1
    [[ $(<"$OPLOG") == INIT_RAN ]] || { cat "$OPLOG"; return 2; }
  }
  It 'runs the init phase through the generated ZDOTDIR and never reads HOME dotfiles'
    When run zdot_chain_case
    The status should be success
  End
  inherit_case() {
    emulate -L zsh
    ms_fixture
    ms_mod probe module.conf 'describe "probe"'
    ms_mod probe env.zsh 'print -r -- "rebuild=$_ms_env_rebuild" >> "$OPLOG"; (( _ms_env_rebuild )) && path+=( /marksharc-probe )'
    ms_run -c 'print -r -- "$MARKSHARC_ENV"' || return 1
    local id=$(<"$TEST_ROOT/out")
    [[ -n $id && $(<"$OPLOG") == rebuild=1 ]] || { cat "$OPLOG"; return 2; }
    : > "$OPLOG"
    ms_run MARKSHARC_ENV=$id -c 'print -r -- "$MARKSHARC_ENV $PATH"' || return 3
    [[ $(<"$OPLOG") == rebuild=0 && $(<"$TEST_ROOT/out") == "$id "* && $(<"$TEST_ROOT/out") != *marksharc-probe* ]] || { cat "$OPLOG" "$TEST_ROOT/out"; return 4; }
    : > "$OPLOG"
    ms_run MARKSHARC_ENV=bogus -c ':' || return 5
    [[ $(<"$OPLOG") == rebuild=1 ]] || return 6
    : > "$OPLOG"
    ms_run MARKSHARC_ENV=$id -lc ':' || return 7
    [[ $(<"$OPLOG") == rebuild=1 ]] || { cat "$OPLOG"; return 8; }
    : > "$OPLOG"
    print -r -- "# changed" >> "$MS_HOME/modules/probe/env.zsh"
    ms_run MARKSHARC_ENV=$id -c 'print -r -- "$MARKSHARC_ENV"' || return 9
    [[ $(<"$OPLOG") == rebuild=1 && $(<"$TEST_ROOT/out") != $id ]]
  }
  It 'skips export and PATH work for a matching MARKSHARC_ENV and rebuilds for login or changed inputs'
    When run inherit_case
    The status should be success
  End
  zprofile_case() {
    emulate -L zsh
    ms_fixture
    ms_mod probe module.conf 'describe "probe"'
    ms_mod probe env.zsh '(( _ms_env_rebuild )) && path=( /marksharc-first "${path[@]}" )'
    ms_run -lc 'print -r -- "$PATH"' || return 1
    [[ $(<"$TEST_ROOT/out") == /marksharc-first:* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'keeps the module PATH first in a login shell even after the system zprofile'
    When run zprofile_case
    The status should be success
  End
End
