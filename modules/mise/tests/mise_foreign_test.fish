source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
set -g _ms_opt_mise_tools ''
set -g _ms_opt_mise_version_files on
set -g _ms_opt_mise_auto_install off
set -g _ms_opt_mise_set_gobin off
set -g _ms_opt_mise_hook chpwd
set -g _ms_opt_mise_compat on

function __mise_env_eval_on_prompt --on-event fish_prompt
end
function __mise_cd_hook --on-variable PWD
end
function mise
end
set -gx MISE_SHELL fish
set -gx MISE_NODE_VERSION 20
set -gx __MISE_ORIG_PATH foreign
set -gx __MISE_SESSION foreign
ms_module mise >"$TEST_ROOT/out" 2>&1
@test "foreign fish activation is quiet" ! -s "$TEST_ROOT/out"
@test "foreign fish prompt hook survives startup" (functions -q __mise_env_eval_on_prompt; echo $status) = 0
@test "foreign fish PWD hook survives startup" (functions -q __mise_cd_hook; echo $status) = 0
@test "foreign fish function survives startup" (functions -q mise; echo $status) = 0
@test "foreign fish shell state survives startup" "$MISE_SHELL" = fish
@test "foreign fish version survives startup" "$MISE_NODE_VERSION" = 20
@test "foreign fish original path survives startup" "$__MISE_ORIG_PATH" = foreign

set -g _ms_fish_reloading 1
ms_module mise >"$TEST_ROOT/out" 2>&1
set -e _ms_fish_reloading
@test "foreign fish activation is quiet on reload" ! -s "$TEST_ROOT/out"
@test "foreign fish prompt hook survives reload" (functions -q __mise_env_eval_on_prompt; echo $status) = 0
@test "foreign fish PWD hook survives reload" (functions -q __mise_cd_hook; echo $status) = 0
@test "foreign fish function survives reload" (functions -q mise; echo $status) = 0
@test "foreign fish shell state survives reload" "$MISE_SHELL" = fish
@test "foreign fish version survives reload" "$MISE_NODE_VERSION" = 20
@test "foreign fish original path survives reload" "$__MISE_ORIG_PATH" = foreign

ms_cleanup
