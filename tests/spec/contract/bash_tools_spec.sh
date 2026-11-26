Describe 'Bash tool integrations'
  Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
  Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"

  prepare_tools() {
    export MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_CONFIG="$HOME/config with spaces" MARKSHARC_NOTIFY=0
    mkdir -p "$MARKSHARC_CONFIG" "$HOME/project/child"
    cat > "$HOME/.bashrc" <<'EOF'
PS1='plain> '
PROMPT_COMMAND='printf "foreign:%s:%s\n" "$?" "${PIPESTATUS[*]}" >> "$TEST_ROOT/prompt"'
source "$MARKSHARC_HOME/core/bash/bashrc.bash"
EOF
    stub_command herdr 'case "$*" in "completion zsh") printf "#compdef herdr\n" ;; *) exit 99 ;; esac'
    printf '%s\n' 'module history-native' 'module prompt-starship off' 'module history-atuin off' \
      'module zoxide off' 'module direnv off' 'module brew off' > "$MARKSHARC_CONFIG/config.conf"
  }

  terminal() {
    "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty "${MARKSHARC_TEST_BASH:-bash}" "$@" \
      > "$TEST_ROOT/out" 2>&1 || { status=$?; cat "$TEST_ROOT/out"; return "$status"; }
  }

  native_failure() {
    prepare_tools
    if [ "$1" != disabled ]; then printf 'module history-atuin\n' >> "$MARKSHARC_CONFIG/config.conf"; fi
    case $1 in
      disabled)
        printf '%s\n' "alias h='printf user-history'" \
          'source "$MARKSHARC_HOME/core/bash/bashrc.bash"' > "$HOME/.bashrc"
        ;;
      failed) stub_command atuin 'printf "incomplete"; exit 1' ;;
      empty) stub_command atuin 'exit 0' ;;
      backendless) stub_command atuin 'printf "%s\n" "ATUIN_SESSION=stale" "__atuin_preexec() { :; }" "__atuin_precmd() { :; }"' ;;
      missing)
        # Warm the renderer before narrowing PATH to a directory without Atuin.
        "$MARKSHARC_HOME/bin/marksharc" render >/dev/null || return 1
        mkdir "$TEST_ROOT/command-only"
        ln -s "$(command -v mkdir)" "$TEST_ROOT/command-only/mkdir"
        printf '%s\n' 'PATH="$TEST_ROOT/command-only"' \
          'source "$MARKSHARC_HOME/core/bash/bashrc.bash"' > "$HOME/.bashrc"
        ;;
    esac
    PTY_INPUT='echo recorded-native
exit
' terminal -i || return 1
    if [ ! -f "$XDG_STATE_HOME/marksharc/history.bash" ]; then cat "$TEST_ROOT/out"; return 2; fi
    grep -Fx 'echo recorded-native' "$XDG_STATE_HOME/marksharc/history.bash"
  }

  It 'persists native history when Atuin is disabled'
    When run native_failure disabled
    The status should be success
    The output should equal 'echo recorded-native'
  End

  It 'persists native history when Atuin init fails'
    When run native_failure failed
    The status should be success
    The output should equal 'echo recorded-native'
  End

  It 'persists native history when Atuin init is empty'
    When run native_failure empty
    The status should be success
    The output should equal 'echo recorded-native'
  End

  It 'persists native history when the Atuin executable is missing'
    When run native_failure missing
    The status should be success
    The output should equal 'echo recorded-native'
  End

  It 'persists native history when Atuin cannot establish a hook backend'
    When run native_failure backendless
    The status should be success
    The output should equal 'echo recorded-native'
  End

  prepare_prompt_tools() {
    printf '%s\n' 'module prompt-starship' 'set prompt-starship.config rich' \
      'module zoxide' 'module direnv' 'set direnv.enable on' >> "$MARKSHARC_CONFIG/config.conf"
    stub_command starship 'case "$*" in
      "init bash --print-full-init")
        echo starship >> "$TEST_ROOT/generated"
        cat <<\EOF
