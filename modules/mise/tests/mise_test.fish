source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
set -g MOD "$MARKSHARC_ROOT/modules/mise"
set -g SHIMS "$TEST_ROOT/mise data/shims"
set -g NVM_BIN "$HOME/.nvm/versions/node/v22.1.0/bin"
set -g GVM_BIN "$HOME/.gvm/gos/go1.23.0/bin"
command mkdir -p "$SHIMS" "$NVM_BIN" "$HOME/.nvm/alias" "$GVM_BIN" \
    "$HOME/.gvm/environments" "$HOME/.pyenv/bin" "$HOME/.pyenv/shims" "$TEST_ROOT/homebrew/bin"
printf '22\n' >"$HOME/.nvm/alias/default"
printf 'gvm_go_name=go1.23.0\n' >"$HOME/.gvm/environments/default"
printf '#!/bin/sh\nexit 0\n' >"$GVM_BIN/go"
printf '#!/bin/sh\nexit 0\n' >"$HOME/.pyenv/bin/pyenv"
command chmod +x "$GVM_BIN/go" "$HOME/.pyenv/bin/pyenv"
ms_stub mise 'printf "external-mise %s\n" "$*" >>"$OPLOG"; exit 0'

function legacy_path
    set -gx PATH "$TEST_ROOT/bin" "$NVM_BIN" "$GVM_BIN" "$HOME/.pyenv/shims" \
        /opt/keep-manager "$TEST_ROOT/homebrew/bin" /usr/bin /bin
end

function load_env
    _ms_fish_path_begin
    _ms_fish_path_add brew "$TEST_ROOT/homebrew/bin"
    _ms_fish_module_env mise
    _ms_fish_module_env node-nvm
    _ms_fish_module_env go-gvm
    _ms_fish_module_env python
    _ms_fish_path_build
end

function path_text
    string join '|' -- $PATH
end

# Ownership is per tool. Only nvm and pyenv stand aside here; gvm and unrelated
# inherited entries remain, while the shim directory occurs once ahead of brew.
set -g _ms_opt_mise_tools 'node python ruby unsupported-tool'
set -g _ms_opt_mise_version_files on
set -g _ms_opt_mise_auto_install off
set -g _ms_opt_mise_set_gobin off
set -g _ms_opt_mise_hook chpwd
set -g _ms_opt_mise_compat on
set -gx MISE_DATA_DIR "$TEST_ROOT/mise data"
legacy_path
load_env >"$TEST_ROOT/out" 2>&1
@test "owned fish environment is quiet" ! -s "$TEST_ROOT/out"
@test "owned node path is removed" (contains -- "$NVM_BIN" $PATH; echo $status) = 1
@test "unowned gvm path is retained" (contains -- "$GVM_BIN" $PATH; echo $status) = 0
@test "owned pyenv paths are removed" (string match -q -- "$HOME/.pyenv/*" $PATH; echo $status) = 1
@test "unrelated inherited path is retained" (contains -- /opt/keep-manager $PATH; echo $status) = 0
@test "fish shims occur once" (count (contains -i -- "$SHIMS" $PATH)) = 1
@test "fish shims precede brew" (contains -i -- "$SHIMS" $PATH; or echo 999) -lt (contains -i -- "$TEST_ROOT/homebrew/bin" $PATH; or echo 0)
@test "fish safe auto-install default is false" "$MISE_NOT_FOUND_AUTO_INSTALL" = false
@test "fish safe GOBIN default is false" "$MISE_GO_SET_GOBIN" = false
@test "fish version files name only owned supported tools" "$MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS" = node,python,ruby
@test "fish owns configured node" (_ms_fish_mise_owns node; echo $status) = 0
@test "fish does not own unconfigured go" (_ms_fish_mise_owns go; echo $status) = 1
@test "fish owns configured python" (_ms_fish_mise_owns python; echo $status) = 0
@test "fish owns configured ruby" (_ms_fish_mise_owns ruby; echo $status) = 0
@test "fish rejects unsupported tools" (_ms_fish_mise_owns unsupported; echo $status) = 1
@test "fish pyenv fallback stands aside" (set -q PYENV_ROOT; echo $status) = 1
@test "fish environment never invokes mise" ! -s "$OPLOG"

