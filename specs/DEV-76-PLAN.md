# DEV-76 implementation plan

Implement [LAUNCH-SPEC.md](LAUNCH-SPEC.md) section 9 under
[MARKSHARC-SPEC.md](MARKSHARC-SPEC.md). [LAUNCH-PLAN.md](LAUNCH-PLAN.md)
P3.9.4 defines this unit; DEV-75 is merged in the starting commit.

1. Confirm the pre-implementation gate on sol: run a command after interactive
   init in a launched terminal and exercise the overlay's registered post-create
   hook against disposable input. Preserve the installed checkout and overlay.
2. Extend both native directive appliers with a validated, deferred `exit`.
   Apply remaining directives and remove the directive file before exiting.
   Cover ordering, default and explicit statuses, malformed values and failures.
3. Add `cwf-new` launch parsing and the `launch-repo --in-shell` handoff.
   Resolve the current base repository as a local path or remote name; omit
   selection outside a repository or with `--pick`. Keep plain creation intact;
   emit `LAUNCH_WORKTREE` only after successful `--launched` creation. Cover argv,
   repository selection, hook failures and caller state in both shells.
4. Add resolved-path matching to `gwt-clean`, emitting `exit 0` only after all
   cleanup steps succeed for the marked worktree. Cover matching, aliases,
   absent/different markers and failed steps without weakening cleanup guards.
5. Add zsh/fish completions, the protocol and launch documentation, command
   inventory and changelog. Run focused suites and the complete documented
   checks on Mac and sol. Inspect the diff for correctness and scope.
6. With the operator present, use disposable repositories and scratch overlays
   to check creation, registered hooks, copied files, shell cwd/marker, cleanup
   and terminal closure in Herdr Core/app and TUI on Mac and sol, including
   Mac-to-sol and plain creation in a launched base terminal. Record evidence
   below. Commit and open one PR, then check hosted Mac/Ubuntu CI. Merge stays
   with the operator.

`local_review: skipped:user-requested`; `cloud_review: skipped:user-requested`.
Routine progress has no pause; protected approvals retain their own authority.

## Live acceptance

Checks used disposable Git repositories with local bare origins, the real `cwf`
0.21.0, and scratch homes, overlays and caches. The overlay modules link to the
installed overlay, so its real core-platform post-create hook generated the
fixture environment. A second hook recorded that unmanaged `.env.local` was
already copied and the real hook's `.env` was already present.

The sol branch was staged under a temporary directory. Thin transport wrappers
around the real `hc`, `herdr` and inventory SSH calls selected the scratch
startup environment and staged framework; they did not emulate creation or
cleanup. Neither installed framework nor overlay was changed. Production
launching still runs the target host's own installation and ships no code.

| Check                                          | Observed result                                                                                                                                                                                                           |
| ---------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Pre-implementation gate, Mac to sol Core       | `sol-ts/t2f` classified itself as interactive, registered the real overlay hook and generated `POSTGRES_PORT=5098` from disposable input after run-after-init.                                                            |
| Mac Core/app creation and cleanup              | `t29`, then final-code `t2b`, entered the new worktree, set `LAUNCH_WORKTREE` and ran the overlay hook. Both exited 0 after cleanup; the final-code terminal was visually inspected in the Mac app.                       |
| Mac TUI creation and cleanup                   | `w3:p1` created its session and its workspace disappeared after `gwt-clean`. Final-code `w4:p1` confirmed clean output and successful creation with the copied-file witness hook, then also closed after cleanup.         |
| Mac to sol Core/app                            | `sol-ts/t2g` and final-code `sol-ts/t2h` created sessions in sol worktrees and set the marker. The Mac app's rendered frame showed sol's worktree, branch and shell state. Both exited 0 after successful cleanup.        |
| Mac to sol TUI                                 | `w2E:p1` created a session, ran both hooks, and its workspace disappeared after cleanup. The saved TUI machine is named `sol-ts`; it does not report a hostname matching the separate `sol` SSH alias.                    |
| Failed cleanup                                 | A deliberately untracked file made final-code `sol-ts/t2h` return 1, retain its marker/worktree and stay at its prompt. Removing only that test file allowed normal cleanup and exit 0.                                   |
| Plain creation inside a launched base terminal | Mac `t2c` and sol-local `t2j` ran plain `cwf-new`, entered the new worktree with an empty marker, cleaned it, returned to the base, printed a success marker and stayed open.                                             |
| Failed launched creation                       | Sol TUI `w2F:p1` reached a deliberately failing post-create hook, printed the retained-session error and stayed open in the base with an empty marker. Manual cleanup returned successfully to the base and kept it open. |

Sol's default Herdr app socket refused connections and no local app process was
visible over SSH. Sol Core terminals were visually verified through the Mac
app. The separate multi-day hands-on gate from DEV-74 is not certified here.
All test terminals were closed and removed, all fixture worktrees and branches
were removed, and the fixture hook's empty PostgreSQL directories were cleaned
up. The user's existing terminals and focus were preserved.

## Verification

Focused checks: 137 zsh examples for directives/creation/cleanup/launch; final
launch-repo suite 16 examples; cwf suite 21; zsh completion suite 2; fish
directive contracts 60; fish units 637 assertions; lint 217 files; and
`git diff --check`. All passed.

- Mac: the full zsh suite passed 669 examples. The fish unit suite passed 637
  assertions using a minimal PATH and a process-only wrapper disabling the
  host's global mise activation. The repository suite passed 35 examples and
  final lint passed for 217 files. The final contract and install reruns passed
  125 and 65 examples respectively. Fish printed sandbox notification warnings;
  the runner reported no assertion or Fish execution failures.
- Sol (Debian 13): the zsh suite passed 668 examples with one Apple Terminal
  platform skip, contracts passed 125 examples, install passed 65, repository
  checks passed 35, and fish units passed 638 assertions. The latest cwf and
  launch-repo tests were synchronized afterward and passed all 37 examples;
  non-document source hashes matched the Mac. Final launch startup contracts
  passed all six examples after the fixture update below, and final lint passed.
- Two verification setup defects were diagnosed rather than changing product
  behavior. The initial sol install clone test saw an empty staging repository;
  committing the staged source fixed it and the entire install suite passed.
  Mac Fish 4.9.3's detached first-start completion generator raced fixture
  teardown in the unchanged launch contracts; the failure reproduced alone.
  The launch fixture now sets Fish's upstream `FISH_UNIT_TESTS_RUNNING` flag
  to suppress that unrelated background work. The contract suite was rerun.
- Self-review covered literal argv, base-only picker selection, cleanup status
  propagation, directive removal before exit, scoped publication and docs.
  No dependencies, installed configurations or generated surfaces changed.
- `local_review: skipped:user-requested`; `cloud_review: skipped:user-requested`.