starship_preexec() { :; }
starship_precmd() {
  printf "starship:%s:%s:%s\n" "$?" "${BP_PIPESTATUS[*]}" "$STARSHIP_CONFIG" >> "$TEST_ROOT/prompt"
  PS1="starship> "
}
precmd_functions+=(starship_precmd)
EOF
        ;;
      time) printf "10\n" ;;
      *) exit 91 ;;
    esac'
    stub_command zoxide 'case "$*" in
      "init bash --hook none")
        echo zoxide >> "$TEST_ROOT/generated"
        printf "%s\n" "z() { builtin cd -- \"\$1\"; }" "zi() { z \"\$@\"; }" "complete -W one z"
        ;;
      "add -- "*) printf "zoxide:%s\n" "$3" >> "$TEST_ROOT/dirs" ;;
      *) exit 92 ;;
    esac'
    stub_command direnv 'case "$*" in
      "hook bash")
        echo direnv >> "$TEST_ROOT/generated"
        printf "%s\n" "_direnv_hook() { export DIRENV_PROBE=ready; }" "PROMPT_COMMAND=_direnv_hook"
        ;;
      *) exit 93 ;;
    esac'
  }

  prompt_case() {
    prepare_tools
    prepare_prompt_tools
    PTY_INPUT='false | true
! false | true
z "$HOME/project"
true
[[ $DIRENV_PROBE == ready ]] || exit 11
complete -p z || exit 12
marksharc reload || exit 13
true
printf "%s\n" "module zoxide off" >> "$MARKSHARC_CONFIG/config.conf"
marksharc reload || exit 14
[[ -z $(type -t z) ]] && ! complete -p z 2>/dev/null || exit 15
exit
' terminal -i || return 1
    grep -Fx 'foreign:0:1 0' "$TEST_ROOT/prompt" >/dev/null &&
      grep -Fx "starship:0:1 0:$MARKSHARC_ROOT/modules/prompt-starship/presets/rich.toml" "$TEST_ROOT/prompt" >/dev/null &&
      grep -Fx 'foreign:1:1 0' "$TEST_ROOT/prompt" >/dev/null &&
      [ "$(grep -Fxc "zoxide:$HOME/project" "$TEST_ROOT/dirs")" = 1 ] &&
      [ "$(sort -u "$TEST_ROOT/generated" | wc -l)" -eq 3 ] &&
      [ "$(wc -l < "$TEST_ROOT/generated")" -eq 3 ]
  }

  It 'composes cached tools with a foreign prompt and tracks navigation completion on reload'
    When run prompt_case
    The status should be success
  End

  atuin_case() {
    prepare_tools
    printf 'module history-atuin\n' >> "$MARKSHARC_CONFIG/config.conf"
    # These are the documented callback arrays injected into Readline by bash-preexec.
    cat > "$HOME/.bashrc" <<'EOF'
foreign_preexec() { :; }
preexec_functions=(foreign_preexec)
precmd_functions=()
bash_preexec_imported=defined
__bp_precmd_invoke_cmd() { :; }
PROMPT_COMMAND=__bp_precmd_invoke_cmd
PS1='history> '
source "$MARKSHARC_HOME/core/bash/bashrc.bash"
EOF
    stub_command atuin 'case "$*" in
      "init bash")
        echo init >> "$TEST_ROOT/generated"
        cat <<\EOF
ATUIN_SESSION=${ATUIN_SESSION:-$(atuin uuid)}
export ATUIN_SESSION
__atuin_preexec() { printf "start:%s\n" "$1" >> "$TEST_ROOT/record"; }
__atuin_precmd() { printf "end:%s\n" "$?" >> "$TEST_ROOT/record"; }
preexec_functions+=(__atuin_preexec)
precmd_functions+=(__atuin_precmd)
bind -m emacs -x "\"\\C-r\":__atuin_preexec search"
EOF
        ;;
      uuid) printf "session-%s\n" "$$" ;;
      "history list --format "*) printf "one\ntwo\nthree\n" ;;
      *) exit 94 ;;
    esac'
    terminal -ic '
      [[ -n $ATUIN_SESSION && -z ${HISTFILE-} ]] || exit 21
      parent=$ATUIN_SESSION
      [[ $(history -2) == $'"'"'two\nthree'"'"' && $(h) == $'"'"'one\ntwo\nthree'"'"' ]] || exit 22
      history -s "builtin sentinel"
      [[ $(builtin history 1) == *"builtin sentinel" ]] || exit 23
      "$BASH" -ic '"'"'printf "%s\n" "$ATUIN_SESSION" > "$TEST_ROOT/session"'"'"' || exit 24
      [[ $(<"$TEST_ROOT/session") != "$parent" ]] || exit 25
      marksharc reload && marksharc reload || exit 26
      [[ $ATUIN_SESSION == "$parent" ]] || exit 27
      for hook in "${preexec_functions[@]}"; do "$hook" sample; done
      for hook in "${precmd_functions[@]}"; do "$hook"; done
      printf "module history-atuin off\n" >> "$MARKSHARC_CONFIG/config.conf"
      marksharc reload || exit 28
      [[ $HISTFILE == "$XDG_STATE_HOME/marksharc/history.bash" &&
         ${preexec_functions[*]} == foreign_preexec &&
         $(bind -m emacs -p) == *"\"\\C-r\": reverse-search-history"* ]] || {
        declare -p HISTFILE preexec_functions
        bind -m emacs -p | grep -F reverse-search-history
        bind -m emacs -X
        exit 29
      }
    ' || return
    [ "$(grep -Fxc start:sample "$TEST_ROOT/record")" = 1 ] &&
      [ "$(wc -l < "$TEST_ROOT/generated")" -eq 1 ]
  }

  It 'maintains one recording and binding registration across reload and gives children new sessions'
    When run atuin_case
    The status should be success
  End

  ble_case() {
    prepare_tools
    printf 'module history-atuin\n' >> "$MARKSHARC_CONFIG/config.conf"
    cat > "$HOME/.bashrc" <<'EOF'
blehook() { printf '%s\n' "$1" >> "$TEST_ROOT/ble"; }
BLE_VERSION=0.4
source "$MARKSHARC_HOME/core/bash/bashrc.bash"
EOF
    stub_command atuin 'case "$*" in
      "init bash")
        cat <<\EOF
