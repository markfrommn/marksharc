# DEV-75 implementation plan

Implement [LAUNCH-SPEC.md](LAUNCH-SPEC.md) section 8 and the configuration in section 10, under [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md) sections 8 and 10. [LAUNCH-PLAN.md](LAUNCH-PLAN.md) P3.9.3 defines the boundary. DEV-74 supplies `launch-session`; worktree creation belongs to DEV-76.

1. Add `modules/git-worktree/bin/repo-list` and focused inventory helpers. Read configured roots through the existing configuration loader. Scan immediate base repositories, chain `git worktree list --porcelain`, and exclude missing/prunable worktrees. Emit five TSV fields (name, path, kind, base, branch). Cache atomically with mode 0600 and a version/time/roots header under the caller's per-host cache. Cover empty roots, spaces and metacharacters, duplicate names, detached branches, linked worktrees and cache permissions with disposable repositories.
2. Implement freshness for age, changed roots, explicit rescan, missing requested names and missing returned paths. Add remote inventory using explicit SSH targets from hosts.conf or mux machine inventories, excluding via commands, and the BatchMode/ConnectTimeout/stdin discipline of `marksharc push`. Cache remote results separately; validate output and propagate failures without replacing a good cache. Specs stub ssh and cover success, failure, timeout and absent targets.
3. Add `modules/launch/bin/launch-repo`. Parse both forms and forward launch options and command argv without evaluation. Resolve local/reserved/picked hosts through existing helpers; select bases by exact name, worktrees by directory then exact branch, and duplicates through the shared picker (status 3 without a terminal). Handle the current repository and explicit local/remote paths, reject reserved creation syntax and `--pwd`, rescan at most once after a miss, and exec `launch-session` with host/path/name. Cover all statuses, conflicts, slash-containing branches, awkward argv, picker choices and handoff with command stubs.
4. Add zsh and fish completions that read cached names without scanning or contacting a remote service. Update module descriptions, launch guide, README/catalog as applicable, changelog and tests/README.md contract inventory. Run targeted specs and `tests/check`, then inspect the final diff. Local and cloud provider reviews are skipped at the operator's request.
5. Run live acceptance with the operator present: repository-name launch on Mac and sol, picker and nonterminal behavior, cross-host existing-worktree launch, and a new repository found after a cached scan. Exercise Herdr Core/app and TUI sessions on both hosts; use temporary fixtures and record exact evidence below. Run the Linux checks on sol and the hosted macOS/Ubuntu checks after opening the PR. Commit and share one DEV-75 PR; the operator owns merge.

## Live acceptance

Checks use disposable repositories and scratch overlays on both hosts, with this
branch staged in a scratch checkout on sol. A real SSH transport wrapper selects
the staged remote `repo-list`; neither installed checkout was changed. Each
launched shell printed a unique marker and its working directory after init.

| Check                              | Observed result                                                                                                                                                                                  |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Mac repository name, Herdr Core    | `t28` opened in the fixture base repository and appeared as a space in the Mac app.                                                                                                              |
| Mac repository name, Herdr TUI     | `w2:p1` printed the fixture base directory after interactive init.                                                                                                                               |
| sol repository name, Herdr Core    | `t2c` printed the fixture base directory; the Mac app listed it under `sol-ts`.                                                                                                                  |
| sol repository name, Herdr TUI     | `w2C:p1` printed the fixture base directory after interactive init.                                                                                                                              |
| Mac to sol existing worktree, Core | `sol:dev75-live-repo/feature/dev75` resolved by exact branch and opened `sol-ts/t2d` in the worktree. The app frame was visually inspected and showed the directory, branch, and command marker. |
| Mac to sol existing worktree, TUI  | `sol-ts:dev75-live-repo/dev75-live-wt` resolved by directory and opened `w2D:p1` in the worktree.                                                                                                |
| Interactive picker                 | Real `gum` under a PTY listed base and worktree with branch/path, accepted a selection, and produced the correct Core launch preview.                                                            |
| No terminal                        | An omitted repository exited 3 with the explicit-selection hint.                                                                                                                                 |
| New repository after cached scan   | A newly created fixture repository was found without `--rescan` on the Mac and sol. The multi-repository scan exposed and fixed an unwanted zsh declaration printed before the TSV rows.         |
| Remote freshness                   | After a worktree was cached and removed on sol, its branch request exited 1 without launching. A change to sol's scratch roots appeared on the next ordinary remote inventory read.              |

The default app socket on sol had no listening window during these checks; sol
Core visibility was verified through the Mac app, as the operator confirmed.
All six test terminals were closed after verification. Local and cloud provider reviews are skipped at the
operator's explicit request. The earlier DEV-74 multi-day hands-on observation
is separate from these DEV-75 acceptance checks.

## Verification

- Mac: lint passed for 217 files; the full check's zsh, contract, install and
  repository suites passed (591, 74, 65 and 35 examples). After the final edits,
  the focused repository-launch suite passed all 14 examples and lint passed.
  The fish suite passed all 633 assertions with a minimal PATH and the host's
  global Homebrew mise auto-activation disabled for the test process. No host
  configuration was changed. The original fish attempt exposed installed
  optional tools and global mise hooks leaking into otherwise isolated fixtures.
- sol (Debian 13): `tests/check` passed lint, 597 zsh examples, 74 contract
  examples, 65 installation examples, 35 repository examples and 634 fish
  assertions. One Apple Terminal example was skipped because its platform file
  is absent. The initial run found a GNU/BSD stat mismatch in the new cache-mode
  assertion; the assertion now selects the platform's stat syntax.
- Self-review checked scope, literal argv handling, cache validation and
  publication contents. No dependencies or generated surfaces changed.
- `local_review: skipped:user-requested`; `cloud_review: skipped:user-requested`.
