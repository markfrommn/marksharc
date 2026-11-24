Describe 'mise ownership and environment'
  mise_config() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -rl -- \
      'module path' \
      'module mise' \
      'module node-nvm' \
      'module go-gvm' \
      'module python' \
      "set mise.tools \"$1\"" \
      "path brew \"$TEST_ROOT/homebrew/bin\"" \
      > "$XDG_CONFIG_HOME/marksharc/config.conf"
  }

  mise_layout() {
    mise_config "${1-node go python}"
    mkdir -p "$TEST_ROOT/homebrew/bin" \
      "$HOME/.nvm/alias" "$HOME/.nvm/versions/node/v22.1.0/bin" \
      "$HOME/.gvm/environments" "$HOME/.gvm/gos/go1.23.0/bin" \
      "$HOME/.pyenv/bin" "$HOME/.pyenv/shims"
    print 22 > "$HOME/.nvm/alias/default"
    print 'gvm_go_name=go1.23.0' > "$HOME/.gvm/environments/default"
    print '#!/bin/sh\nexit 0\n' > "$HOME/.gvm/gos/go1.23.0/bin/go"
    print '#!/bin/sh\nexit 0\n' > "$HOME/.pyenv/bin/pyenv"
    chmod +x "$HOME/.gvm/gos/go1.23.0/bin/go" "$HOME/.pyenv/bin/pyenv"
    export MISE_DATA_DIR="$TEST_ROOT/mise data"
    mkdir -p "$MISE_DATA_DIR/shims"
    stub_command mise 'printf "external-mise %s\n" "$*" >> "$OPLOG"; exit 0'
  }

  inherited_manager_path() {
    local prefix=
    [[ ${1-} == shims ]] && prefix="$MISE_DATA_DIR/shims:"
    print -r -- "$prefix$TEST_ROOT/bin:$HOME/.nvm/versions/node/v22.1.0/bin:$HOME/.gvm/gos/go1.23.0/bin:$HOME/.pyenv/shims:/opt/keep-manager:$PATH"
  }

  mise_env_snapshot() {
    ms_run MISE_DATA_DIR="$MISE_DATA_DIR" GOPATH="${GOPATH-}" GVM_OVERLAY_PREFIX="${GVM_OVERLAY_PREFIX-}" gvm_go_name="${gvm_go_name-}" gvm_pkgset_name="${gvm_pkgset_name-}" PATH="$(inherited_manager_path "$@")" -c \
      'print -l $path
       print "AUTO=${MISE_NOT_FOUND_AUTO_INSTALL-unset}"
       print "GOBIN=${MISE_GO_SET_GOBIN-unset}"
       print "VERSION_FILES=${MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS-unset}"
       print "PYENV=${PYENV_ROOT-unset}"
       print "GOPATH=${GOPATH-unset}"
       print "GVM_OVERLAY=${GVM_OVERLAY_PREFIX-unset}"
       for tool in node go python ruby unsupported; do _ms_mise_owns $tool; print "OWNS_$tool=$?"; done'
  }

  legacy_fallback_snapshot() {
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *"$HOME/.nvm/versions/node/v22.1.0/bin"* &&
       $out == *"$HOME/.gvm/gos/go1.23.0/bin"* &&
       $out == *"$HOME/.pyenv/shims"* &&
       $out == *"$HOME/.pyenv/bin"* &&
       $out != *"$MISE_DATA_DIR/shims"* &&
       $out == *'AUTO=unset'* && $out == *'GOBIN=unset'* &&
       $out == *'VERSION_FILES=unset'* && $out == *"PYENV=$HOME/.pyenv"* ]]
  }

  empty_tools_case() {
    emulate -L zsh
    ms_fixture_full
    mise_layout ''
    mise_env_snapshot || { cat "$TEST_ROOT/err"; return 1; }
    legacy_fallback_snapshot || { cat "$TEST_ROOT/out"; return 2; }
    [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 3; }
  }
  It 'leaves every legacy manager and the mise exports untouched with empty tools'
    When run empty_tools_case
    The status should be success
  End

  missing_mise_case() {
    emulate -L zsh
    ms_fixture_full
    mise_layout 'node go python'
    rm "$TEST_ROOT/bin/mise"
    mise_env_snapshot shims || { cat "$TEST_ROOT/err"; return 1; }
    legacy_fallback_snapshot || { cat "$TEST_ROOT/out"; return 2; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'OWNS_node=1'* && $out == *'OWNS_go=1'* && $out == *'OWNS_python=1'* ]]
  }
  It 'restores legacy ownership for every configured tool when mise is unavailable'
    When run missing_mise_case
    The status should be success
  End

  per_tool_case() {
    emulate -L zsh
    ms_fixture_full
    mise_layout 'node python ruby unsupported-tool'
    mise_env_snapshot || { cat "$TEST_ROOT/err"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out != *"$HOME/.nvm/versions/node/v22.1.0/bin"* &&
       $out == *"$HOME/.gvm/gos/go1.23.0/bin"* &&
       $out != *"$HOME/.pyenv/"* &&
       $out == *'/opt/keep-manager'* ]] || { print -r -- "$out"; return 2; }
    [[ $out == *'OWNS_node=0'* && $out == *'OWNS_go=1'* &&
       $out == *'OWNS_python=0'* && $out == *'OWNS_ruby=0'* &&
       $out == *'OWNS_unsupported=1'* ]] || { print -r -- "$out"; return 3; }
    local -a lines=( "${(@f)out}" ) shim_lines
    shim_lines=( ${(M)lines:#$MISE_DATA_DIR/shims} )
    (( $#shim_lines == 1 )) || { print -r -- "$out"; return 4; }
    [[ $out == *'AUTO=false'* && $out == *'GOBIN=false'* &&
       $out == *'VERSION_FILES=node,python,ruby'* && $out == *'PYENV=unset'* ]]
  }
  It 'stands aside and removes stale manager paths only for owned supported tools'
    When run per_tool_case
    The status should be success
  End

  gvm_environment_case() {
    emulate -L zsh
    ms_fixture_full
    mise_layout go
    export GOPATH="$HOME/.gvm/pkgsets/go1.23.0/global"
    export GVM_OVERLAY_PREFIX="$GOPATH/overlay" gvm_go_name=go1.23.0 gvm_pkgset_name=global
    mise_env_snapshot || { cat "$TEST_ROOT/err"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'GOPATH=unset'* && $out == *'GVM_OVERLAY=unset'* ]] || { print -r -- "$out"; return 2; }
  }
  It 'clears inherited gvm install destinations only when Go is owned'
    When run gvm_environment_case
    The status should be success
  End

  option_case() {
    emulate -L zsh
    ms_fixture_full
    mise_layout 'node go'
    print -rl -- 'set mise.version_files off' 'set mise.auto_install on' 'set mise.set_gobin on' \
      >> "$XDG_CONFIG_HOME/marksharc/config.conf"
    export GOPATH="$HOME/.gvm/pkgsets/go1.23.0/global:$TEST_ROOT/custom go"
    export GVM_OVERLAY_PREFIX="$HOME/.gvm/pkgsets/go1.23.0/global/overlay" gvm_go_name=go1.23.0 gvm_pkgset_name=global
    mise_env_snapshot || { cat "$TEST_ROOT/err"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'AUTO=true'* && $out == *'GOBIN=true'* && $out == *'VERSION_FILES='* && $out == *"GOPATH=$TEST_ROOT/custom go"* && $out == *'GVM_OVERLAY=unset'* ]] || { print -r -- "$out"; return 2; }
    export MISE_SHIMS_DIR="$TEST_ROOT/shim override"
    mkdir -p "$MISE_SHIMS_DIR"
    ms_run MISE_SHIMS_DIR="$MISE_SHIMS_DIR" MISE_DATA_DIR="$MISE_DATA_DIR" -c 'print -l $path' || return 3
    [[ $(<"$TEST_ROOT/out") == *"$MISE_SHIMS_DIR"* && $(<"$TEST_ROOT/out") != *"$MISE_DATA_DIR/shims"* ]]
  }
  It 'maps option values safely and prefers an explicit shim directory with spaces'
    When run option_case
    The status should be success
  End

  session_case() {
    emulate -L zsh
    ms_fixture_full
    mise_config node
    print 'set mise.hook off' >> "$XDG_CONFIG_HOME/marksharc/config.conf"
    local shims="$XDG_DATA_HOME/mise/shims"
    mkdir -p "$shims" "$TEST_ROOT/homebrew/bin"
    stub_command mise 'printf "unexpected %s\n" "$*" >> "$OPLOG"; exit 99'
    local mode out
    local -a lines
    for mode in batch agent interactive; do
      case $mode in
        batch) ms_run -c 'print -l $path' ;;
        agent) ms_run CLAUDECODE=1 -c 'print -l $path' ;;
        interactive) ms_pty -dic 'print -l $path; exit' ;;
      esac || { cat "$TEST_ROOT/out" "$TEST_ROOT/err" 2>/dev/null; return 1; }
      out=$(<"$TEST_ROOT/out")
      out=${out//$'\r'/}
      lines=( "${(@f)out}" )
      (( ${lines[(Ie)$shims]} > 0 && ${lines[(Ie)$TEST_ROOT/homebrew/bin]} > 0 &&
         ${lines[(Ie)$shims]} < ${lines[(Ie)$TEST_ROOT/homebrew/bin]} )) || { print "$mode"; print -r -- "$out"; return 2; }
    done
    [[ ! -s $OPLOG ]]
  }
  It 'puts default-location shims ahead of brew without activation in every session class'
    When run session_case
    The status should be success
  End
