Describe 'generated provider wrappers preserve data and ownership'
  provider_case() {
    emulate -L zsh
    mkdir -p "$HOME/ai/providers"
    local USER_KEY_DIR=$HOME
    cat > "$HOME/ai/providers/a-test.provider" <<'DATA'
typeset -gA a_provider=(ANTHROPIC_AUTH_TOKEN 'fake key' MODELS_URL 'https://fixture.invalid/a' LITERAL '$(touch "$HOME/INJECTED")')
DATA
    print -r -- 'typeset -gA b_provider=(ANTHROPIC_AUTH_TOKEN fake)' > "$HOME/ai/providers/b-test.provider"
    cat > "$TEST_ROOT/bin/claude" <<'DATA'
#!/bin/sh
printf '%s\n' "$#" "$1" "$LITERAL" > "$HOME/argv"
DATA
    chmod +x "$TEST_ROOT/bin/claude"
    _ms_opt_cc_providers_dir="$HOME/ai/providers"
    load_mfn cc-providers
    purge_functions() { for f in ${(k)functions}; do [[ $f =~ $1 ]] && unfunction "$f"; done; return 0; }
    claude-unrelated() { :; }
    setup-cc-providers > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
    claudea 'one argument' || return 2
    [[ ! -e "$HOME/INJECTED" && $(<"$HOME/argv") == $'1\none argument\n$(touch "$HOME/INJECTED")' ]] || return 3
    (( $+functions[claude-unrelated] && ! $+functions[modelsb] )) || return 4
    rm "$HOME/ai/providers/a-test.provider"
    setup-cc-providers > "$TEST_ROOT/out" 2>&1 || return 5
    (( ! $+functions[claudea] && ! $+functions[modelsa] && $+functions[claude-unrelated] )) || return 6
  }
  dir_case() {
    emulate -L zsh
    local USER_KEY_DIR=$HOME
    load_mfn cc-providers
    mkdir -p "$XDG_CONFIG_HOME/marksharc/providers" "$HOME/elsewhere" "$HOME/elsewhere-config/providers"
    print -r -- 'typeset -gA one_provider=(ANTHROPIC_AUTH_TOKEN fake)' > "$XDG_CONFIG_HOME/marksharc/providers/one-test.provider"
    print -r -- 'typeset -gA two_provider=(ANTHROPIC_AUTH_TOKEN fake)' > "$HOME/elsewhere/two-test.provider"
    print -r -- 'typeset -gA three_provider=(ANTHROPIC_AUTH_TOKEN fake)' > "$HOME/elsewhere-config/providers/three-test.provider"
    unset _ms_opt_cc_providers_dir MARKSHARC_CONFIG
    # Default: the providers directory of the overlay config directory.
    setup-cc-providers || return 1
    (( $+functions[claudeone] && ! $+functions[claudetwo] )) || return 2
    # The option wins over the default.
    _ms_opt_cc_providers_dir="$HOME/elsewhere"
    setup-cc-providers || return 3
    (( $+functions[claudetwo] && ! $+functions[claudeone] )) || return 4
    # MARKSHARC_CONFIG moves the default.
    unset _ms_opt_cc_providers_dir
    MARKSHARC_CONFIG="$HOME/elsewhere-config"
    setup-cc-providers || return 5
    (( $+functions[claudethree] && ! $+functions[claudetwo] && ! $+functions[claudeone] )) || return 6
  }
  It 'reads provider files from the option, else the overlay providers directory'
    When run dir_case
    The status should be success
  End
  It 'keeps provider values literal, command scoped and refresh owned'
    When run provider_case
    The status should be success
  End
End