[[ $ATUIN_NO_BUILTIN_PREEXEC == 1 ]] || return 1
export ATUIN_SESSION=ble-session
__atuin_preexec() { printf "start:%s\n" "$1" >> "$TEST_ROOT/record"; }
__atuin_precmd() { printf "end:%s\n" "$?" >> "$TEST_ROOT/record"; }
preexec_functions+=(__atuin_preexec)
precmd_functions+=(__atuin_precmd)
EOF
        ;;
      *) exit 96 ;;
    esac'
    terminal -ic '
      [[ -z ${HISTFILE-} ]] || exit 41
      _ms_bash_preexec_dispatch ble-command
      BLE_PIPESTATUS=(2 0)
      _ms_bash_prompt_return 2
      _ms_bash_ble_prompt
      printf "module history-atuin off\n" >> "$MARKSHARC_CONFIG/config.conf"
      marksharc reload
      [[ $HISTFILE == "$XDG_STATE_HOME/marksharc/history.bash" ]] || exit 42
    ' || return 1
    cat "$TEST_ROOT/record" "$TEST_ROOT/ble"
  }

  It 'records through ble.sh callbacks and removes its registrations on disable'
    When run ble_case
    The status should be success
    The output should equal 'start:ble-command
end:2
PRECMD!=_ms_bash_ble_prompt
PREEXEC!=_ms_bash_preexec_dispatch
PRECMD-=_ms_bash_ble_prompt
PREEXEC-=_ms_bash_preexec_dispatch'
  End

  manager_case() {
    prepare_tools
    printf '%s\n' 'module mise' 'module path' 'module python' 'module node-nvm' 'module go-gvm' \
      'set mise.tools "node"' >> "$MARKSHARC_CONFIG/config.conf"
    mkdir -p "$HOME/.nvm/alias" "$HOME/.nvm/versions/node/v20.0.0/bin" \
      "$HOME/.nvm/versions/node/v22.0.0/bin" "$HOME/.gvm/scripts" "$HOME/.gvm/gos/go1.24/bin" \
      "$HOME/.gvm/gos/go1.25/bin" "$HOME/.gvm/environments" "$XDG_DATA_HOME/mise/shims" \
      "$HOME/.pyenv/bin" "$HOME/.pyenv/shims" "$HOME/project/unavailable"
    printf '20\n' > "$HOME/.nvm/alias/default"
    printf '22\n' > "$HOME/project/.nvmrc"
    printf 'module probe\n\ngo 1.25\n' > "$HOME/project/go.mod"
    printf '999\n' > "$HOME/project/unavailable/.nvmrc"
    printf 'module probe\n\ngo 1.99\n' > "$HOME/project/unavailable/go.mod"
    printf 'export gvm_go_name=go1.24\n' > "$HOME/.gvm/environments/default"
    for binary in "$HOME/.nvm/versions/node/v20.0.0/bin/node" "$HOME/.nvm/versions/node/v22.0.0/bin/node" \
      "$HOME/.gvm/gos/go1.24/bin/go" "$HOME/.gvm/gos/go1.25/bin/go"; do
      printf '#!/bin/sh\nprintf "%%s\\n" "$0"\n' > "$binary"
      chmod +x "$binary"
    done
    cat > "$HOME/.nvm/nvm.sh" <<'EOF'
printf 'nvm loaded\n' >> "$TEST_ROOT/managers"
nvm() {
  printf 'nvm:%s\n' "$*" >> "$TEST_ROOT/managers"
  case $1 in
    version) case ${2-} in 22) echo v22.0.0 ;; 999) echo N/A; return 3 ;; *) echo v20.0.0 ;; esac ;;
    use) export PATH="$NVM_DIR/versions/node/v22.0.0/bin:$PATH" ;;
    *) return 1 ;;
  esac
}
EOF
    cat > "$HOME/.gvm/scripts/gvm" <<'EOF'
