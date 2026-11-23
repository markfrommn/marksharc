Describe 'generated command shims'
  shim_case() {
    emulate -L zsh
    mkdir -p "$HOME/providers" "$TEST_ROOT/stage"
    cat > "$HOME/providers/a.conf" <<'DATA'
# Provider settings

env ANTHROPIC_AUTH_TOKEN 'secret % value'
env LITERAL '$(touch "$HOME/INJECTED")'
env MODELS_URL https://fixture.invalid/models
DATA
    cat > "$TEST_ROOT/bin/claude" <<'DATA'
#!/bin/sh
printf '%s\n' "$ANTHROPIC_AUTH_TOKEN" "$LITERAL" "$1" > "$HOME/result"
DATA
    chmod +x "$TEST_ROOT/bin/claude"
    source "$MARKSHARC_ROOT/core/zsh/lib/modules.zsh"
    source "$MARKSHARC_ROOT/core/zsh/lib/shims.zsh"
    local MARKSHARC_HOME=$MARKSHARC_ROOT
    typeset -a _ms_plan=(cc-providers)
    typeset -A _ms_mod_dir=(cc-providers "$MARKSHARC_ROOT/modules/cc-providers") _ms_cfg_set=(cc-providers.dir "$HOME/providers") _ms_mod_optdef=()
    _ms_shims_render "$TEST_ROOT/stage" || return 1
    [[ $(file_mode "$TEST_ROOT/stage/claudea") == 700 ]] || return 2
    ! grep -q 'secret % value' "$TEST_ROOT/stage/claudea" || return 3
    /bin/bash -c '"$1" "$2"' _ "$TEST_ROOT/stage/claudea" 'a b;$(touch BAD)' || return 4
    [[ $(<"$HOME/result") == $'secret % value\n$(touch "$HOME/INJECTED")\na b;$(touch BAD)' && ! -e $HOME/INJECTED && ! -e $TEST_ROOT/BAD ]] || { cat "$HOME/result" >&2; return 5; }
    sed -i 's/secret % value/changed/' "$HOME/providers/a.conf"
    "$TEST_ROOT/stage/claudea" x || return 6
    [[ $(head -1 "$HOME/result") == changed ]]
  }
  It 'keeps secrets out of executable shims and reads data at invocation from bash'
    When run shim_case
    The status should be success
  End
  invalid_case() {
    emulate -L zsh
    mkdir -p "$HOME/providers" "$TEST_ROOT/stage"
    print -r -- 'env BAD-NAME value' > "$HOME/providers/a.conf"
    source "$MARKSHARC_ROOT/core/zsh/lib/modules.zsh"
    source "$MARKSHARC_ROOT/core/zsh/lib/shims.zsh"
    local MARKSHARC_HOME=$MARKSHARC_ROOT
    typeset -a _ms_plan=(cc-providers)
    typeset -A _ms_mod_dir=(cc-providers "$MARKSHARC_ROOT/modules/cc-providers") _ms_cfg_set=(cc-providers.dir "$HOME/providers") _ms_mod_optdef=()
    _ms_shims_render "$TEST_ROOT/stage" 2> "$TEST_ROOT/error" && return 1
    [[ ! -e $TEST_ROOT/stage/claudea && -s $TEST_ROOT/error ]]
  }
  It 'rejects malformed provider variable names before creating their shims'
    When run invalid_case
    The status should be success
  End
  models_case() {
    emulate -L zsh
    mkdir -p "$HOME/providers" "$TEST_ROOT/stage"
    print -rl -- "env ANTHROPIC_AUTH_TOKEN 'token space'" 'env MODELS_URL https://example.invalid' > "$HOME/providers/a.conf"
    cat > "$TEST_ROOT/bin/curl" <<'DATA'
#!/bin/sh
printf '%s\n' "$@" > "$HOME/curl-args"
printf '%s\n' '{"data":[{"id":"model"}]}'
exit "${CURL_STATUS:-0}"
DATA
    cat > "$TEST_ROOT/bin/jq" <<'DATA'
#!/bin/sh
cat >/dev/null
printf 'model\n'
DATA
    chmod +x "$TEST_ROOT/bin/curl" "$TEST_ROOT/bin/jq"
    source "$MARKSHARC_ROOT/core/zsh/lib/modules.zsh"
    source "$MARKSHARC_ROOT/core/zsh/lib/shims.zsh"
    local MARKSHARC_HOME=$MARKSHARC_ROOT
    typeset -a _ms_plan=(cc-providers)
    typeset -A _ms_mod_dir=(cc-providers "$MARKSHARC_ROOT/modules/cc-providers") _ms_cfg_set=(cc-providers.dir "$HOME/providers") _ms_mod_optdef=()
    _ms_shims_render "$TEST_ROOT/stage" || return 1
    "$TEST_ROOT/stage/modelsa" > "$HOME/models" || return 2
    [[ $(<"$HOME/curl-args") == $'--fail\n--silent\n--show-error\nhttps://example.invalid\n-H\nAuthorization: Bearer token space' && $(<"$HOME/models") == model ]] || return 3
    CURL_STATUS=7 "$TEST_ROOT/stage/modelsa" > /dev/null && return 4
    return 0
  }
  It 'preserves models authorization and curl pipeline failures'
    When run models_case
    The status should be success
  End
  session_case() {
    emulate -L zsh
    mkdir -p "$TEST_ROOT/stage"
    cat > "$TEST_ROOT/bin/herdr" <<'DATA'
#!/bin/sh
if [ "$1 $2" = 'session list' ]; then
  printf 'NAME STATE PID SOCKET\ndemo ready 123 %s\n' "$HOME/socket space;\$(touch BAD)"
else
  printf '%s\n' "$@" > "$HOME/attach"
fi
DATA
    cat > "$TEST_ROOT/bin/collie" <<'DATA'
#!/bin/sh
printf '%s\n' "$HERDR_SOCKET_PATH" "$1" > "$HOME/collie"
DATA
    chmod +x "$TEST_ROOT/bin/herdr" "$TEST_ROOT/bin/collie"
    source "$MARKSHARC_ROOT/core/zsh/lib/shims.zsh"
    typeset -a _ms_plan=(herdr)
    _ms_shims_render "$TEST_ROOT/stage" || return 1
    /bin/bash -c '"$1" "$2"' _ "$TEST_ROOT/stage/collie-demo" 'a b;$(touch BAD)' || return 2
    "$TEST_ROOT/stage/herdr-demo" 'a b' || return 3
    [[ $(<"$HOME/collie") == "$HOME/socket space;\$(touch BAD)"$'\na b;$(touch BAD)' && $(<"$HOME/attach") == $'session\nattach\ndemo\na b' && ! -e $TEST_ROOT/BAD ]]
  }
  It 'preserves session socket and argument data from bash'
    When run session_case
    The status should be success
  End
  missing_case() {
    emulate -L zsh
    mkdir -p "$TEST_ROOT/stage" "$TEST_ROOT/empty"
    source "$MARKSHARC_ROOT/core/zsh/lib/shims.zsh"
    typeset -a _ms_plan=(herdr)
    local PATH="$TEST_ROOT/empty"
    _ms_shims_render "$TEST_ROOT/stage"
  }
  It 'succeeds quietly when herdr is absent'
    When run missing_case
    The status should be success
    The output should equal ''
  End
End
