Describe 'private overlay loader'
  overlay_case() {
    emulate -L zsh
    ms_fixture
    local overlay="$TEST_ROOT/overlay with spaces"
    mkdir -p "$overlay/modules/demo" "$overlay/hosts" "$MS_HOME/modules/demo"
    print 'describe public' > "$MS_HOME/modules/demo/module.conf"
    print 'print public >> "$OPLOG"' > "$MS_HOME/modules/demo/env.zsh"
    print 'describe private' > "$overlay/modules/demo/module.conf"
    print 'option value default' >> "$overlay/modules/demo/module.conf"
    print 'print -r -- "private:$_ms_opt_demo_value" >> "$OPLOG"' > "$overlay/modules/demo/env.zsh"
    print 'set demo.value common' > "$overlay/config.conf"
    print 'set demo.value "host value"' > "$overlay/hosts/testhost.conf"
    ms_run MARKSHARC_CONFIG="$overlay" HOST=testhost -c ':' || return 1
    [[ $(<"$OPLOG") == 'private:host value' ]] || { cat "$OPLOG"; return 2; }
  }
  It 'loads the private duplicate and applies host configuration after common configuration'
    When run overlay_case
    The status should be success
  End
  host_agent_case() {
    emulate -L zsh
    ms_fixture
    mkdir -p "$XDG_CONFIG_HOME/marksharc/hosts"
    print 'set agent.markers CUSTOM_AGENT' > "$XDG_CONFIG_HOME/marksharc/hosts/testhost.conf"
    ms_pty HOST=testhost CUSTOM_AGENT=1 -dic 'print -r -- "class=$MARKSHARC_SESSION"; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'class=agent'* ]]
  }
  It 'uses host agent markers before interactive classification'
    When run host_agent_case
    The status should be success
  End
  identity_case() {
    emulate -L zsh
    ms_fixture
    mkdir -p "$TEST_ROOT/one/modules/demo/functions/zsh" "$TEST_ROOT/two/modules/demo/functions/zsh"
    print a > "$TEST_ROOT/one/modules/demo/functions/zsh/f"
    cp "$TEST_ROOT/one/modules/demo/functions/zsh/f" "$TEST_ROOT/two/modules/demo/functions/zsh/f"
    ms_run MARKSHARC_CONFIG="$TEST_ROOT/one" -c 'print "$MARKSHARC_ENV"' || return 1
    local first=$(<"$TEST_ROOT/out")
    ms_run MARKSHARC_CONFIG="$TEST_ROOT/two" -c 'print "$MARKSHARC_ENV"' || return 2
    [[ $(<"$TEST_ROOT/out") != "$first" ]] || return 3
    mv "$TEST_ROOT/one/modules/demo/functions/zsh/f" "$TEST_ROOT/one/modules/demo/functions/zsh/g"
    ms_run MARKSHARC_CONFIG="$TEST_ROOT/one" -c 'print "$MARKSHARC_ENV"' || return 5
    [[ $(<"$TEST_ROOT/out") != "$first" ]] || return 6
    local renamed=$(<"$TEST_ROOT/out")
    ms_run MARKSHARC_CONFIG="$TEST_ROOT/one" MARKSHARC_ENV="$renamed" -c 'print "$_ms_env_rebuild"' || return 7
    [[ $(<"$TEST_ROOT/out") == 0 ]] || return 8
    print longer > "$TEST_ROOT/one/modules/demo/functions/zsh/g"
    ms_run MARKSHARC_CONFIG="$TEST_ROOT/one" MARKSHARC_ENV="$renamed" -c 'print "$MARKSHARC_ENV:$_ms_env_rebuild"' || return 4
    [[ $(<"$TEST_ROOT/out") != "$renamed:0" && $(<"$TEST_ROOT/out") == *:1 ]]
  }
  It 'invalidates inherited environment for overlay path and private file changes'
    When run identity_case
    The status should be success
  End
  reload_paths_case() {
    emulate -L zsh
    ms_fixture
    local overlay="$TEST_ROOT/private"
    mkdir -p "$overlay/modules/demo/functions/zsh" "$overlay/modules/demo/completions/zsh"
    print 'describe demo' > "$overlay/modules/demo/module.conf"
    print 'print demo' > "$overlay/modules/demo/functions/zsh/demo"
    ms_pty MARKSHARC_CONFIG="$overlay" -dic '
      print -r -- "before=${fpath[(Ie)$MARKSHARC_CONFIG/modules/demo/functions/zsh]}"
      print "module demo off" > "$MARKSHARC_CONFIG/config.conf"
      source "$MARKSHARC_HOME/core/zsh/reload.zsh" >/dev/null 2>&1
      print -r -- "after=${fpath[(Ie)$MARKSHARC_CONFIG/modules/demo/functions/zsh]}"
      exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'before=2'* && $(<"$TEST_ROOT/out") == *'after=0'* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'removes stale private fpath entries when a module is disabled on reload'
    When run reload_paths_case
    The status should be success
  End
  function_ownership_case() {
    emulate -L zsh
    ms_fixture
    ms_mod demo module.conf 'describe demo'
    ms_mod demo functions/zsh/demo-user 'print module-user'
    ms_mod demo functions/zsh/demo-loaded 'print loaded'
    ms_mod demo functions/zsh/demo-pending 'print pending'
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    ms_pty -dic '
      demo-loaded >/dev/null
      demo-user() { print user; }
      print "module demo off" > "$XDG_CONFIG_HOME/marksharc/config.conf"
      source "$MARKSHARC_HOME/core/zsh/reload.zsh" >/dev/null 2>&1
      print -r -- "user=$(demo-user) loaded=${+functions[demo-loaded]} pending=${+functions[demo-pending]}"
      exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'user=user loaded=0 pending=0'* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'unloads only owned loaded and pending functions when a module is disabled'
    When run function_ownership_case
    The status should be success
  End
  active_function_reload_case() {
    emulate -L zsh
    ms_fixture
    ms_mod demo module.conf 'describe demo'
    ms_mod demo functions/zsh/demo-func 'print old'
    ms_pty -dic '
      demo-func >/dev/null
      print "print new" > "$MARKSHARC_HOME/modules/demo/functions/zsh/demo-func"
      source "$MARKSHARC_HOME/core/zsh/reload.zsh" >/dev/null 2>&1
      print -r -- "result=$(demo-func)"
      exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'result=new'* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'refreshes a loaded module function when the module stays enabled'
    When run active_function_reload_case
    The status should be success
  End
  post_case() {
    emulate -L zsh
    ms_fixture
    mkdir -p "$XDG_CONFIG_HOME/marksharc/local"
    print 'print post >> "$OPLOG"' > "$XDG_CONFIG_HOME/marksharc/local/post.zsh"
    ms_run -c ':' || return 1
    [[ ! -s "$OPLOG" ]] || return 2
    ms_pty -dic 'source "$MARKSHARC_HOME/core/zsh/reload.zsh" >/dev/null 2>&1; exit' || return 3
    [[ $(<"$OPLOG") == $'post\npost' ]] || { cat "$OPLOG"; return 4; }
  }
  It 'runs the post hook interactively on startup and once per reload'
    When run post_case
    The status should be success
  End
  # private_layout_case stays out: it asserted the author's private tree, which
  # never lives in this repo. disabled_hook_case is back with a synthesized
  # overlay module (the convoy hook/cleanup pattern with neutral names).
  disabled_hook_case() {
    emulate -L zsh
    ms_fixture_full
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/demo-hooks"
    print 'describe "demo hooks"' > "$XDG_CONFIG_HOME/marksharc/modules/demo-hooks/module.conf"
    cat > "$XDG_CONFIG_HOME/marksharc/modules/demo-hooks/init.zsh" <<'DATA'
demo-cwf-new-hook() { :; }
typeset -gaU cwf_new_post_create_hooks
cwf_new_post_create_hooks=( demo-cwf-new-hook ${cwf_new_post_create_hooks:#demo-cwf-new-hook} )
_ms_demo_hooks_cleanup() {
  cwf_new_post_create_hooks=( "${(@)cwf_new_post_create_hooks:#demo-cwf-new-hook}" )
}
typeset -gaU _ms_init_cleanups
_ms_init_cleanups+=( _ms_demo_hooks_cleanup )
DATA
    ms_pty -dic '
      print -r -- "before=${cwf_new_post_create_hooks[(Ie)demo-cwf-new-hook]}"
      print "module demo-hooks off" >> "$XDG_CONFIG_HOME/marksharc/config.conf"
      source "$MARKSHARC_HOME/core/zsh/reload.zsh" >/dev/null 2>&1
      print -r -- "after=${cwf_new_post_create_hooks[(Ie)demo-cwf-new-hook]}"
      exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'before=1'* && $(<"$TEST_ROOT/out") == *'after=0'* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'removes a disabled private module owned hook on reload'
    When run disabled_hook_case
    The status should be success
  End
  removed_option_case() {
    emulate -L zsh
    ms_fixture
    ms_mod demo module.conf $'describe demo\noption color blue'
    ms_mod demo env.zsh 'print -r -- "color=$_ms_opt_demo_color" >> "$OPLOG"'
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print 'set demo.color red' > "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_pty -dic 'print "set other.value ignored" > "$XDG_CONFIG_HOME/marksharc/config.conf"; source "$MARKSHARC_HOME/core/zsh/reload.zsh" >/dev/null 2>&1; exit' || return 1
    [[ $(<"$OPLOG") == $'color=red\ncolor=blue' ]] || { cat "$OPLOG"; return 2; }
  }
  It 'restores an option default when its override is removed on reload'
    When run removed_option_case
    The status should be success
  End
End