printf 'gvm loaded\n' >> "$TEST_ROOT/managers"
cd() { return 31; }
gvm() {
  [[ $1 == use ]] || return 1
  export PATH="$GVM_ROOT/gos/$2/bin:$PATH" gvm_go_name=$2
}
EOF
    cat > "$HOME/.pyenv/bin/pyenv" <<'EOF'
#!/bin/sh
case "$*" in "init - bash") printf "pyenv() { :; }\n" ;; *) exit 1 ;; esac
EOF
    chmod +x "$HOME/.pyenv/bin/pyenv"
    stub_command uv 'exit 0'
    mv "$TEST_ROOT/bin/uv" "$TEST_ROOT/uv-stub"
    stub_command mise 'case "$*" in
      "activate bash --no-hook-env")
        printf "%s\n" "export MISE_SHELL=bash" "export __MISE_ORIG_PATH=\"\$PATH\""
        ;;
      "hook-env "*) printf "export PATH=\"\$HOME/managed-node/bin:\$PATH\"\n"; printf "hook\n" >> "$TEST_ROOT/mise" ;;
      "shell node@"*) printf "export MISE_NODE_VERSION=%s\n" "${2#node@}" ;;
      "current go") printf "1.25.2\n" ;;
      deactivate) printf "unset MISE_SHELL MISE_NODE_VERSION __MISE_ORIG_PATH\n" ;;
      *) exit 95 ;;
    esac'
    mkdir -p "$HOME/managed-node/bin"
    PTY_INPUT='[[ $(type -t pyenv) == function && $GOROOT == "$HOME/.gvm/gos/go1.24" ]] || exit 31
[[ ! -e $TEST_ROOT/managers ]] || exit 32
nvm use 22 && [[ $MISE_NODE_VERSION == 22 ]] || exit 33
cd "$HOME/project/child"
[[ $GOROOT == "$HOME/.gvm/gos/go1.25" ]] || exit 34
[[ -z $(type -t cd | grep function) ]] || exit 35
mise deactivate && [[ -z ${MISE_NODE_VERSION-} && :$PATH: != *":$HOME/managed-node/bin:"* ]] || exit 36
printf "set mise.hook off\n" >> "$MARKSHARC_CONFIG/config.conf"
marksharc reload
[[ $(type -t mise) == file && :$PATH: == *":$XDG_DATA_HOME/mise/shims:"* ]] || exit 37
printf "set mise.hook prompt\nset mise.tools \"node go python\"\n" >> "$MARKSHARC_CONFIG/config.conf"
marksharc reload
[[ $(gvm current) == 1.25.2 && -z ${GOROOT-} && -z $(type -t pyenv) ]] || exit 38
before=$(wc -l < "$TEST_ROOT/mise")
true
[[ $(wc -l < "$TEST_ROOT/mise") -gt "$before" ]] || exit 39
command mv "$TEST_ROOT/bin/mise" "$TEST_ROOT/mise-stub"
marksharc reload
[[ :$PATH: != *":$XDG_DATA_HOME/mise/shims:"* ]] || exit 40
[[ $(command -v node) == "$HOME/.nvm/versions/node/v22.0.0/bin/node" &&
   $(type -t pyenv) == function && $GOROOT == "$HOME/.gvm/gos/go1.25" ]] || exit 41
cd "$HOME/project/unavailable"
[[ $(command -v node) == "$HOME/.nvm/versions/node/v22.0.0/bin/node" &&
   $GOROOT == "$HOME/.gvm/gos/go1.25" ]] || exit 42
command mv "$TEST_ROOT/uv-stub" "$TEST_ROOT/bin/uv"
marksharc reload
[[ -z $(type -t pyenv) && :$PATH: != *":$HOME/.pyenv/shims:"* ]] || exit 43
exit
' terminal -i || return 1
    [ "$(grep -Fxc 'gvm loaded' "$TEST_ROOT/managers")" = 2 ] &&
      [ "$(grep -Fxc 'nvm loaded' "$TEST_ROOT/managers")" -ge 1 ] &&
      ! grep -Eq 'nvm:install|gvm:install' "$TEST_ROOT/managers"
  }

  It 'selects mise-owned Node immediately and cleans up to lazy legacy managers'
    When run manager_case
    The status should be success
  End
End