# Empty tools and a missing executable are automatic fallback, not errors.
set -g _ms_opt_mise_tools ''
legacy_path
load_env
@test "empty tools restore nvm" (contains -- "$NVM_BIN" $PATH; echo $status) = 0
@test "empty tools restore gvm" (contains -- "$GVM_BIN" $PATH; echo $status) = 0
@test "empty tools restore pyenv" (contains -- "$HOME/.pyenv/shims" $PATH; echo $status) = 0
@test "empty tools omit shims" (contains -- "$SHIMS" $PATH; echo $status) = 1
@test "empty tools do not export auto-install" (set -q MISE_NOT_FOUND_AUTO_INSTALL; echo $status) = 1
set -g _ms_opt_mise_tools 'node go python'
command rm -f "$TEST_ROOT/bin/mise"
legacy_path
set -gx PATH "$SHIMS" $PATH
load_env
@test "missing mise restores nvm" (contains -- "$NVM_BIN" $PATH; echo $status) = 0
@test "missing mise restores gvm" (contains -- "$GVM_BIN" $PATH; echo $status) = 0
@test "missing mise restores pyenv" (contains -- "$HOME/.pyenv/shims" $PATH; echo $status) = 0
@test "missing mise drops inherited shims" (contains -- "$SHIMS" $PATH; echo $status) = 1
@test "missing mise rejects ownership" (_ms_fish_mise_owns node; echo $status) = 1

# Option mapping and shim overrides preserve paths with spaces.
ms_stub mise 'exit 0'
set -g _ms_opt_mise_tools 'node go'
set -g _ms_opt_mise_version_files off
set -g _ms_opt_mise_auto_install on
set -g _ms_opt_mise_set_gobin on
set -gx GOPATH "$HOME/.gvm/pkgsets/go1.23.0/global"
set -gx GVM_OVERLAY_PREFIX "$GOPATH/overlay"
set -gx gvm_go_name go1.23.0
set -gx gvm_pkgset_name global
load_env
@test "fish owned Go clears inherited gvm GOPATH" (set -q GOPATH; echo $status) = 1
@test "fish owned Go clears gvm overlay" (set -q GVM_OVERLAY_PREFIX; echo $status) = 1
set -gx GOPATH "$HOME/.gvm/pkgsets/go1.23.0/global:$TEST_ROOT/custom go"
set -gx GVM_OVERLAY_PREFIX "$HOME/.gvm/pkgsets/go1.23.0/global/overlay"
load_env
@test "fish custom GOPATH survives" "$GOPATH" = "$TEST_ROOT/custom go"
@test "fish mixed custom GOPATH clears gvm overlay" (set -q GVM_OVERLAY_PREFIX; echo $status) = 1
@test "fish maps enabled auto-install to true" "$MISE_NOT_FOUND_AUTO_INSTALL" = true
@test "fish maps enabled set-gobin to true" "$MISE_GO_SET_GOBIN" = true
@test "fish maps disabled version files to an empty list" "$MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS" = ''
set -gx MISE_SHIMS_DIR "$TEST_ROOT/shim override"
command mkdir -p "$MISE_SHIMS_DIR"
load_env
@test "explicit fish shim directory wins" (contains -- "$MISE_SHIMS_DIR" $PATH; echo $status) = 0
@test "explicit fish shim directory supersedes data shims" (contains -- "$SHIMS" $PATH; echo $status) = 1
set -e MISE_SHIMS_DIR

