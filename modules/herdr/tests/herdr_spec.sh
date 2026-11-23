Describe 'herdr session wrappers and completion'
  session_case() {
    emulate -L zsh
    load_mfn herdr
    local -a calls
    _ms_init_cached() { return 0; }
    herdr() { case "$*" in 'session list') print 'NAME STATE PID SOCKET'; print "  demo ready 123 $HOME/socket space";; 'completion zsh') :;; *) print -r -- "$#|$*" > "$HOME/attach";; esac; }
    have_command() { [[ $1 == herdr ]]; }
    mkdir -p "$HOME/.config/fallback"
    cat > "$HOME/.config/fallback/collie-ctl.sh" <<'DATA'
#!/bin/sh
printf '%s\n' "$HERDR_SOCKET_PATH" "$#" "$1" > "$HOME/collie"
DATA
    chmod +x "$HOME/.config/fallback/collie-ctl.sh"
    purge_functions() { :; }
    make_function() { functions[$1]=$2; }
    setup-herdr-sessions > "$TEST_ROOT/out" 2>&1 || return 1
    herdr-demo 'extra argument' || return 2
    collie-demo 'extra argument' || return 3
    [[ $(<"$HOME/collie") == "$HOME/socket space"$'\n1\nextra argument' ]] || return 4
    [[ $(<"$HOME/attach") == '4|session attach demo extra argument' ]] || return 5
  }
  completion_case() {
    emulate -L zsh
    ms_fixture
    ms_copy_module herdr
    cat > "$TEST_ROOT/bin/herdr" <<'DATA'
#!/bin/sh
case "$*" in
  'session list') echo 'NAME STATE PID SOCKET';;
  'completion zsh') [ -e "$TEST_ROOT/herdr-ok" ] && echo '#compdef herdr' || exit 3;;
esac
DATA
    chmod +x "$TEST_ROOT/bin/herdr"
    render() {
      env -i HOME="$HOME" PATH="$PATH" MARKSHARC_HOME="$MS_HOME" HOST=testhost \
        XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
        XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
        OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT" /bin/zsh -f "$MS_HOME/core/cli/render" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"
    }
    render && return 1
    local cache="$XDG_CACHE_HOME/marksharc/testhost"
    [[ ! -e $cache/completions/zsh/_herdr && ! -e $cache/completion-id ]] || return 2
    : > "$TEST_ROOT/herdr-ok"
    render || { cat "$TEST_ROOT/err"; return 3; }
    [[ $(<"$cache/completions/zsh/_herdr") == '#compdef herdr' && ! -s $OPLOG ]] || return 4
    [[ $(<"$cache/completion-id") == $(<"$cache/render-id") ]]
  }
  It 'renders completion without sourcing it and preserves no artifact after generator failure'
    When run completion_case
    The status should be success
  End
  It 'finds Collie fallback and preserves spaced socket/arguments'
    When run session_case
    The status should be success
  End
  init_case() {
    module_run herdr 'setup-herdr-sessions() { print CALLED; return 3; }; source "$MOD_INIT"' || return 1
    [[ $(<"$TEST_ROOT/out") == CALLED ]]
  }
  It 'runs setup-herdr-sessions from init and tolerates its failure'
    When run init_case
    The status should be success
  End
End
