# The overlay skeleton installed by install.sh (spec 6.3). It must leave every public
# module enabled, offer each as a commented off line, and only suggest real options.
Describe 'template overlay'
  template="$MARKSHARC_ROOT/templates/overlay"

  config_case() {
    emulate -L zsh
    local conf=$template/config.conf name line
    [[ -f $conf ]] || return 1
    # No active module line: the loader would otherwise switch to explicit-list mode.
    if grep -Eq '^[[:space:]]*module[[:space:]]' "$conf"; then return 2; fi
    local -a want have
    for name in "$MARKSHARC_ROOT"/modules/*(/N:t); do want+=( $name ); done
    while IFS= read -r line; do
      [[ $line =~ '^# module ([A-Za-z0-9_-]+) off$' ]] && have+=( $match[1] )
    done < "$conf"
    (( $#want )) || return 3
    [[ ${(j: :)${(o)want}} == ${(j: :)${(o)have}} ]] || { print -r -- "want: $want | have: $have"; return 4; }
  }
  It 'lists every public module as a commented off line and has no active module line'
    When run config_case
    The status should be success
  End

  loader_case() {
    emulate -L zsh
    ms_unit "MARKSHARC_CONFIG=\"$template\"; "'_ms_config_load; print -r -- "explicit=$_ms_cfg_explicit n=${#_ms_cfg_enabled} set=${#_ms_cfg_set}"' || return 1
    [[ $(<"$TEST_ROOT/out") == 'explicit=0 n=0 set=0' ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err" >&2; return 2; }
  }
  It 'loads as a config that enables every module and sets nothing'
    When run loader_case
    The status should be success
  End

  examples_case() {
    emulate -L zsh
    local line key mod opt n=0
    while IFS= read -r line; do
      [[ $line =~ '^# set ([A-Za-z0-9_-]+)\.([A-Za-z0-9_]+) ' ]] || continue
      mod=$match[1]; opt=$match[2]; n=$(( n + 1 ))
      [[ $mod == core && $opt == dot_in_path ]] && continue
      grep -Eq "^option[[:space:]]+${opt}[[:space:]]" "$MARKSHARC_ROOT/modules/$mod/module.conf" 2>/dev/null || { print -r -- "unknown option $mod.$opt"; return 1; }
    done < "$template/config.conf"
    (( n >= 2 )) || { print -r -- "only $n set examples"; return 2; }
  }
  It 'only suggests set examples for options that exist'
    When run examples_case
    The status should be success
  End

  skeleton_case() {
    emulate -L zsh
    [[ -f $template/README.md && -f $template/local/post.zsh && -f $template/hosts/.gitkeep ]] || return 1
    [[ ! -e $template/.gitkeep && ! -e $template/local/pre.zsh ]] || return 2
    zsh -n "$template/local/post.zsh" || return 3
    # The sample hook does nothing until the user edits it.
    [[ -z $(zsh -fc 'source "$1"' _ "$template/local/post.zsh" 2>&1) ]] || return 4
  }
  It 'ships the README, a silent post hook and the hosts directory'
    When run skeleton_case
    The status should be success
  End

  real_tree_case() {
    emulate -L zsh
    ms_fixture_full
    cp -R "$template" "$XDG_CONFIG_HOME/marksharc" 2>/dev/null || { mkdir -p "$XDG_CONFIG_HOME" && cp -R "$template" "$XDG_CONFIG_HOME/marksharc"; }
    ms_run -c 'print -r -- "$MARKSHARC_SESSION"' || return 1
    [[ $(<"$TEST_ROOT/out") == batch && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    ms_run -c 'print -r -- "$+functions[_ms_path_build]$+commands[ls]"' || return 3
  }
  It 'starts quietly with the template as the overlay'
    When run real_tree_case
    The status should be success
  End
End
