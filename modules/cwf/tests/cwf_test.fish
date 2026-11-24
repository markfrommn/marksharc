source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

ms_stub cwf 'printf "%s|%s\n" "$COMMON_DEV_TOOLS" "$*" >>"$TEST_ROOT/cwf-calls"
case "$*" in
"shell fish") echo "set -gx _CWF_SHELL_LOADED yes"; echo "function _marker_cwf; echo cwf-loaded; end" ;;
*) exit 3 ;;
esac'

set -e COMMON_DEV_TOOLS
ms_module cwf >"$TEST_ROOT/out" 2>&1
@test "startup prints nothing" ! -s "$TEST_ROOT/out"
@test "the hook registries exist and are empty" (set -q -g cwf_new_post_create_hooks cwf_new_copy_exclude; and echo yes) = yes
@test "the registries start empty" (count $cwf_new_post_create_hooks $cwf_new_copy_exclude) -eq 0
@test "without COMMON_DEV_TOOLS cwf is not asked" ! -e "$TEST_ROOT/cwf-calls"
@test "cwf-new is autoloadable" (functions -q cwf-new; and echo yes) = yes

set -g cwf_new_post_create_hooks hook-a
set -g cwf_new_copy_exclude 'r:*.key' 'r:.env.local'
ms_module cwf
@test "existing registry entries survive a reload" "$cwf_new_post_create_hooks" = hook-a
@test "existing exclude patterns survive a reload" (count $cwf_new_copy_exclude) -eq 2

set -g COMMON_DEV_TOOLS "$TEST_ROOT/missing"
ms_module cwf
@test "a COMMON_DEV_TOOLS that is not a directory is ignored" ! -e "$TEST_ROOT/cwf-calls"

command mkdir -p "$TEST_ROOT/dev tools"
set -gx COMMON_DEV_TOOLS "$TEST_ROOT/dev tools"
ms_module cwf >"$TEST_ROOT/out" 2>&1
@test "a COMMON_DEV_TOOLS directory loads the cwf integration" "$_CWF_SHELL_LOADED" = yes
@test "the integration's functions exist" "$(_marker_cwf)" = cwf-loaded
@test "cwf was asked for 'shell fish' with the tools directory" "$(cat "$TEST_ROOT/cwf-calls")" = "$TEST_ROOT/dev tools|shell fish"
@test "loading the integration is quiet" ! -s "$TEST_ROOT/out"

set -e _CWF_SHELL_LOADED
ms_module cwf
@test "an unchanged directory is an init-cache hit" (count <"$TEST_ROOT/cwf-calls") -eq 1
@test "the cache hit still loads the integration" "$_CWF_SHELL_LOADED" = yes

command mkdir -p "$TEST_ROOT/other tools"
set -gx COMMON_DEV_TOOLS "$TEST_ROOT/other tools"
ms_module cwf
@test "a different tools directory misses the cache" (count <"$TEST_ROOT/cwf-calls") -eq 2

set -e _CWF_SHELL_LOADED
set -g _ms_fish_reloading 1
ms_module cwf
set -e _ms_fish_reloading
@test "reload does not load the integration again" ! (set -q _CWF_SHELL_LOADED; and echo set)

# The wrapper hands both registries to the write-once executable newline-joined.
ms_stub cwf-new 'printf "%s\n" "$MARKSHARC_CWF_NEW_HOOKS" >"$TEST_ROOT/hooks"
printf "%s\n" "$MARKSHARC_CWF_NEW_COPY_EXCLUDE" >"$TEST_ROOT/excl"
printf "%s\n" "$*" >"$TEST_ROOT/args"'
set -g cwf_new_post_create_hooks first 'second hook'
set -g cwf_new_copy_exclude 'r:*.key' 'r:a b'
cwf-new feature/x
@test "cwf-new passes the hooks newline-joined" "$(cat "$TEST_ROOT/hooks")" = "first
second hook"
@test "cwf-new passes the exclude patterns newline-joined" "$(cat "$TEST_ROOT/excl")" = "r:*.key
r:a b"
@test "cwf-new passes its argument through" "$(cat "$TEST_ROOT/args")" = feature/x
set -g cwf_new_post_create_hooks
set -g cwf_new_copy_exclude
cwf-new x
@test "empty registries pass empty values" -z "$(cat "$TEST_ROOT/hooks")"

# Completion: the local branches of the current repository, for the one argument.
set -l repo "$TEST_ROOT/repo"
$REAL_GIT init -q -b main "$repo"
$REAL_GIT -C "$repo" config user.email fixture@example.invalid
$REAL_GIT -C "$repo" config user.name Fixture
$REAL_GIT -C "$repo" commit -q --allow-empty -m first
$REAL_GIT -C "$repo" branch feature/one
$REAL_GIT -C "$repo" branch side-two
builtin cd "$repo"
set -l offered (complete -C 'cwf-new ' | string split -f1 \t)
@test "completion offers the local branches" "$offered" = "feature/one main side-two"
@test "completion offers only branches, not files" (count $offered) -eq 3
@test "completion filters by the typed prefix" "$(complete -C 'cwf-new fe' | string split -f1 \t)" = feature/one
@test "completion offers nothing for a second argument" -z "$(complete -C 'cwf-new main ')"
builtin cd "$TEST_ROOT"
@test "completion outside a repository offers nothing" -z "$(complete -C 'cwf-new ')"

ms_cleanup
