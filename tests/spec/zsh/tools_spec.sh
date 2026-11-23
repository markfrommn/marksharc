Describe 'tool-root modules (env phase)'
  # Each case runs the path module and the module under test under zsh -f against a
  # fixture directory tree, then lets the path finalizer build PATH.
  tool_layout() {
    local root="$TEST_ROOT/root"
    mkdir -p "$root"/{bin,usr/bin,sbin,usr/sbin,usr/local/bin,opt/homebrew/bin,opt/homebrew/sbin,dev}
  }
  # tool_run <os> <child-body> : prints the PATH one entry per line after the body ran.
  tool_run() {
    local os=$1 body=$2
    cat > "$TEST_ROOT/child.zsh" <<DATA
MARKSHARC_OS=${os:l}; MARKSHARC_ARCH=x86_64; uid=1000; _ms_fs_root=$TEST_ROOT/root
path=( /usr/bin /bin )
source "\$MARKSHARC_HOME/modules/path/env.zsh"
${body}
_ms_path_finalize
print -l -- "\$path[@]"
DATA
    ms_unit "source $TEST_ROOT/child.zsh" || { cat "$TEST_ROOT/err"; return 1; }
  }
  show() { print -r -- "GOT:"; print -l -- "$@"; }
  brew_env_case() {
    emulate -L zsh
    tool_layout
    mkdir -p "$TEST_ROOT/root/home/linuxbrew/.linuxbrew/bin"
    tool_run Darwin '_ms_test_render_module brew' || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    # /opt/homebrew is in the brew tier (first on macOS); Linuxbrew stays in local.
    [[ $got[1] == /opt/homebrew/bin && $got[2] == /opt/homebrew/sbin ]] || { show $got; return 2; }
    [[ $got[3] == /usr/local/bin && $got[4] == /home/linuxbrew/.linuxbrew/bin ]] || { show $got; return 3; }
    tool_run Linux 'mkdir -p "$XDG_CONFIG_HOME/marksharc"; print "set brew.linuxbrew_tier brew" > "$XDG_CONFIG_HOME/marksharc/config.conf"; _ms_test_render_module brew' || return 4
    got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ $got[1] == /opt/homebrew/bin && $got[3] == /home/linuxbrew/.linuxbrew/bin ]] || { show $got; return 5; }
  }
  It 'puts Homebrew directories in the brew tier and Linuxbrew in the configured tier'
    When run brew_env_case
    The status should be success
  End
  language_roots_case() {
    emulate -L zsh
    tool_layout
    mkdir -p "$HOME/go/bin" "$HOME/gp1/bin" "$HOME/gp2/bin" "$HOME/.cargo/bin" "$HOME/cg/bin"
    tool_run Darwin 'source "$MARKSHARC_HOME/modules/go/env.zsh"; source "$MARKSHARC_HOME/modules/rust/env.zsh"' || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    (( ${got[(Ie)$HOME/go/bin]} > 0 && ${got[(Ie)$HOME/.cargo/bin]} > ${got[(Ie)$HOME/go/bin]} )) || { show $got; return 2; }
    tool_run Darwin 'GOPATH=$HOME/gp1:$HOME/gp2 CARGO_HOME=$HOME/cg; source "$MARKSHARC_HOME/modules/go/env.zsh"; source "$MARKSHARC_HOME/modules/rust/env.zsh"' || return 3
    got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    (( ${got[(Ie)$HOME/gp1/bin]} > 0 && ${got[(Ie)$HOME/gp2/bin]} > 0 && ${got[(Ie)$HOME/cg/bin]} > 0 && ${got[(Ie)$HOME/go/bin]} == 0 )) || { show $got; return 4; }
  }
  It 'adds the Go and Cargo bin directories to the user tier'
    When run language_roots_case
    The status should be success
  End
  bun_pnpm_case() {
    emulate -L zsh
    tool_layout
    mkdir -p "$HOME/.bun/bin" "$HOME/Library/pnpm" "$HOME/.local/share/pnpm"
    print '#compdef bun' > "$HOME/.bun/_bun"
    tool_run Darwin '_ms_test_render_module bun; source "$MARKSHARC_HOME/modules/pnpm/env.zsh"; print -r -- "BUN=$BUN_INSTALL PNPM=$PNPM_HOME" >&2' || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    [[ $(<"$TEST_ROOT/err") == "BUN=$HOME/.bun PNPM=$HOME/Library/pnpm" ]] || { cat "$TEST_ROOT/err"; return 2; }
    (( ${got[(Ie)$HOME/.bun/bin]} > 0 && ${got[(Ie)$HOME/Library/pnpm]} > 0 )) || { show $got; return 3; }
    # pnpm path option off: PNPM_HOME is still exported, PATH is untouched.
    tool_run Darwin '_ms_opt_pnpm_path=off; source "$MARKSHARC_HOME/modules/pnpm/env.zsh"' || return 4
    [[ $(<"$TEST_ROOT/out") != *pnpm* ]] || return 5
    # bun's completion file reaches compinit through fpath.
    ms_unit "BUN_INSTALL=$HOME/.bun; source \"\$MARKSHARC_HOME/modules/bun/init.zsh\"; print -r -- \"\$fpath[1]\"" || return 6
    [[ $(<"$TEST_ROOT/out") == "$HOME/.bun" ]] || return 7
    # No bun, no pnpm: nothing exported, nothing added.
    rm -rf "$HOME/.bun" "$HOME/Library/pnpm" "$HOME/.local/share/pnpm"
    tool_run Darwin '_ms_test_render_module bun; source "$MARKSHARC_HOME/modules/pnpm/env.zsh"' || return 8
    [[ $(<"$TEST_ROOT/out") != *bun* && $(<"$TEST_ROOT/out") != *pnpm* ]]
  }
  It 'exports BUN_INSTALL and PNPM_HOME and adds their directories only when installed'
    When run bun_pnpm_case
    The status should be success
  End
  lmstudio_case() {
    emulate -L zsh
    tool_layout
    mkdir -p "$HOME/.lmstudio/bin"
    tool_run Darwin '_ms_test_render_module lmstudio' || return 1
    local -a got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    # local tier: before the system directories on macOS, as today.
    (( ${got[(Ie)$HOME/.lmstudio/bin]} > 0 && ${got[(Ie)$HOME/.lmstudio/bin]} < ${got[(Ie)/bin]} )) || { show $got; return 2; }
    # On Linux it follows the user tier (app), as the old apath did.
    tool_run Linux '_ms_test_render_module lmstudio' || return 3
    got=( "${(@f)$(<"$TEST_ROOT/out")}" )
    (( ${got[(Ie)$HOME/.lmstudio/bin]} > ${got[(Ie)/bin]} )) || { show $got; return 4; }
  }
  It 'puts the LM Studio CLI directory in the local tier on macOS and the app tier on Linux'
    When run lmstudio_case
    The status should be success
  End
  cuda_case() {
    emulate -L zsh
    tool_layout
    mkdir -p "$TEST_ROOT/root/usr/local/cuda/bin"
    # lspci must never run: the old rule forked it on every Linux start.
    printf '#!/bin/sh\necho FORBIDDEN lspci >> "$OPLOG"\nexit 99\n' > "$TEST_ROOT/bin/lspci"; chmod +x "$TEST_ROOT/bin/lspci"
    tool_run Linux '_ms_test_render_module cuda; print -r -- "MPS=${CUDA_MPS_PIPE_DIRECTORY-unset}" >&2' || return 1
    [[ $(<"$TEST_ROOT/err") == MPS=unset && $(<"$TEST_ROOT/out") != */cuda/bin* ]] || { cat "$TEST_ROOT/err"; return 2; }
    : > "$TEST_ROOT/root/dev/nvidiactl"
    tool_run Linux '_ms_test_render_module cuda; print -r -- "MPS=$CUDA_MPS_PIPE_DIRECTORY LOG=$CUDA_MPS_LOG_DIRECTORY" >&2' || return 3
    [[ $(<"$TEST_ROOT/err") == "MPS=/tmp/nvidia-mps LOG=$HOME/tmp/nvidia-mps" && $(<"$TEST_ROOT/out") == */usr/local/cuda/bin* ]] || { cat "$TEST_ROOT/err"; return 4; }
    [[ ! -s $OPLOG ]] || return 5
    # The module is Linux only: the loader skips it on macOS.
    grep -q '^requires os linux$' "$MARKSHARC_ROOT/modules/cuda/module.conf"
  }
  It 'exports the MPS variables and adds CUDA only on Linux when the driver is loaded, without forks'
    When run cuda_case
    The status should be success
  End