# A native activation fixture exposes the same hooks and command as mise itself.
printf '%s\n' '#!/bin/sh' \
    'if [ "$1 $2" = "activate fish" ]; then' \
    '  printf "activate fish\n" >>"$OPLOG"' \
    "  printf '%s\\n' 'function __mise_env_eval' '    printf \"refresh\\\\n\" >>\"\$OPLOG\"' '    set -gx PATH (string match -v -- \"$SHIMS\" $PATH)' 'end' 'function __mise_env_eval_on_prompt --on-event fish_prompt' '    printf \"prompt\\\\n\" >>\"\$OPLOG\"' 'end' 'function __mise_cd_hook --on-variable PWD' '    printf \"directory\\\\n\" >>\"\$OPLOG\"' '    __mise_env_eval' 'end' 'function mise' '    printf \"mise\" >>\"\$OPLOG\"' '    for arg in \$argv' '        printf \"|%s\" \"\$arg\" >>\"\$OPLOG\"' '    end' '    printf \"\\\\n\" >>\"\$OPLOG\"' '    if test \"\$argv[1]\" = deactivate' '        functions -e __mise_env_eval __mise_env_eval_on_prompt __mise_cd_hook' '    end' '    return 0' 'end' 'function __mise_env_eval_2 --on-event fish_preexec; end' 'function fish_command_not_found; end' 'set -gx MISE_SHELL fish' 'set -gp PATH \"$XDG_DATA_HOME/mise/installs/node/22/bin\"' 'set -g MISE_ACTIVATION_SETTING \"\$MISE_NOT_FOUND_AUTO_INSTALL\"'" \
    '  exit 0' \
    fi \
    'printf "unexpected-external %s\n" "$*" >>"$OPLOG"; exit 99' >"$TEST_ROOT/bin/mise"
command chmod +x "$TEST_ROOT/bin/mise"
set -g _ms_opt_mise_tools 'node go python'
set -g _ms_opt_mise_version_files on
set -g _ms_opt_mise_auto_install off
set -g _ms_opt_mise_set_gobin off
set -g _ms_opt_mise_hook chpwd
printf '' >"$OPLOG"
load_env
ms_module mise >"$TEST_ROOT/out" 2>&1
@test "fish activation startup is quiet" ! -s "$TEST_ROOT/out"
@test "fish activation ran once" (count (string match -r '^activate fish$' <"$OPLOG")) = 1
@test "chpwd removes the fish prompt hook" (functions -q __mise_env_eval_on_prompt; echo $status) = 1
@test "chpwd retains the fish PWD hook" (functions -q __mise_cd_hook; echo $status) = 0
builtin cd "$TEST_ROOT"
@test "fish PWD hook refreshes after cd" (count (string match -r '^refresh$' <"$OPLOG")) = 1
@test "fish directory hook restores manager shims" (contains -- "$SHIMS" $PATH; echo $status) = 0
@test "fish prompt hook did not run" (count (string match -r '^prompt$' <"$OPLOG")) = 0

printf '' >"$OPLOG"
mise shell node@22
mise use go@1.24
mise unuse node
mise deactivate
set -l deactivate_status $status
printf 'mise|shell|node@22\nrefresh\nmise|use|go@1.24\nrefresh\nmise|unuse|node\nrefresh\nmise|deactivate\n' >"$TEST_ROOT/expected"
@test "fish wrapper refreshes after shell and use" (cmp -s "$TEST_ROOT/expected" "$OPLOG"; echo $status) = 0
@test "fish deactivate keeps its own status" $deactivate_status = 0

# Activation is cached, but auto_install shapes the generated activation and its key.
printf '' >"$OPLOG"
set -g _ms_opt_mise_auto_install on
_ms_fish_module_env mise
_ms_fish_mise_drop_activation_paths
set -g _ms_fish_reloading 1
ms_module mise
set -e _ms_fish_reloading
@test "fish auto-install change gets fresh activation" "$MISE_ACTIVATION_SETTING" = true
_ms_fish_mise_drop_activation_paths
set -g _ms_fish_reloading 1
ms_module mise
set -e _ms_fish_reloading
@test "fish repeated activation is cached with its shaping option" (count (string match -r '^activate fish$' <"$OPLOG")) = 1