End

Describe 'mise interactive activation and compatibility'
  activation_config() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -rl -- 'module path' 'module mise' "set mise.tools \"${1-node go}\"" \
      "set mise.hook ${2:-chpwd}" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    mkdir -p "$XDG_DATA_HOME/mise/shims"
  }

  activation_stub() {
    cat > "$TEST_ROOT/bin/mise" <<'DATA'
#!/bin/sh
if [ "$1 $2" = 'activate zsh' ]; then
  printf 'activate zsh\n' >> "$OPLOG"
  printf 'typeset -g _ms_stub_activation_path="%s"\n' "$PATH"
  cat <<'ZSH'
path=( "$XDG_DATA_HOME/mise/installs/node/22/bin" "${(@s.:.)_ms_stub_activation_path}" )
export MISE_SHELL=zsh MISE_NODE_VERSION=20 __MISE_ORIG_PATH="$PATH" __MISE_SESSION=stub __MISE_DIFF=stub
_mise_hook_env_state() { :; }
if [[ -z ${_mise_cmd_not_found-} ]]; then
    typeset -g _mise_cmd_not_found=1
    command_not_found_handler() { return 127; }
fi
typeset -gU precmd_functions chpwd_functions
_mise_hook_precmd() { print -r -- precmd >> "$OPLOG"; }
_mise_hook_chpwd() { print -r -- chpwd >> "$OPLOG"; _mise_hook; }
_mise_hook() { print -r -- refresh >> "$OPLOG"; path=( ${path:#$XDG_DATA_HOME/mise/shims} ); }
precmd_functions+=( _mise_hook_precmd )
chpwd_functions+=( _mise_hook_chpwd )
mise() {
  { printf 'mise'; local arg; for arg in "$@"; do printf '|%s' "$arg"; done; print; } >> "$OPLOG"
  if [[ $1 == deactivate ]]; then
    precmd_functions=( ${precmd_functions:#_mise_hook_precmd} )
    chpwd_functions=( ${chpwd_functions:#_mise_hook_chpwd} )
    unfunction _mise_hook _mise_hook_precmd _mise_hook_chpwd mise 2>/dev/null
  fi
  return 0
}
typeset -g MISE_ACTIVATION_SETTING="$MISE_NOT_FOUND_AUTO_INSTALL"
ZSH
  exit 0
fi
printf 'external-mise' >> "$OPLOG"
for arg in "$@"; do printf '|%s' "$arg" >> "$OPLOG"; done
printf '\n' >> "$OPLOG"
DATA
    chmod +x "$TEST_ROOT/bin/mise"
  }

  chpwd_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config 'node go' chpwd
    activation_stub
    ms_pty -dic 'print "PRE=${precmd_functions[(Ie)_mise_hook_precmd]} CH=${chpwd_functions[(Ie)_mise_hook_chpwd]}"; cd .; print "SHIMS=${path[(Ie)$XDG_DATA_HOME/mise/shims]}"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *'PRE=0 CH='[1-9]* && $(<"$TEST_ROOT/out") == *'SHIMS='[1-9]* ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(grep -c '^chpwd$' "$OPLOG") == 1 && $(grep -c '^precmd$' "$OPLOG") == 0 ]] || { cat "$OPLOG"; return 3; }
  }
  It 'keeps only the directory hook in chpwd mode and refreshes on cd dot'
    When run chpwd_case
    The status should be success
  End

  prompt_off_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config node prompt
    activation_stub
    ms_pty -dic 'print "PRE=${precmd_functions[(Ie)_mise_hook_precmd]} CH=${chpwd_functions[(Ie)_mise_hook_chpwd]}"; print -rl -- "module path" "module mise" "set mise.tools \"node\"" "set mise.hook off" > "$XDG_CONFIG_HOME/marksharc/config.conf"; marksharc reload; print "OFF_PRE=${precmd_functions[(Ie)_mise_hook_precmd]} OFF_CH=${chpwd_functions[(Ie)_mise_hook_chpwd]} TOOL=${path[(Ie)$XDG_DATA_HOME/mise/installs/node/22/bin]} HANDLER=$+functions[command_not_found_handler] SHELL=${MISE_SHELL-unset}"; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'PRE='[1-9]*' CH='[1-9]* ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(<"$TEST_ROOT/out") == *'OFF_PRE=0 OFF_CH=0 TOOL=0 HANDLER=0 SHELL=unset'* ]] || { cat "$TEST_ROOT/out"; return 3; }
    [[ $(grep -c '^activate zsh$' "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 4; }
  }
  It 'retains both hooks in prompt mode and uses shims only in off mode'
    When run prompt_off_case
    The status should be success
  End

  refresh_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config 'node go python' chpwd
    activation_stub
    ms_pty -dic ': > "$OPLOG"; mise shell node@22; mise use go@1.24; mise sh python@3.13; mise unuse node; mise deactivate; print "RC=$? MISE_FUNC=$+functions[mise]"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    print -r -- $'mise|shell|node@22\nrefresh\nmise|use|go@1.24\nrefresh\nmise|sh|python@3.13\nrefresh\nmise|unuse|node\nrefresh\nmise|deactivate' > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG" || { cat "$OPLOG"; return 2; }
    [[ $(<"$TEST_ROOT/out") == *'RC=0 MISE_FUNC=0'* ]]
  }
  It 'refreshes immediately after state changes but never calls a removed hook after deactivate'
    When run refresh_case
    The status should be success
  End

  activation_cache_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config node chpwd
    activation_stub
    ms_pty -dic 'print "INITIAL=$MISE_ACTIVATION_SETTING"; print -rl -- "module path" "module mise" "set mise.tools \"node\"" "set mise.auto_install on" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; marksharc reload; print "CHANGED=$MISE_ACTIVATION_SETTING HANDLER=$+functions[command_not_found_handler]"; marksharc reload; exit' || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *'INITIAL=false'* && $(<"$TEST_ROOT/out") == *'CHANGED=true HANDLER=1'* ]] || { cat "$TEST_ROOT/out" "$OPLOG"; return 2; }
    [[ $(grep -c '^activate zsh$' "$OPLOG") == 2 ]] || { cat "$OPLOG"; return 3; }
  }
  It 'caches repeated activation while keying the cache on activation-shaping auto-install'
    When run activation_cache_case
    The status should be success
  End

  activation_path_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config node chpwd
    activation_stub
    mkdir -p "$HOME/.gvm/gos/go1.23.0/bin"
    export GVM_ROOT="$HOME/.gvm"
    ms_pty PATH="$GVM_ROOT/gos/go1.23.0/bin:$PATH" -dic 'print -rl -- "module path" "module mise" "set mise.tools \"node go\"" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; marksharc reload; print "GVM=${path[(Ie)$GVM_ROOT/gos/go1.23.0/bin]}"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *'GVM=0'* ]] || { cat "$TEST_ROOT/out"; return 2; }
    [[ $(grep -c '^activate zsh$' "$OPLOG") == 2 ]] || { cat "$OPLOG"; return 3; }
  }
  It 'does not restore a cached pre-activation PATH across an ownership transition'
    When run activation_path_case
    The status should be success
  End

  compat_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config 'node go' chpwd
    activation_stub
    ms_pty -dic ': > "$OPLOG"; nvm use "22 beta" --silent; nvm install 20; nvm ls; nvm current; nvm alias default 22; gvm use go1.23.1; gvm install go1.24; gvm ls; gvm list; gvm current; gvm alias default go1.23.1; nvm exec 22 node > "$TEST_ROOT/nvm-hint" 2>&1; print "NVM_HINT=$?"; gvm pkgset list > "$TEST_ROOT/gvm-hint" 2>&1; print "GVM_HINT=$?"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    print -r -- $'mise|shell|node@22 beta|--silent\nrefresh\nmise|install|node@20\nmise|ls|node\nmise|current|node\nmise|use|--global|node@22\nrefresh\nmise|shell|go@1.23.1\nrefresh\nmise|install|go@1.24\nmise|ls|go\nmise|ls|go\nmise|current|go\nmise|use|--global|go@1.23.1\nrefresh' > "$TEST_ROOT/expected"
    cmp "$TEST_ROOT/expected" "$OPLOG" || { cat "$OPLOG"; return 2; }
    [[ $(<"$TEST_ROOT/out") == *'NVM_HINT=2'* && $(<"$TEST_ROOT/out") == *'GVM_HINT=2'* ]] || { cat "$TEST_ROOT/out"; return 3; }
    local hint
    for hint in 'mise shell node@' 'mise install node@' 'mise ls node' 'mise current node' 'mise use --global node@'; do
      [[ $(<"$TEST_ROOT/nvm-hint") == *"$hint"* ]] || { cat "$TEST_ROOT/nvm-hint"; return 4; }
    done
    for hint in 'mise shell go@' 'mise install go@' 'mise ls go' 'mise current go' 'mise use --global go@'; do
      [[ $(<"$TEST_ROOT/gvm-hint") == *"$hint"* ]] || { cat "$TEST_ROOT/gvm-hint"; return 5; }
    done
  }
  It 'translates common nvm and gvm verbs literally and prints hints for unsupported verbs'
    When run compat_case
    The status should be success
  End

  compat_ownership_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config node chpwd
    activation_stub
    ms_pty -dic 'print "NVM=$+functions[nvm] GVM=$+functions[gvm]"; exit' || return 1
    [[ $(<"$TEST_ROOT/out") == *'NVM=1 GVM=0'* ]] || { cat "$TEST_ROOT/out"; return 2; }
    activation_config node chpwd
    print 'set mise.compat off' >> "$XDG_CONFIG_HOME/marksharc/config.conf"
    ms_pty -dic 'print "NVM=$+functions[nvm] GVM=$+functions[gvm]"; exit' || return 3
    [[ $(<"$TEST_ROOT/out") == *'NVM=0 GVM=0'* ]]
  }
  It 'defines compatibility functions only for owned tools and only when enabled'
    When run compat_ownership_case
    The status should be success
  End
End

Describe 'mise reload and legacy restoration'
  activation_config() {
    mkdir -p "$XDG_CONFIG_HOME/marksharc"
    print -rl -- 'module path' 'module mise' "set mise.tools \"${1-node go}\"" \
      "set mise.hook ${2:-chpwd}" > "$XDG_CONFIG_HOME/marksharc/config.conf"
    mkdir -p "$XDG_DATA_HOME/mise/shims"
  }

  activation_stub() {
    cat > "$TEST_ROOT/bin/mise" <<'DATA'
#!/bin/sh
if [ "$1 $2" = 'activate zsh' ]; then
  printf 'activate zsh\n' >> "$OPLOG"
  printf 'typeset -g _ms_stub_activation_path="%s"\n' "$PATH"
  cat <<'ZSH'
path=( "$XDG_DATA_HOME/mise/installs/node/22/bin" "${(@s.:.)_ms_stub_activation_path}" )
export MISE_SHELL=zsh MISE_NODE_VERSION=20 __MISE_ORIG_PATH="$PATH" __MISE_SESSION=stub __MISE_DIFF=stub
_mise_hook_env_state() { :; }
if [[ -z ${_mise_cmd_not_found-} ]]; then
    typeset -g _mise_cmd_not_found=1
    command_not_found_handler() { return 127; }
fi
typeset -gU precmd_functions chpwd_functions
_mise_hook_precmd() { print -r -- precmd >> "$OPLOG"; }
_mise_hook_chpwd() { print -r -- chpwd >> "$OPLOG"; _mise_hook; }
_mise_hook() { print -r -- refresh >> "$OPLOG"; path=( ${path:#$XDG_DATA_HOME/mise/shims} ); }
precmd_functions+=( _mise_hook_precmd )
chpwd_functions+=( _mise_hook_chpwd )
mise() {
  { printf 'mise'; local arg; for arg in "$@"; do printf '|%s' "$arg"; done; print; } >> "$OPLOG"
  if [[ $1 == deactivate ]]; then
    precmd_functions=( ${precmd_functions:#_mise_hook_precmd} )
    chpwd_functions=( ${chpwd_functions:#_mise_hook_chpwd} )
    unfunction _mise_hook _mise_hook_precmd _mise_hook_chpwd mise 2>/dev/null
  fi
  return 0
}
typeset -g MISE_ACTIVATION_SETTING="$MISE_NOT_FOUND_AUTO_INSTALL"
ZSH
  exit 0
fi
printf 'external-mise' >> "$OPLOG"
for arg in "$@"; do printf '|%s' "$arg" >> "$OPLOG"; done
printf '\n' >> "$OPLOG"
DATA
    chmod +x "$TEST_ROOT/bin/mise"
  }

  legacy_reload_fixture() {
    ms_fixture_full
    activation_config '' chpwd
    print -rl -- 'module node-nvm' 'module go-gvm' >> "$XDG_CONFIG_HOME/marksharc/config.conf"
    mkdir -p "$HOME/.nvm" "$HOME/.gvm/scripts" "$HOME/.gvm/gos/go1.23.0/bin"
    print '#!/bin/sh\nexit 0\n' > "$HOME/.gvm/gos/go1.23.0/bin/go"
    chmod +x "$HOME/.gvm/gos/go1.23.0/bin/go"
    cat > "$HOME/.nvm/nvm.sh" <<'DATA'
print -r -- 'nvm-source' >> "$OPLOG"
nvm() { { printf 'real-nvm'; for arg in "$@"; do printf '|%s' "$arg"; done; print; } >> "$OPLOG"; }
nvm_find_nvmrc() { return 1; }
DATA
    cat > "$HOME/.gvm/scripts/gvm" <<'DATA'
print -r -- 'gvm-source' >> "$OPLOG"
export GVM_VERSION=stub
gvm() { { printf 'real-gvm'; for arg in "$@"; do printf '|%s' "$arg"; done; print; } >> "$OPLOG"; }
DATA
    activation_stub
  }

  write_tools() {
    print -rl -- 'module path' 'module mise' 'module node-nvm' 'module go-gvm' \
      "set mise.tools \"$1\"" 'set mise.hook chpwd' > "$XDG_CONFIG_HOME/marksharc/config.conf"
  }

  reload_restoration_case() {
    emulate -L zsh
    legacy_reload_fixture
    ms_pty -dic 'print "LEGACY_NVM=${chpwd_functions[(Ie)load-nvmrc]} LEGACY_GVM=${chpwd_functions[(Ie)_gvm_auto_use]}"; write_tools() { print -rl -- "module path" "module mise" "module node-nvm" "module go-gvm" "set mise.tools \"$1\"" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; }; write_tools "node go"; marksharc reload; print "OWNED_NVM=${chpwd_functions[(Ie)load-nvmrc]} OWNED_GVM=${chpwd_functions[(Ie)_gvm_auto_use]}"; nvm ls; gvm ls; write_tools ""; marksharc reload; print "FALLBACK_NVM=${chpwd_functions[(Ie)load-nvmrc]} FALLBACK_GVM=${chpwd_functions[(Ie)_gvm_auto_use]} MISE_PRE=${precmd_functions[(Ie)_mise_hook_precmd]} MISE_CH=${chpwd_functions[(Ie)_mise_hook_chpwd]}"; nvm ls; gvm list; exit' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'LEGACY_NVM='[1-9]*' LEGACY_GVM='[1-9]* &&
       $out == *'OWNED_NVM=0 OWNED_GVM=0'* &&
       $out == *'FALLBACK_NVM='[1-9]*' FALLBACK_GVM='[1-9]*' MISE_PRE=0 MISE_CH=0'* ]] || { print -r -- "$out"; return 2; }
    local log=$(<"$OPLOG")
    [[ $log == *'mise|ls|node'* && $log == *'mise|ls|go'* &&
       $log == *'nvm-source'* && $log == *'gvm-source'* &&
       $log == *'real-nvm|ls'* && $log == *'real-gvm|list'* ]] || { print -r -- "$log"; return 3; }
  }
  It 'removes legacy hooks and first-use stubs while owned and restores them on fallback'
    When run reload_restoration_case
    The status should be success
  End

  loaded_legacy_case() {
    emulate -L zsh
    legacy_reload_fixture
    ms_pty -dic 'nvm ls; gvm list; write_tools() { print -rl -- "module path" "module mise" "module node-nvm" "module go-gvm" "set mise.tools \"node go\"" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; }; write_tools; marksharc reload; : > "$OPLOG"; nvm ls; gvm list; exit' || { cat "$TEST_ROOT/out"; return 1; }
    local log=$(<"$OPLOG")
    [[ $log == *'real-nvm|ls'* && $log == *'real-gvm|list'* &&
       $log != *'mise|ls|node'* && $log != *'mise|ls|go'* ]] || { print -r -- "$log"; return 2; }
  }
  It 'never replaces an already loaded real nvm or gvm during an ownership reload'
    When run loaded_legacy_case
    The status should be success
  End

  post_compat_legacy_case() {
    emulate -L zsh
    legacy_reload_fixture
    ms_pty -dic 'write_tools() { print -rl -- "module path" "module mise" "module node-nvm" "module go-gvm" "set mise.tools \"node go\"" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; }; write_tools; marksharc reload; unfunction nvm gvm; source "$NVM_DIR/nvm.sh" --no-use; source "$GVM_ROOT/scripts/gvm" >/dev/null 2>&1; marksharc reload; : > "$OPLOG"; nvm ls; gvm list; exit' || { cat "$TEST_ROOT/out"; return 1; }
    local log=$(<"$OPLOG")
    [[ $log == *'real-nvm|ls'* && $log == *'real-gvm|list'* &&
       $log != *'mise|ls|node'* && $log != *'mise|ls|go'* ]] || { print -r -- "$log"; return 2; }
  }
  It 'preserves real managers loaded after compatibility when reloading ownership'
    When run post_compat_legacy_case
    The status should be success
  End

  missing_inherited_case() {
    emulate -L zsh
    legacy_reload_fixture
    mkdir -p "$HOME/.nvm/alias" "$HOME/.nvm/versions/node/v22.1.0/bin"
    print 22 > "$HOME/.nvm/alias/default"
    ms_pty -dic 'write_tools() { print -rl -- "module path" "module mise" "module node-nvm" "module go-gvm" "set mise.tools \"node go\"" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; }; write_tools; marksharc reload; rm "$TEST_ROOT/bin/mise"; print -r -- "print -l \$path" > "$TEST_ROOT/child.zsh"; zsh "$TEST_ROOT/child.zsh"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *"$HOME/.nvm/versions/node/v24.19.0/bin"* || $out == *"$HOME/.nvm/versions/node/v22.1.0/bin"* ]] || { print -r -- "$out"; return 2; }
    [[ $out == *"$HOME/.gvm/gos/go1.23.0/bin"* ]] || { print -r -- "$out"; return 3; }
  }
  It 'rebuilds legacy manager paths when an activated parent loses mise'
    When run missing_inherited_case
    The status should be success
  End

  empty_inherited_case() {
    emulate -L zsh
    legacy_reload_fixture
    mkdir -p "$HOME/.nvm/alias" "$HOME/.nvm/versions/node/v22.1.0/bin"
    print 22 > "$HOME/.nvm/alias/default"
    ms_pty -dic 'write_tools() { print -rl -- "module path" "module mise" "module node-nvm" "module go-gvm" "set mise.tools \"node go\"" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; }; write_tools; marksharc reload; print -rl -- "module path" "module mise" "module node-nvm" "module go-gvm" "set mise.tools \"\"" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; print -r -- "print -l \$path; print \"AUTO=\${MISE_NOT_FOUND_AUTO_INSTALL-unset} SHIMS=\${path[(Ie)\$XDG_DATA_HOME/mise/shims]}\"" > "$TEST_ROOT/child.zsh"; zsh "$TEST_ROOT/child.zsh"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *"$HOME/.nvm/versions/node/v22.1.0/bin"* && $out == *"$HOME/.gvm/gos/go1.23.0/bin"* &&
       $out == *'AUTO=unset SHIMS=0'* ]] || { print -r -- "$out"; return 2; }
  }
  It 'drops module shims and settings when a child has empty tools'
    When run empty_inherited_case
    The status should be success
  End

  disabled_inherited_case() {
    emulate -L zsh
    legacy_reload_fixture
    mkdir -p "$HOME/.nvm/alias" "$HOME/.nvm/versions/node/v22.1.0/bin"
    print 22 > "$HOME/.nvm/alias/default"
    ms_pty -dic 'write_tools() { print -rl -- "module path" "module mise" "module node-nvm" "module go-gvm" "set mise.tools \"node go\"" "set mise.hook chpwd" > "$XDG_CONFIG_HOME/marksharc/config.conf"; }; write_tools; marksharc reload; print -rl -- "module path" "module node-nvm" "module go-gvm" > "$XDG_CONFIG_HOME/marksharc/config.conf"; print -r -- "print -l \$path; print \"AUTO=\${MISE_NOT_FOUND_AUTO_INSTALL-unset} MISE_FUNC=\$+functions[mise]\"" > "$TEST_ROOT/child.zsh"; zsh "$TEST_ROOT/child.zsh"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *"$HOME/.nvm/versions/node/v22.1.0/bin"* && $out == *"$HOME/.gvm/gos/go1.23.0/bin"* &&
       $out == *'AUTO=unset MISE_FUNC=0'* && $out != *"$XDG_DATA_HOME/mise/installs/node/22/bin"* ]] || { print -r -- "$out"; return 2; }
  }
  It 'restores legacy paths and clears activation when a child disables mise'
    When run disabled_inherited_case
    The status should be success
  End

  foreign_activation_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config '' chpwd
    ms_pty -dic 'export MISE_SHELL=zsh MISE_NODE_VERSION=20 __MISE_ORIG_PATH=foreign __MISE_SESSION=foreign; _mise_hook_precmd() { :; }; _mise_hook_chpwd() { :; }; mise() { :; }; precmd_functions+=( _mise_hook_precmd ); chpwd_functions+=( _mise_hook_chpwd ); source "$MARKSHARC_HOME/core/zsh/zshrc.zsh"; marksharc reload; print "PRE=${precmd_functions[(Ie)_mise_hook_precmd]} CH=${chpwd_functions[(Ie)_mise_hook_chpwd]} SHELL=$MISE_SHELL VERSION=$MISE_NODE_VERSION ORIG=$__MISE_ORIG_PATH FUNC=$+functions[mise]"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *'PRE='[1-9]*' CH='[1-9]*' SHELL=zsh VERSION=20 ORIG=foreign FUNC=1'* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'leaves a foreign activation untouched with empty tools on startup and reload'
    When run foreign_activation_case
    The status should be success
  End

  active_inherited_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config node chpwd
    activation_stub
    mkdir -p "$HOME/project"
    print 22 > "$HOME/project/.nvmrc"
    ms_pty -dic 'cd "$HOME/project"; print -r -- "print \"SHELL=\${MISE_SHELL-unset} VERSION=\${MISE_NODE_VERSION-unset} SHIMS=\${path[(Ie)\$XDG_DATA_HOME/mise/shims]}\"" > "$TEST_ROOT/child.zsh"; zsh "$TEST_ROOT/child.zsh"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    [[ $(<"$TEST_ROOT/out") == *'SHELL=unset VERSION=unset SHIMS='[1-9]* ]] || { cat "$TEST_ROOT/out"; return 2; }
  }
  It 'clears exported activation versions before an owned child reads its project'
    When run active_inherited_case
    The status should be success
  End

  python_uv_case() {
    emulate -L zsh
    ms_fixture_full
    activation_config python off
    activation_stub
    print 'module python' >> "$XDG_CONFIG_HOME/marksharc/config.conf"
    mkdir -p "$HOME/.pyenv/bin" "$HOME/.pyenv/shims"
    stub_command uv 'exit 0'
    stub_command pyenv 'printf "pyenv|%s\n" "$*" >> "$OPLOG"; case "$1" in init) exit 0;; commands) printf "init\n";; esac'
    cp "$TEST_ROOT/bin/pyenv" "$HOME/.pyenv/bin/pyenv"
    ms_pty -dic 'rm "$TEST_ROOT/bin/uv"; marksharc reload; print "OWNED_PYENV=${PYENV_ROOT-unset}"; print -rl -- "module path" "module mise" "module python" "set mise.tools \"\"" "set mise.hook off" > "$XDG_CONFIG_HOME/marksharc/config.conf"; marksharc reload; print "FALLBACK_PYENV=${PYENV_ROOT-unset}"; exit' || { cat "$TEST_ROOT/out"; return 1; }
    local out=$(<"$TEST_ROOT/out")
    [[ $out == *'OWNED_PYENV=unset'* && $out == *"FALLBACK_PYENV=$HOME/.pyenv"* ]] || { print -r -- "$out"; return 2; }
    [[ $(<"$OPLOG") == *'pyenv|init'* ]] || { cat "$OPLOG"; return 3; }
  }
  It 'keeps uv preferred and suppresses pyenv only until owned Python falls back'
    When run python_uv_case
    The status should be success
  End
End
