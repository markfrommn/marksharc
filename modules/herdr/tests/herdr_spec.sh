Describe 'herdr session wrappers and completion'
  completion_case() {
    emulate -L zsh
    ms_fixture
    ms_copy_module herdr mux
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
End
