source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

ms_module git-worktree >"$TEST_ROOT/out" 2>&1
@test "startup prints nothing" ! -s "$TEST_ROOT/out"
@test "the pre-remove hook registry exists" (set -q -g gwt_clean_pre_remove_hooks; and echo yes) = yes
@test "the registry starts empty" (count $gwt_clean_pre_remove_hooks) -eq 0
@test "the helpers are autoloadable" (functions -q git-managed git-unmanaged git_managed_arr_core gwt-clean; and echo yes) = yes

set -g gwt_clean_pre_remove_hooks keep-me
ms_module git-worktree
@test "an existing registry survives a reload" "$gwt_clean_pre_remove_hooks" = keep-me

# gwt-clean hands its hook list to the write-once executable newline-joined, and applies directives.
ms_stub gwt-clean 'printf "%s\n" "$MARKSHARC_GWT_CLEAN_HOOKS" >"$TEST_ROOT/hooks"
printf "%s\n" "$*" >"$TEST_ROOT/gwt-args"
printf "cd\t%s\n" "$TEST_ROOT/dir x" >>"$MARKSHARC_DIRECTIVES"'
command mkdir -p "$TEST_ROOT/dir x"
set -g gwt_clean_pre_remove_hooks hook-one 'hook two'
gwt-clean
@test "gwt-clean passes the hooks newline-joined" "$(cat "$TEST_ROOT/hooks")" = "hook-one
hook two"
@test "gwt-clean applies the cd directive (space in the path)" "$PWD" = "$TEST_ROOT/dir x"
builtin cd "$TEST_ROOT"

# git-managed and git-unmanaged on a disposable repository.
set -l repo "$TEST_ROOT/repo with space"
$REAL_GIT init -q -b main "$repo"
$REAL_GIT -C "$repo" config user.email fixture@example.invalid
$REAL_GIT -C "$repo" config user.name Fixture
builtin cd "$repo"
printf x >tracked.txt
printf x >"sp ace.txt"
printf x >-dash
printf x >'*.star'
printf x >local-only
printf x >other.star
# Literal pathspecs, so the fixture tracks the file named '*.star' and not other.star.
$REAL_GIT --literal-pathspecs add tracked.txt "sp ace.txt" -- -dash '*.star'
$REAL_GIT commit -q -m first

@test "git-managed lists the tracked files" "$(git-managed tracked.txt local-only 'sp ace.txt' -dash)" = "Git Managed: tracked.txt sp ace.txt -dash"
@test "git-unmanaged lists the untracked files" "$(git-unmanaged tracked.txt local-only 'sp ace.txt' other.star)" = "Git Un-Managed: local-only other.star"
@test "pathspecs are literal: a tracked glob name is one file" "$(git-managed '*.star' other.star)" = "Git Managed: *.star"
@test "pathspecs are literal: a glob does not match other files" "$(git-unmanaged '*.star' other.star)" = "Git Un-Managed: other.star"
@test "a leading dash is a file name" "$(git-unmanaged -dash -nothere)" = "Git Un-Managed: -nothere"
@test "nothing selected still prints the label" "$(git-managed local-only)" = "Git Managed: "
@test "no arguments print the bare label" "$(git-unmanaged)" = "Git Un-Managed: "
git-managed tracked.txt >/dev/null
@test "git-managed succeeds" $status -eq 0

set -g MARKSHARC_SESSION agent
@test "git-managed prints nothing outside an interactive session" -z "$(git-managed tracked.txt)"
@test "git-unmanaged prints nothing outside an interactive session" -z "$(git-unmanaged local-only)"
set -g MARKSHARC_SESSION interactive

# The private helper: fills a variable of the caller, validates its arguments.
set -l picked old
git_managed_arr_core unmanaged picked tracked.txt local-only
@test "the helper fills the caller's variable" "$picked" = local-only
git_managed_arr_core managed picked local-only
@test "the helper sets an empty list when nothing matches" (count $picked) -eq 0
git_managed_arr_core sideways picked tracked.txt
@test "the helper rejects an unknown mode" $status -eq 1
git_managed_arr_core managed 'bad name' tracked.txt
@test "the helper rejects an invalid variable name" $status -eq 1
@test "the helper leaves no scratch variables behind" (count (set -n | string match '_ms_gm_*')) -eq 0

# Outside a repository git fails: the failure is reported, not hidden as "unmanaged".
builtin cd "$TEST_ROOT"
set -lx GIT_CEILING_DIRECTORIES "$TEST_ROOT"
git-unmanaged tracked.txt >"$TEST_ROOT/out" 2>/dev/null
@test "outside a repository the status is git's failure" $status -eq 128
@test "outside a repository nothing is listed" ! -s "$TEST_ROOT/out"

ms_cleanup
