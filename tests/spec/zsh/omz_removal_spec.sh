Describe 'Oh-My-Zsh removal'
  no_live_omz_references_case() {
    emulate -L zsh
    local matches grep_status
    matches=$(git -C "$MARKSHARC_ROOT" grep -n -E \
      -e 'zsh\.zshrc\.ohmyzsh' \
      -e 'oh-my-zsh\.sh' \
      -e '\.p10k\.zsh' \
      -e 'ZSH_DISABLE_COMPFIX' \
      -e 'OPS1' \
      -e 'VCPS1' \
      -- core modules)
    grep_status=$?
    (( grep_status == 1 )) && return 0
    print -r -- "$matches"
    return 1
  }
  It 'has no live OMZ, p10k, COMPFIX, or legacy prompt references'
    When run no_live_omz_references_case
    The status should be success
  End
End

Describe 'removed cloud startup integration'
  # The whole zsh tree starts in a PTY with kubectl and gcloud fixtures that fail the
  # example when startup touches them.
  cloud_startup_removal_case() {
    emulate -L zsh
    ms_fixture_full
    local tool cloud_root sname
    # Tools that other startup code may run are benign here; only cloud tools may fail.
    for tool in zoxide starship atuin herdr cwf; do
      printf '#!/bin/sh\nexit 0\n' > "$TEST_ROOT/bin/$tool"
      chmod +x "$TEST_ROOT/bin/$tool"
    done
    for cloud_root in "$HOME/tmp" "$HOME"; do
      mkdir -p "$cloud_root/google-cloud-sdk"
      for sname in path completion; do
        print 'print FORBIDDEN_GCLOUD >> "$OPLOG"' > "$cloud_root/google-cloud-sdk/$sname.zsh.inc"
      done
    done
    cat > "$TEST_ROOT/bin/kubectl" <<'DATA'
#!/bin/sh
printf 'FORBIDDEN kubectl %s\n' "$*" >> "$OPLOG"
[ "$1" != completion ] || printf ':\n'
DATA
    chmod +x "$TEST_ROOT/bin/kubectl"
    ms_pty -dic 'print -r -- "KCPATH=${KCPATH-} plugins=${plugins[*]-}"; print READY' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *READY* && $out == *'KCPATH= plugins='* ]] || { print -r -- "$out"; return 2; }
    [[ ! -s $OPLOG ]] || { print -r -- "$(<"$OPLOG")"; return 3; }
  }
  It 'does not discover kubectl or source legacy cloud integrations'
    When run cloud_startup_removal_case
    The status should be success
  End
End