set -g _ms_opt_mise_hook prompt
ms_module mise
@test "prompt mode restores the fish prompt hook" (functions -q __mise_env_eval_on_prompt; echo $status) = 0
@test "prompt mode keeps the fish PWD hook" (functions -q __mise_cd_hook; echo $status) = 0
set -l activation_before_off (count (string match -r '^activate fish$' <"$OPLOG"))
set -g _ms_opt_mise_hook off
ms_module mise
@test "off removes the fish prompt hook" (functions -q __mise_env_eval_on_prompt; echo $status) = 1
@test "off removes the fish PWD hook" (functions -q __mise_cd_hook; echo $status) = 1
@test "off removes the fish preexec hook" (functions -q __mise_env_eval_2; echo $status) = 1
@test "off restores fish default command-not-found" (functions -q fish_command_not_found; echo $status) = 0
@test "off removes mise saved command-not-found" (functions -q __mise_fish_command_not_found; echo $status) = 1
@test "off clears fish mise shell state" (set -q MISE_SHELL; echo $status) = 1
@test "off removes activated tool paths" (contains -- "$XDG_DATA_HOME/mise/installs/node/22/bin" $PATH; echo $status) = 1
@test "off does not activate again" (count (string match -r '^activate fish$' <"$OPLOG")) = $activation_before_off

# Compatibility functions preserve every argument and normalize gvm's go prefix.
command mkdir -p "$TEST_ROOT/autoload"
printf 'function nvm; echo real-nvm; end\n' >"$TEST_ROOT/autoload/nvm.fish"
set -gp fish_function_path "$TEST_ROOT/autoload"
set -g _ms_opt_mise_tools 'node go'
set -g _ms_opt_mise_hook chpwd
ms_module mise
printf '' >"$OPLOG"
nvm use '22 beta' --silent
nvm install 20
nvm ls
nvm current
nvm alias default 22
gvm use go1.23.1
gvm install go1.24
gvm ls
gvm list
gvm current
gvm alias default go1.23.1
printf 'mise|shell|node@22 beta|--silent\nrefresh\nmise|install|node@20\nmise|ls|node\nmise|current|node\nmise|use|--global|node@22\nrefresh\nmise|shell|go@1.23.1\nrefresh\nmise|install|go@1.24\nmise|ls|go\nmise|ls|go\nmise|current|go\nmise|use|--global|go@1.23.1\nrefresh\n' >"$TEST_ROOT/expected"
@test "fish compatibility mappings call mise literally" (cmp -s "$TEST_ROOT/expected" "$OPLOG"; echo $status) = 0
set -l nvm_hint (nvm exec 22 node 2>&1)
@test "fish nvm hint returns two" $status = 2
set -l gvm_hint (gvm pkgset list 2>&1)
@test "fish gvm hint returns two" $status = 2
set -l hints (string join \n -- $nvm_hint $gvm_hint)
@test "fish hints show node shell form" (string match -q '*mise shell node@*' -- "$hints"; echo $status) = 0
@test "fish hints show node global form" (string match -q '*mise use --global node@*' -- "$hints"; echo $status) = 0
@test "fish hints show go install form" (string match -q '*mise install go@*' -- "$hints"; echo $status) = 0
@test "fish hints show go current form" (string match -q '*mise current go*' -- "$hints"; echo $status) = 0

set -g _ms_opt_mise_tools node
ms_module mise
@test "fish unowned gvm compatibility is removed" (functions -q gvm; echo $status) = 1
@test "fish owned nvm compatibility remains" (functions -q nvm; echo $status) = 0
set -g _ms_opt_mise_compat off
ms_module mise
@test "fish disabled nvm compatibility is removed" (functions -q nvm; echo $status) = 1
@test "fish compat-off retains the restoration latch" (set -q _ms_fish_mise_restore_nvm; echo $status) = 0

# Removing the executable while tools are configured also removes activation state.
set -g _ms_opt_mise_compat on
set -g _ms_opt_mise_hook chpwd
ms_module mise
command rm -f "$TEST_ROOT/bin/mise"
ms_module mise >"$TEST_ROOT/out" 2>&1
@test "fish missing-mise reload is quiet" ! -s "$TEST_ROOT/out"
@test "fish missing-mise reload removes the PWD hook" (functions -q __mise_cd_hook; echo $status) = 1
@test "fish missing-mise reload removes the wrapper" (functions -q mise; echo $status) = 1
ms_module node-nvm
@test "fish compat-off then fallback restores real nvm" "$(nvm)" = real-nvm

ms_cleanup
