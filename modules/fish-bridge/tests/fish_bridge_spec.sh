Describe 'fish-bridge module'
  runfish_case() {
    emulate -L zsh
    # The curated child runs under env -i: no HOME, so the stub carries its absolute log path.
    cat > "$TEST_ROOT/bin/fish" <<DATA
#!/bin/sh
{ printf 'ARGS=%s\\n' "\$*"; /usr/bin/env; } > "$TEST_ROOT/fish-env"
DATA
    chmod +x "$TEST_ROOT/bin/fish"
    load_mfn fish-bridge run-fish
    export TERM=xterm-fixture SSH_AUTH_SOCK="$HOME/agent space" SECRET_X=leak
    run-fish > "$TEST_ROOT/out" 2>&1 || { cat "$TEST_ROOT/out"; return 1; }
    local env_text=$(<"$TEST_ROOT/fish-env")
    [[ $env_text == *'ARGS=-l'* && $env_text == *$'\nTERM=xterm-fixture'* && $env_text == *$'\nSSH_AUTH_SOCK='"$HOME/agent space"* ]] || { print -r -- "$env_text"; return 2; }
    [[ $env_text != *SECRET_X* && $env_text == *$'\nSHELL='*fish* ]] || { print -r -- "$env_text"; return 3; }
  }
  It 'starts a login fish with only the curated environment'
    When run runfish_case
    The status should be success
  End
End
