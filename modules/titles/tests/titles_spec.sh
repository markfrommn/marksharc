Describe 'literal terminal titles'
  title_case() {
    emulate -L zsh
    load_mfn titles set-title
    local TERM=xterm
    local actual=$(set-title 'two words $HOME %n' window combined)
    [[ $actual == $'\e]0;combined\a\e]2;window\a\e]1;two words $HOME %n\a' ]] || return 1
    TERM=tmux
    actual=$(set-title $'literal %n\a\e\n')
    [[ $actual == $'\ekliteral %n\e\\' ]] || return 2
  }
  label_case() {
    emulate -L zsh
    git_fixture
    "$REAL_GIT" checkout -q --detach
    cat > "$TEST_ROOT/title-script" <<'DATA'
fpath=( "$MARKSHARC_ROOT/modules/titles/functions/zsh" $fpath )
autoload -Uz set-title chdir-set-title
cwf() { return 1; }
set-title() { print -r -- "$1"; }
chdir-set-title
DATA
    local label=$(SHLVL=0 /bin/zsh -df "$TEST_ROOT/title-script")
    [[ $label == detached-* ]] || { print -r -- "$label"; return 1; }
  }
  It 'labels detached repositories without remotes'
    When run label_case
    The status should be success
  End
  It 'uses distinct title arguments without escaping or prompt expansion'
    When run title_case
    The status should be success
  End
  init_case() {
    emulate -L zsh
    # The hook is registered once (init is safe to source twice), the startup kick runs it
    # with the skip variable set and the variable is gone afterwards.
    module_run titles '
      chdir-set-title() { print -r -- "kick:${chdir_set_title_skip-unset}" >> "$OPLOG"; }
      source "$MOD_INIT"; source "$MOD_INIT"
      print -r -- "hooks=${(j:,:)chpwd_functions} after=${chdir_set_title_skip-unset}"' || return 1
    [[ $(<"$TEST_ROOT/out") == 'hooks=chdir-set-title after=unset' ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(<"$OPLOG") == $'kick:yes\nkick:yes' ]] || { cat "$OPLOG"; return 3; }
  }
  It 'registers the chpwd hook once and runs the startup kick with the skip variable'
    When run init_case
    The status should be success
  End
End