Describe 'pinned offline plugin loading'
  # The installed fzf-tab checkout pin (see modules/completion-fzf-tab/zsh.plugins).
  FZF_TAB_SHA=24105b15714bfec37989ed5c5b6e60f572253019

  missing_plugin_case() {
    emulate -L zsh
    load_mfn completion-fzf-tab
    zsh-plugin-load fzf-tab $FZF_TAB_SHA source
    [[ $? == 0 && ! -s $OPLOG ]]
  }
  It 'skips a missing plugin clone silently'
    When run missing_plugin_case
    The status should be success
  End

  sources_clone_case() {
    emulate -L zsh
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    mkdir -p "$root"
    print 'print FZF_TAB >> "$OPLOG"' > "$root/fzf-tab.plugin.zsh"
    load_mfn completion-fzf-tab
    zsh-plugin-load fzf-tab $FZF_TAB_SHA source || return 1
    [[ $(<"$OPLOG") == FZF_TAB ]]
  }
  It 'sources the pinned clone entry file'
    When run sources_clone_case
    The status should be success
  End

  prefers_entry_order_case() {
    emulate -L zsh
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    mkdir -p "$root"
    print 'print WRONG_ENTRY >> "$OPLOG"' > "$root/init.zsh"
    print 'print FZF_TAB >> "$OPLOG"' > "$root/fzf-tab.plugin.zsh"
    load_mfn completion-fzf-tab
    zsh-plugin-load fzf-tab $FZF_TAB_SHA source || return 1
    [[ $(<"$OPLOG") == FZF_TAB ]]
  }
  It 'prefers <name>.plugin.zsh over init.zsh'
    When run prefers_entry_order_case
    The status should be success
  End

  empty_clone_case() {
    emulate -L zsh
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    mkdir -p "$root"
    load_mfn completion-fzf-tab
    zsh-plugin-load fzf-tab $FZF_TAB_SHA source
    [[ $? == 0 && ! -s $OPLOG ]]
  }
  It 'tolerates a clone without any entry file'
    When run empty_clone_case
    The status should be success
  End

  fpath_kind_case() {
    emulate -L zsh
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA" FPATH="$FPATH"
    mkdir -p "$root"
    load_mfn completion-fzf-tab
    local before=${#fpath}
    zsh-plugin-load fzf-tab $FZF_TAB_SHA fpath || return 1
    [[ $fpath[1] == $root && ${#fpath} == $(( before + 1 )) ]]
  }
  It 'prepends the clone directory to fpath for the fpath kind'
    When run fpath_kind_case
    The status should be success
  End

  unknown_kind_case() {
    emulate -L zsh
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    mkdir -p "$root"
    load_mfn completion-fzf-tab
    zsh-plugin-load fzf-tab $FZF_TAB_SHA bogus
    [[ $? == 2 ]]
  }
  It 'rejects an unknown plugin kind'
    When run unknown_kind_case
    The status should be success
  End
End

Describe 'explicit pinned plugin update'
  FZF_TAB_SHA=24105b15714bfec37989ed5c5b6e60f572253019

  git_log_stub() {
    cat > "$TEST_ROOT/bin/git" <<'DATA'
#!/bin/sh
printf '%s\n' "$*" >> "$OPLOG"
last=
for arg do last=$arg; done
if [ "$1" = clone ]; then
  mkdir -p "$last"
fi
DATA
    chmod +x "$TEST_ROOT/bin/git"
  }

  pinned_update_case() {
    emulate -L zsh
    local MARKSHARC_HOME="$MARKSHARC_ROOT"
    git_log_stub
    load_mfn completion-fzf-tab
    zsh-plugin-update || return 1
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    [[ -d $root ]] || return 1
    [[ $(<"$OPLOG") == *"clone --no-checkout https://github.com/Aloxaf/fzf-tab $root"* ]] || return 2
    [[ $(<"$OPLOG") == *"-C $root checkout --detach $FZF_TAB_SHA"* ]]
  }
  It 'clones and checks out the pinned SHA for a new plugin'
    When run pinned_update_case
    The status should be success
  End

  inline_comment_update_case() {
    emulate -L zsh
    local MARKSHARC_HOME="$TEST_ROOT/zdir"
    mkdir -p "$MARKSHARC_HOME/modules/completion-fzf-tab"
    print -r -- "plugin fzf-tab 'https://example.invalid/repo#fragment' $FZF_TAB_SHA shell zsh # kind fpath" > "$MARKSHARC_HOME/modules/completion-fzf-tab/zsh.plugins"
    git_log_stub
    load_mfn completion-fzf-tab
    zsh-plugin-update || return 1
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    [[ $(<"$OPLOG") == *"clone --no-checkout https://example.invalid/repo#fragment $root"* ]] || return 2
    [[ $(<"$OPLOG") == *"-C $root checkout --detach $FZF_TAB_SHA"* ]]
  }
  It 'accepts inline comments and preserves a hash inside quotes'
    When run inline_comment_update_case
    The status should be success
  End

  existing_clone_case() {
    emulate -L zsh
    local MARKSHARC_HOME="$MARKSHARC_ROOT"
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    mkdir -p "$root/.git"
    git_log_stub
    load_mfn completion-fzf-tab
    zsh-plugin-update || return 1
    [[ $(<"$OPLOG") != *"clone --no-checkout https://github.com/Aloxaf/fzf-tab $root"* ]] || return 2
    [[ $(<"$OPLOG") == *"-C $root checkout --detach $FZF_TAB_SHA"* ]]
  }
  It 'checks out the pin on an existing clone without recloning'
    When run existing_clone_case
    The status should be success
  End

  nongit_path_case() {
    emulate -L zsh
    local MARKSHARC_HOME="$MARKSHARC_ROOT"
    local root="$XDG_CACHE_HOME/marksharc/plugins/fzf-tab@$FZF_TAB_SHA"
    mkdir -p "$root"
    print keep > "$root/sentinel"
    git_log_stub
    load_mfn completion-fzf-tab
    if zsh-plugin-update 2> "$TEST_ROOT/err"; then return 1; fi
    [[ $(<"$root/sentinel") == keep ]] || return 2
    [[ ! -s $OPLOG && -s $TEST_ROOT/err ]]
  }
  It 'refuses to overwrite an existing non-git path'
    When run nongit_path_case
    The status should be success
  End

  malformed_registry_case() {
    emulate -L zsh
    local directive=$1
    local MARKSHARC_HOME="$TEST_ROOT/zdir"
    mkdir -p "$MARKSHARC_HOME/modules/completion-fzf-tab"
    print -r -- "$directive" > "$MARKSHARC_HOME/modules/completion-fzf-tab/zsh.plugins"
    git_log_stub
    load_mfn completion-fzf-tab
    if zsh-plugin-update 2> "$TEST_ROOT/err"; then return 1; fi
    [[ ! -s $OPLOG && -s $TEST_ROOT/err ]]
  }
  Describe 'rejects malformed directives without evaluating them'
    Parameters:value \
      'plugin' \
      'plugin fzf-tab' \
      'plugin fzf-tab https://github.com/Aloxaf/fzf-tab' \
      'plugin fzf-tab https://github.com/Aloxaf/fzf-tab 24105b15714bfec37989ed5c5b6e60f572253019 shell' \
      'plugin fzf-tab https://github.com/Aloxaf/fzf-tab 24105b15714bfec37989ed5c5b6e60f572253019 bogus x' \
      "plugin fzf-tab https://example.invalid/repo 0123456789012345678901234567890123456789 shell 'zsh kind source" \
      'notaplugin fzf-tab https://github.com/Aloxaf/fzf-tab 24105b15714bfec37989ed5c5b6e60f572253019'
    It "rejects: $1"
      When run malformed_registry_case "$1"
      The status should be success
    End
  End

  no_eval_case() {
    emulate -L zsh
    local MARKSHARC_HOME="$TEST_ROOT/zdir"
    mkdir -p "$MARKSHARC_HOME/modules/completion-fzf-tab"
    print -r -- "plugin evil '\$(printf PWNED >> \"\$OPLOG\")' 0123456789012345678901234567890123456789 shell zsh kind source" > "$MARKSHARC_HOME/modules/completion-fzf-tab/zsh.plugins"
    git_log_stub
    load_mfn completion-fzf-tab
    zsh-plugin-update || return 1
    ! grep -q '^PWNED$' "$OPLOG"
  }
  It 'never evaluates directive contents'
    When run no_eval_case
    The status should be success
  End
End

Describe 'native directory navigation'
  navigation_bindings_case() {
    emulate -L zsh
    TERM_PROGRAM=iTerm.app
    TERM=xterm-256color
    zmodload zsh/terminfo || return 1
    . "$MARKSHARC_ROOT/modules/nav/init.zsh" || return 2

    local name
    for name in dirhistory_back dirhistory_forward dirhistory_up dirhistory_down \
      dirhistory_zle_dirhistory_back dirhistory_zle_dirhistory_future \
      dirhistory_zle_dirhistory_up dirhistory_zle_dirhistory_down \
      insert-cycledleft insert-cycledright insert-cycledup insert-cycleddown; do
      (( $+functions[$name] )) || return 3
    done
    for name in dirhistory_zle_dirhistory_back dirhistory_zle_dirhistory_future \
      dirhistory_zle_dirhistory_up dirhistory_zle_dirhistory_down \
      insert-cycledleft insert-cycledright insert-cycledup insert-cycleddown; do
      (( ${+widgets[$name]} )) || return 4
    done

    local keymap direction sequence widget terminfo_key
    local -a sequences
    local -A suffixes=(left D right C up A down B)
    local -A terminfo_keys=(left kcub1 right kcuf1 up kcuu1 down kcud1)
    local -A navigation_widgets=(
      left dirhistory_zle_dirhistory_back
      right dirhistory_zle_dirhistory_future
      up dirhistory_zle_dirhistory_up
      down dirhistory_zle_dirhistory_down
    )
    local -A cycle_widgets=(
      D insert-cycledleft C insert-cycledright A insert-cycledup B insert-cycleddown
    )
    for keymap in emacs viins vicmd; do
      for direction in left right up down; do
        widget=$navigation_widgets[$direction]
        terminfo_key=$terminfo_keys[$direction]
        sequences=("\e[3$suffixes[$direction]" "\e[1;3$suffixes[$direction]"
          "\e\e[$suffixes[$direction]" "\eO3$suffixes[$direction]"
          "^[^[[$suffixes[$direction]")
        [[ -n ${terminfo[$terminfo_key]:-} ]] && sequences+=("^[${terminfo[$terminfo_key]}")
        for sequence in "${sequences[@]}"; do
          [[ $(bindkey -M "$keymap" "$sequence") == *" $widget" ]] || {
            print -r -- "unbound: $keymap $direction ${(q)sequence}: $(bindkey -M "$keymap" "$sequence")"
            return 5
          }
        done
      done
      for sequence in D C A B; do
        [[ $(bindkey -M "$keymap" "\e[1;6$sequence") == *" $cycle_widgets[$sequence]" ]] || return 6
      done
    done
  }
  It 'defines navigation functions and widgets in every keymap'
    When run navigation_bindings_case
    The status should be success
  End

  navigation_history_case() {
    emulate -L zsh
    local root="$TEST_ROOT/navigation root"
    mkdir -p "$root/one" "$root/two" || return 1
    cd "$root" || return 2
    . "$MARKSHARC_ROOT/modules/nav/init.zsh" || return 3
    cd "$root/one" && cd "$root/two" || return 4
    dirhistory_back || return 5
    [[ $PWD == "$root/one" ]] || return 6
    dirhistory_forward || return 7
    [[ $PWD == "$root/two" ]] || return 8
    dirhistory_back || return 9
    cd "$root/two" || return 10
    dirhistory_forward || return 11
    [[ $PWD == "$root/two" ]] || return 12
    cd "$root/one" && dirhistory_up || return 13
    [[ $PWD == "$root" ]] || return 14
    mkdir -p "$root/alpha child" || return 15
    dirhistory_down || return 16
    [[ $PWD == "$root/alpha child" ]] || return 17
    mkdir -p "$root/empty" && cd "$root/empty" || return 18
    if dirhistory_down; then return 19; fi
    [[ $PWD == "$root/empty" ]]
  }
  It 'preserves spaced paths and clears forward history on normal cd'
    When run navigation_history_case
    The status should be success
  End

  navigation_limits_case() {
    emulate -L zsh
    local root="$TEST_ROOT/history limit"
    mkdir -p "$root/start" && cd "$root/start" || return 1
    . "$MARKSHARC_ROOT/modules/nav/init.zsh" || return 2
    dirhistory_cd "$PWD" || return 3
    [[ $#dirhistory_past == 1 ]] || return 4
    local DIRHISTORY_SIZE=3 n
    for n in one two three four; do
      mkdir -p "$root/$n" && cd "$root/$n" || return 5
    done
    [[ $#dirhistory_past == 3 && $dirhistory_past[1] == "$root/two" &&
      $dirhistory_past[-1] == "$root/four" ]]
  }
  It 'deduplicates consecutive entries and caps directory history'
    When run navigation_limits_case
    The status should be success
  End

  navigation_reload_case() {
    emulate -L zsh
    local root="$TEST_ROOT/navigation reload"
    mkdir -p "$root/one" "$root/two" || return 1
    cd "$root" || return 2
    . "$MARKSHARC_ROOT/modules/nav/init.zsh" || return 3
    cd "$root/one" && cd "$root/two" || return 4
    . "$MARKSHARC_ROOT/modules/nav/init.zsh" || return 5
    dirhistory_back || return 6
    [[ $PWD == "$root/one" ]] || return 7
    dirhistory_forward || return 8
    [[ $PWD == "$root/two" ]]
  }
  It 'preserves back and forward history when navigation is reloaded'
    When run navigation_reload_case
    The status should be success
  End
End

Describe 'native coloured man pages'
  pager_environment_case() {
    emulate -L zsh
    cat > "$TEST_ROOT/bin/env" <<'DATA'
#!/bin/sh
for arg do printf 'ENV:%s\n' "$arg" >> "$OPLOG"; done
while [ "$#" -gt 0 ]; do
  case $1 in *=*) shift ;; *) break ;; esac
done
exec "$@"
DATA
    cat > "$TEST_ROOT/bin/man" <<'DATA'
#!/bin/sh
printf 'MAN:%s:%s\n' "$#" "$1" >> "$OPLOG"
DATA
    chmod +x "$TEST_ROOT/bin/env" "$TEST_ROOT/bin/man"
    hash -r
    . "$MARKSHARC_ROOT/modules/pager/init.zsh" || return 1
    local name
    for name in colored man dman debman; do (( $+functions[$name] )) || return 2; done
    man printf || return 3
    local log=$(<"$OPLOG") key
    local -A expected=(
      mb "${fg_bold[red]}" md "${fg_bold[red]}" me "$reset_color"
      so "${fg_bold[yellow]}${bg[blue]}" se "$reset_color"
      us "${fg_bold[green]}" ue "$reset_color"
    )
    for key in mb md me so se us ue; do
      [[ $log == *"ENV:LESS_TERMCAP_$key=$expected[$key]"* ]] || return 4
    done
    for key in GROFF_NO_SGR=1 LC_ALL=C LANG=C; do
      [[ $log == *"ENV:$key"* ]] || return 5
    done
    [[ $log == *$'ENV:printf\nMAN:1:printf'* ]]
  }
  It 'passes all colours and the C locale while preserving man arguments'
    When run pager_environment_case
    The status should be success
  End
End

Describe 'native command-not-found dispatch'
  homebrew_handler_case() {
    emulate -L zsh
    mkdir -p "$TEST_ROOT/Library/Homebrew/command-not-found" || return 1
    cat > "$TEST_ROOT/Library/Homebrew/command-not-found/handler.sh" <<'DATA'
command_not_found_handler() {
  print -r -- "$1" >> "$OPLOG"
  return 127
}
DATA
    hash -r
    . "$MARKSHARC_ROOT/modules/command-not-found/init.zsh" || return 2
    command_not_found_handler missing-command
    [[ $? == 127 && $(<"$OPLOG") == missing-command ]]
  }
  It 'dispatches to the Homebrew handler derived from the brew path'
    When run homebrew_handler_case
    The status should be success
  End

  intel_homebrew_handler_case() {
    emulate -L zsh
    local prefix="$TEST_ROOT/intel/usr/local"
    mkdir -p "$prefix/bin" "$prefix/Homebrew/bin" \
      "$prefix/Homebrew/Library/Homebrew/command-not-found" || return 1
    cat > "$prefix/Homebrew/bin/brew" <<'DATA'
#!/bin/sh
exit 0
DATA
    cat > "$prefix/Homebrew/Library/Homebrew/command-not-found/handler.sh" <<'DATA'
command_not_found_handler() {
  print -r -- "intel:$1" >> "$OPLOG"
  return 127
}
DATA
    chmod +x "$prefix/Homebrew/bin/brew" || return 2
    ln -s ../Homebrew/bin/brew "$prefix/bin/brew" || return 3
    path=("$prefix/bin" /usr/bin /bin /usr/sbin /sbin)
    hash -r
    . "$MARKSHARC_ROOT/modules/command-not-found/init.zsh" || return 4
    command_not_found_handler missing-command
    [[ $? == 127 && $(<"$OPLOG") == intel:missing-command ]]
  }
  It 'resolves an Intel brew symlink before locating the Homebrew handler'
    When run intel_homebrew_handler_case
    The status should be success
  End

  apt_handler_case() {
    emulate -L zsh
    path=(/usr/bin /bin /usr/sbin /sbin)
    hash -r
    . "$MARKSHARC_ROOT/modules/command-not-found/init.zsh" || return 1
    cat > "$TEST_ROOT/bin/apt-handler" <<'DATA'
#!/bin/sh
printf '%s\n' "$*" >> "$OPLOG"
exit 23
DATA
    chmod +x "$TEST_ROOT/bin/apt-handler"
    command_not_found_apt_candidates=("$TEST_ROOT/bin/missing" "$TEST_ROOT/bin/apt-handler")
    command_not_found_handler missing-command
    [[ $? == 23 && $(<"$OPLOG") == '-- missing-command' ]]
  }
  It 'uses the first executable apt candidate and returns its status'
    When run apt_handler_case
    The status should be success
  End

  missing_handler_case() {
    emulate -L zsh
    path=(/usr/bin /bin /usr/sbin /sbin)
    hash -r
    . "$MARKSHARC_ROOT/modules/command-not-found/init.zsh" || return 1
    command_not_found_apt_candidates=()
    command_not_found_handler missing-command 2> "$TEST_ROOT/error"
    [[ $? == 127 && $(<"$TEST_ROOT/error") == 'zsh: command not found: missing-command' ]]
  }
  It 'quotes the missing command and returns 127 without a provider'
    When run missing_handler_case
    The status should be success
  End
End
