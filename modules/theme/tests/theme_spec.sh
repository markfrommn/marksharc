Describe 'theme module (P3.6)'
  # Every case runs the module's init in a clean zsh with the core libraries; only stubs in
  # $TEST_ROOT/bin count as installed, so host tools never leak in.
  theme_run() {
    print -r -- "$1" > "$TEST_ROOT/case.zsh"
    ms_unit 'MARKSHARC_SESSION=interactive; PATH="$TEST_ROOT/bin:/usr/bin:/bin"; have_command() { [[ -x $TEST_ROOT/bin/$1 ]]; }
THEME="$MARKSHARC_HOME/modules/theme/init.zsh"; source "$TEST_ROOT/case.zsh"'
  }
  all_tools() {
    stub_command vivid 'echo "vivid $*" >> "$OPLOG"; echo "di=01;34:ln=01;36"'
    stub_command bat 'exit 0'; stub_command col 'exit 0'; stub_command fd 'exit 0'
    stub_command eza 'exit 0'; stub_command delta 'exit 0'
  }
  native_case() {
    emulate -L zsh
    theme_run 'unset LS_COLORS MANPAGER GIT_CONFIG_COUNT FZF_DEFAULT_COMMAND; source $THEME
print -r -- "LS=${LS_COLORS-unset} MAN=${MANPAGER-unset} GIT=${GIT_CONFIG_COUNT-unset} CMD=${FZF_DEFAULT_COMMAND-unset}"
print -r -- "OPTS=$FZF_DEFAULT_OPTS"; print -r -- "T=$FZF_CTRL_T_OPTS"; print -r -- "C=$FZF_ALT_C_OPTS"' || return 1
    [[ $(<"$TEST_ROOT/out") == $'LS=unset MAN=unset GIT=unset CMD=unset\nOPTS=--height=40% --layout=reverse --border --info=inline\nT=--preview \'head -n 300 {}\'\nC=--preview \'ls -A {}\'' ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    [[ ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/err"; return 3; }
  }
  It 'leaves the native behaviour when vivid, bat, delta, fd and eza are missing'
    When run native_case
    The status should be success
  End
  tools_case() {
    emulate -L zsh
    all_tools
    theme_run '_ms_opt_theme_delta=on; _ms_opt_theme_bat_theme=Nord; source $THEME
print -r -- "LS=$LS_COLORS"; print -r -- "MAN=$MANPAGER ROFF=$MANROFFOPT BAT=$BAT_THEME"
print -r -- "GIT=$GIT_CONFIG_COUNT $GIT_CONFIG_KEY_0 ${GIT_CONFIG_VALUE_0#$MARKSHARC_HOME/}"
print -r -- "CMD=$FZF_DEFAULT_COMMAND|$FZF_CTRL_T_COMMAND"; print -r -- "T=$FZF_CTRL_T_OPTS"; print -r -- "C=$FZF_ALT_C_OPTS"
zstyle -s ":fzf-tab:complete:cd:x" fzf-preview p; print -r -- "CD=$p"
zstyle -s ":fzf-tab:complete:less:x" fzf-preview p; print -r -- "LESS=$p"
zstyle -s ":fzf-tab:x" use-fzf-default-opts p; print -r -- "DEF=$p"
print -r -- "EXPORTED=${(t)LS_COLORS} ${(t)MANPAGER} ${(t)GIT_CONFIG_COUNT}"' || return 1
    local -a want=(
      'LS=di=01;34:ln=01;36'
      "MAN=sh -c 'col -bx | bat -l man -p' ROFF=-c BAT=Nord"
      'GIT=1 include.path modules/theme/delta.gitconfig'
      'CMD=fd --type f --hidden --follow --exclude .git|fd --type f --hidden --follow --exclude .git'
      "T=--preview 'bat --color=always --style=numbers --line-range=:300 {}'"
      "C=--preview 'eza --tree --level=2 --color=always {} | head -n 200'"
      'CD=eza --tree --level=2 --color=always $realpath | head -n 200'
      'LESS=bat --color=always --style=numbers --line-range=:300 $realpath'
      'DEF=yes'
      'EXPORTED=scalar-export scalar-export scalar-export'
    )
    [[ $(<"$TEST_ROOT/out") == ${(F)want} ]] || { diff <(print -r -- ${(F)want}) "$TEST_ROOT/out"; cat "$TEST_ROOT/err"; return 2; }
    [[ $(<"$OPLOG") == 'vivid generate molokai' ]] || { cat "$OPLOG"; return 3; }
    # A later shell takes LS_COLORS from the cache without running vivid.
    theme_run 'source $THEME; print -r -- "LS=$LS_COLORS"' || return 4
    [[ $(<"$TEST_ROOT/out") == 'LS=di=01;34:ln=01;36' && $(<"$OPLOG") == 'vivid generate molokai' ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 5; }
  }
  It 'sets LS_COLORS from cached vivid output, bat as man pager, the delta include and fzf previews'
    When run tools_case
    The status should be success
  End
  fallback_tools_case() {
    emulate -L zsh
    stub_command batcat 'exit 0'; stub_command col 'exit 0'; stub_command rg 'exit 0'
    theme_run '_ms_opt_theme_delta=on; source $THEME; print -r -- "MAN=$MANPAGER|CMD=$FZF_DEFAULT_COMMAND|GIT=${GIT_CONFIG_COUNT-unset}"' || return 1
    [[ $(<"$TEST_ROOT/out") == "MAN=sh -c 'col -bx | batcat -l man -p'|CMD=rg --files --hidden --glob '!.git'|GIT=unset" ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
  }
  It "uses Debian's batcat and rg when bat and fd are absent, and no include without delta"
    When run fallback_tools_case
    The status should be success
  End
  reload_case() {
    emulate -L zsh
    all_tools
    # An include already in the environment is kept; ours is appended, then removed on reload.
    theme_run 'export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=core.editor GIT_CONFIG_VALUE_0=vi
_ms_opt_theme_delta=on; source $THEME; print -r -- "ON=$GIT_CONFIG_COUNT $GIT_CONFIG_KEY_1"
_ms_opt_theme_delta=off; _ms_opt_theme_ls_colors=off; _ms_opt_theme_fzf=off; _ms_opt_theme_man_pager=off; source $THEME
print -r -- "OFF=$GIT_CONFIG_COUNT $GIT_CONFIG_KEY_0=$GIT_CONFIG_VALUE_0 ${GIT_CONFIG_KEY_1-gone} ${LS_COLORS-unset} ${MANPAGER-unset} ${FZF_DEFAULT_OPTS-unset}"
zstyle -s ":fzf-tab:x" use-fzf-default-opts p || print -r -- "ZSTYLE=gone"
_ms_opt_theme_delta=on; source $THEME; source $THEME; print -r -- "TWICE=$GIT_CONFIG_COUNT"' || return 1
    [[ $(<"$TEST_ROOT/out") == $'ON=2 include.path\nOFF=1 core.editor=vi gone unset unset unset\nZSTYLE=gone\nTWICE=2' ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
  }
  It 'removes what it set when an option is switched off on reload, and is safe to source twice'
    When run reload_case
    The status should be success
  End
  order_case() {
    emulate -L zsh
    # LS_COLORS must exist before completion reads it for its list colours.
    local theme=${${(M)${(f)"$(<"$MARKSHARC_ROOT/modules/theme/module.conf")"}:#order *}#order }
    local completion=${${(M)${(f)"$(<"$MARKSHARC_ROOT/modules/completion/module.conf")"}:#order *}#order }
    (( theme < completion ))
  }
  It 'loads before the completion module'
    When run order_case
    The status should be success
  End
End