End

Describe 'interactive tool modules (init phase)'
  stub_tool() { printf '#!/bin/sh\nprintf "print %%s >> \\"\\$OPLOG\\"\\n" "$(basename "$0")"\n' > "$TEST_ROOT/bin/$1"; chmod +x "$TEST_ROOT/bin/$1"; }
  ls_case() {
    emulate -L zsh
    stub_command eza 'exit 0'
    ms_unit 'MARKSHARC_SESSION=interactive; alias ls="ls -x"; source "$MARKSHARC_HOME/modules/ls/init.zsh"; _ms_test_render_module ls
      print -r -- "${aliases[ll]}|${aliases[la]}|${aliases[dir]}|${aliases[lf]}|${aliases[lsf]}|${+aliases[ls]}"' || return 1
    [[ $(<"$TEST_ROOT/out") == 'eza -lA|eza -a|eza -l|eza -FA|eza -F|0' ]] || { cat "$TEST_ROOT/out"; return 2; }
    rm "$TEST_ROOT/bin/eza"
    ms_unit 'MARKSHARC_SESSION=interactive; source "$MARKSHARC_HOME/modules/ls/init.zsh"; _ms_test_render_module ls
      print -r -- "${aliases[ls]}|${aliases[ll]}|${aliases[la]}|${aliases[dir]}|${aliases[lf]}|${aliases[lsf]}"' || return 3
    [[ $(<"$TEST_ROOT/out") == 'ls --color=auto|ls -lA|ls -a|ls -l|ls -FA|ls -F' ]] || { cat "$TEST_ROOT/out"; return 4; }
    ms_unit 'MARKSHARC_OS=darwin; source "$MARKSHARC_HOME/modules/ls/init.zsh"; print -r -- "${aliases[ls]}"' || return 5
    [[ $(<"$TEST_ROOT/out") == 'ls -G' ]] || return 6
    # No other module defines the family again (the old file defined ll twice).
    ! grep -rE "alias +(ll|la|dir|lf|lsf)=" "$MARKSHARC_ROOT/modules" --include='*.zsh' --exclude-dir=ls
  }
  It 'defines one consistent ls family with and without eza'
    When run ls_case
    The status should be success
  End
  pager_options_case() {
    emulate -L zsh
    have_command() { [[ $1 == less ]]; }
    unset PAGER LESS MANPATH
    source "$MARKSHARC_ROOT/modules/pager/init.zsh" || return 1
    [[ $PAGER == 'less -R' && $LESS == -FRX && $MANPATH == /usr/share/man* ]] || return 2
    (( ${+functions[diff]} + ${+functions[diffcp]} == 2 )) || return 3
    [[ ${(t)MANPATH} == *export* && ${(t)PAGER} == *export* ]]
  }
  It 'sets PAGER, LESS and MANPATH and defines the coloured diff wrappers'
    When run pager_options_case
    The status should be success
  End
  editor_case() {
    emulate -L zsh
    # Ported from mark-desktop-files' pruning spec: an explicit option wins,
    # then emacs, then vi; no xemacs alias or fallback survives the move.
    have_command() { [[ $1 == emacs ]]; }
    unset EDITOR _ms_opt_editor_command
    source "$MARKSHARC_ROOT/modules/editor/init.zsh" || return 1
    [[ $EDITOR == 'emacs -nw' ]] || return 2
    have_command() { return 1; }
    unset EDITOR
    source "$MARKSHARC_ROOT/modules/editor/init.zsh" || return 3
    [[ $EDITOR == vi ]] || return 4
    _ms_opt_editor_command='nano -w'
    source "$MARKSHARC_ROOT/modules/editor/init.zsh" || return 5
    [[ $EDITOR == 'nano -w' && -z ${aliases[xemacs]-} && ${aliases[emacs]-} != *xemacs* ]]
  }
  It 'selects Emacs, vi, or the editor option without retaining xemacs aliases or fallbacks'
    When run editor_case
    The status should be success
  End
  freebsd_case() {
    emulate -L zsh
    # Ported from mark-desktop-files' pruning spec: the kept modules load on
    # FreeBSD with no FreeBSD-only CLICOLOR export or startx alias.
    local MARKSHARC_OS=freebsd
    have_command() { return 1; }
    unset CLICOLOR
    local module
    for module in zsh-options editor pager ls nav; do
      source "$MARKSHARC_ROOT/modules/$module/init.zsh" > "$TEST_ROOT/output" 2>&1 || return 3
    done
    [[ -z ${CLICOLOR-} ]] || return 1
    (( ${+aliases[startx]} == 0 )) || return 2
  }
  It 'loads the kept modules on FreeBSD with no FreeBSD-only CLICOLOR or startx behavior'
    When run freebsd_case
    The status should be success
  End
  options_case() {
    emulate -L zsh
    unset LANG
    TERM=xterm PS1=x; export PS1
    source "$MARKSHARC_ROOT/modules/zsh-options/init.zsh" || return 1
    [[ $TERM == xterm-256color && $LANG == en_US.UTF-8 && $BLOCKSIZE == 1K && ${(t)PS1} != *export* ]] || return 2
    [[ ! -o bgnice && -o globdots && -o extendedglob && -o menucomplete ]] || return 3
    ms_unit 'MARKSHARC_SESSION=interactive; _ms_test_render_module zsh-options; print -r -- "${aliases[j]}"' || return 4
    [[ $(<"$TEST_ROOT/out") == 'jobs -l' ]] || return 5
    # Directory-stack options belong to nav.
    unsetopt autocd pushdsilent
    source "$MARKSHARC_ROOT/modules/nav/init.zsh" || return 4
    [[ -o autocd && -o pushdsilent && -o pushdminus ]]
  }
  It 'applies the kept option set, locale and TERM fix, and nav owns the directory options'
    When run options_case
    The status should be success
  End
  cached_tools_case() {
    emulate -L zsh
    stub_tool zoxide; stub_tool starship; stub_tool direnv; printf '#!/bin/sh\necho fortune >> "$OPLOG"\n' > "$TEST_ROOT/bin/fortune"; chmod +x "$TEST_ROOT/bin/fortune"
    source "$MARKSHARC_ROOT/core/zsh/lib/cache.zsh"; source "$MARKSHARC_ROOT/core/zsh/lib/util.zsh"
    _ms_reloading=0
    source "$MARKSHARC_ROOT/modules/zoxide/init.zsh"; source "$MARKSHARC_ROOT/modules/prompt-starship/init.zsh"
    [[ $(grep -c '^zoxide$' "$OPLOG") == 1 && $(grep -c '^starship$' "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 1; }
    # direnv is opt-in; greeting too.
    source "$MARKSHARC_ROOT/modules/direnv/init.zsh"; source "$MARKSHARC_ROOT/modules/greeting/init.zsh"
    [[ $(grep -c '^direnv$' "$OPLOG") == 0 && $(grep -c '^fortune$' "$OPLOG") == 0 ]] || { cat "$OPLOG"; return 2; }
    _ms_opt_direnv_enable=on _ms_opt_greeting_fortune=on
    source "$MARKSHARC_ROOT/modules/direnv/init.zsh"; source "$MARKSHARC_ROOT/modules/greeting/init.zsh"
    [[ $(grep -c '^direnv$' "$OPLOG") == 1 && $(grep -c '^fortune$' "$OPLOG") == 1 ]] || { cat "$OPLOG"; return 3; }
    # A reload (cs, li) runs none of them again.
    : > "$OPLOG"; _ms_reloading=1
    local m; for m in zoxide prompt-starship direnv greeting; do source "$MARKSHARC_ROOT/modules/$m/init.zsh"; done
    [[ ! -s $OPLOG ]]
  }
  It 'initialises zoxide and starship once, and direnv and fortune only when enabled'
    When run cached_tools_case
    The status should be success
  End
  completion_case() {
    emulate -L zsh
    # compinit is stubbed; awk and grep must not run (the old hosts style forked them).
    local tool
    for tool in awk grep; do printf '#!/bin/sh\necho "FORBIDDEN %s" >> "$OPLOG"\nexit 99\n' "$tool" > "$TEST_ROOT/bin/$tool"; chmod +x "$TEST_ROOT/bin/$tool"; done
    mkdir -p "$TEST_ROOT/fp"; print 'print "compinit $*" >> "$OPLOG"' > "$TEST_ROOT/fp/compinit"
    fpath=( "$TEST_ROOT/fp" $fpath )
    _ms_reloading=0
    source "$MARKSHARC_ROOT/modules/completion/init.zsh" || return 1
    # -i: the audit still runs (never -C or -u), but an insecure directory is
    # excluded silently instead of prompting a startup that cannot answer.
    [[ $(<"$OPLOG") == "compinit -i -d $XDG_CACHE_HOME/marksharc/"*"/zcompdump" ]] || { cat "$OPLOG"; return 2; }
    [[ $(zstyle -L ':completion:*' menu) == *select=1* ]] || return 3
    zstyle -L ':completion:*' hosts > /dev/null || return 4
  }
  It 'initialises completion natively with zstyles and no external forks'
    When run completion_case
    The status should be success
  End
End
