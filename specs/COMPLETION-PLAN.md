# MarkSharc Declarative Completion Plan

> **For agentic workers:** this plan covers three implementation pull requests, one per Linear issue, following design PR [DEV-84](https://linear.app/psols/issue/DEV-84). Before starting an entry, write its task-level plan to `specs/DEV-<id>-PLAN.md`, then implement task by task with a spec for every behaviour change and keep `tests/check` green.

**Goal:** Deliver consistent, offline-safe interactive completions for `marksharc`, `launch-session`, `launch-repo`, and `cwf-new` across native zsh, Bash 4.4+, Fish, and Carapace from one declarative `.comp` specification rendered by `marksharc render`.

**Authority:** [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md) first, then [COMPLETION-SPEC.md](COMPLETION-SPEC.md) (with [LAUNCH-SPEC.md](LAUNCH-SPEC.md) and [BASH-SPEC.md](BASH-SPEC.md) for command and Bash backend contracts). Section numbers below refer to [COMPLETION-SPEC.md](COMPLETION-SPEC.md) unless another document is named.

**Program plan:** [MARKSHARC-PLAN.md](MARKSHARC-PLAN.md) lists this work as L8 ([DEV-84](https://linear.app/psols/issue/DEV-84) design, [DEV-85](https://linear.app/psols/issue/DEV-85)–[DEV-87](https://linear.app/psols/issue/DEV-87) implementation). Its global constraints apply to every entry here.

**Tracking:** Linear project MarkSharc, milestone `5. Advanced/Forward`.

## Boundaries

| Entry | Issue | Title | Estimate | Depends on |
|---|---|---|---|---|
| L8.0 | [DEV-84](https://linear.app/psols/issue/DEV-84) | Spec and plan declarative completion rendering and Carapace parity | 3 (design) | P2.4 ([DEV-44](https://linear.app/psols/issue/DEV-44)) |
| L8.1 | [DEV-85](https://linear.app/psols/issue/DEV-85) | Completion spec renderer and dynamic candidate helper | 3 | L8.0 ([DEV-84](https://linear.app/psols/issue/DEV-84)) |
| L8.2 | [DEV-86](https://linear.app/psols/issue/DEV-86) | Declarative completion specs for `marksharc`, `launch`, and `cwf-new` | 3 | L8.1 ([DEV-85](https://linear.app/psols/issue/DEV-85)) |
| L8.3 | [DEV-87](https://linear.app/psols/issue/DEV-87) | Carapace managed spec wiring, lifecycle, and end-to-end parity | 3 | L8.2 ([DEV-86](https://linear.app/psols/issue/DEV-86)) |

```mermaid
flowchart LR
  P2_4["P2.4 DEV-44"]
  L8_0["L8.0 DEV-84"]
  L8_1["L8.1 DEV-85"]
  L8_2["L8.2 DEV-86"]
  L8_3["L8.3 DEV-87"]
  P2_4 --> L8_0
  L8_0 --> L8_1
  L8_1 --> L8_2
  L8_2 --> L8_3
```

The entries run sequentially: L8.1 builds and verifies the candidate helper, parser, and four-target renderer; L8.2 authors the four command specs, wires native zsh/Bash/Fish loading, and retires the replaced hand-written files; L8.3 activates Carapace managed symlinks, cache invalidation, precedence, doctor/uninstall lifecycle, and documentation.

## Pull requests

### L8.1 — Completion spec renderer and dynamic candidate helper ([DEV-85](https://linear.app/psols/issue/DEV-85))

- **Repo:** marksharc
- **Estimate:** 3
- **Depends on:** L8.0 ([DEV-84](https://linear.app/psols/issue/DEV-84))
- **Spec:** sections 2, 3, 4, 5.1, 5.2

**Goal:** Provide the shared offline dynamic candidate helper, the closed `.comp` directive parser, and the four-target renderer integrated into `marksharc render` without breaking existing completions.

**Scope**

- Add `core/cli/complete` (section 4): strictly offline, read-only zsh executable supporting `modules`, `hosts`, `installers`, `update-steps`, `launch-hosts`, `repos`, `base-repos`, `worktrees`, `launch-repo-target`, and `git-branches`, including `--from-carapace` env support, host-name path-traversal checks, and literal tab-separated output.
- Add `core/zsh/lib/render-completions.zsh` (sections 3, 5.1, 5.2):
  - Parse and validate `.comp` files (`command`, `subcommand`, `flag`, `arg`, `mode`) using `_ms_words`.
  - Discover specs from `core/completions/*.comp`, enabled public modules, and enabled overlay modules with override precedence.
  - Emit four target artifacts per spec into the atomic render stage: `zsh/_<cmd>`, `bash/<cmd>.bash`, `fish/<cmd>.fish`, and `carapace/<cmd>.yaml`.
- Integrate `_ms_render_completions` into `core/zsh/lib/render.zsh` (moving `completion-bash` to its own `$_ms_render_bash_stage` so `$_ms_render_stage/bash` promotes cleanly to `$cache/completions/bash`, and keeping `render --env-only` strictly out of completion/shim directories) and fold `*.comp` paths into `core/zsh/lib/envid.zsh`.

**Tests**

- `tests/spec/zsh/complete_helper_spec.sh`: every `ms:*` kind in temporary `HOME` with spaces/apostrophes/colons, missing caches, invalid host rejection, `--from-carapace`, and stubbed `ssh`/`hc` asserting zero invocations.
- `tests/spec/zsh/render_completions_spec.sh`: valid/invalid `.comp` parsing, golden output assertions for all four targets, `zsh -n`, `bash -n`, `fish --no-execute`, and Carapace YAML validation (when `carapace` is installed), plus `envid` invalidation and coexistence with existing generated completions.

**Done when**

- `core/cli/complete` and `core/zsh/lib/render-completions.zsh` pass all unit, golden, and syntax specs.
- `marksharc render` atomically renders `.comp` fixtures for all four targets while keeping all existing suites green.
- `tests/check` passes on macOS and Ubuntu.

---

### L8.2 — Declarative completion specs for `marksharc`, `launch`, and `cwf-new` ([DEV-86](https://linear.app/psols/issue/DEV-86))

- **Repo:** marksharc
- **Estimate:** 3
- **Depends on:** L8.1 ([DEV-85](https://linear.app/psols/issue/DEV-85))
- **Spec:** sections 5.2, 5.3, 7, 8

**Goal:** Deliver full native completion parity for `marksharc`, `launch-session`, `launch-repo`, and `cwf-new` across zsh, Bash 4.4+, and Fish from `.comp` specs, and retire the replaced hand-written files.

**Scope**

- Author the four `.comp` specs (section 7):
  - `core/completions/marksharc.comp`
  - `modules/launch/completions/launch-session.comp`
  - `modules/launch/completions/launch-repo.comp`
  - `modules/cwf/completions/cwf-new.comp`
- Add `core/bash/complete.bash` (preserving Readline unquoting, `:@=` word-break reassembly, and literal quoting from `workflow.bash`) and load rendered `$cache/completions/bash/*.bash` in `core/bash/interactive.bash`.
- Wire `$cache/completions/fish` onto `fish_complete_path` (with reload cleanup) in `core/fish/marksharc.fish`.
- Retire the replaced hand-written completion files listed in section 5.3 while preserving `cwf.bash`, `herdr.bash`, and generated `completion` / `completion-bash` outputs.

**Tests**

- Extend `tests/spec/zsh/launch_completions_spec.sh` and add `tests/spec/zsh/marksharc_completions_spec.sh` (PTY tests for `marksharc`, `launch-session`, `launch-repo` including `--host`/`--base-only`/worktrees/`host:`, and `cwf-new` including `--host`).
- Extend `tests/spec/contract/bash_static_completion_spec.sh` with rendered `marksharc` hierarchy tests and verify all existing quoted path/repo/worktree/branch Bash unit and PTY tests stay green (plus Bash 3.2 env-only regression).
- Extend `tests/fish/completions_test.fish` to load from rendered cache and cover all four commands, reload cleanup, `launch-repo --host`/`--base-only`, `cwf-new --host`, and `marksharc install`/`update --only`.

**Done when**

- `marksharc`, `launch-session`, `launch-repo`, and `cwf-new` autocomplete consistently in native zsh, Bash 4.4+, and Fish.
- Replaced hand-written files are removed and `tests/check` passes on macOS and Ubuntu.

---

### L8.3 — Carapace managed spec wiring, lifecycle, and end-to-end parity ([DEV-87](https://linear.app/psols/issue/DEV-87))

- **Repo:** marksharc
- **Estimate:** 3
- **Depends on:** L8.2 ([DEV-86](https://linear.app/psols/issue/DEV-86))
- **Spec:** sections 6, 8

**Goal:** Wire rendered Carapace YAML specs cleanly into Carapace's platform specs directory with full lifecycle management, cache invalidation, shell precedence, diagnostics, and documentation.

**Scope**

- Implement platform Carapace specs-dir resolution and manifest-tracked symlink reconciliation in `marksharc render` (sections 6.1, 6.2): create/update symlinks when `completion-carapace` is enabled, never overwrite non-MarkSharc files or foreign symlinks, warn on conflicts, and prune stale symlinks on module or Carapace disable.
- Update `core/cli/uninstall` to remove manifest-tracked Carapace symlinks before any `--purge` cache cleanup.
- Update `core/cli/doctor` to report missing, broken, or conflicting managed Carapace spec symlinks when `completion-carapace` is enabled and `carapace` is installed (section 6.5).
- Fold the Carapace spec manifest fingerprint into `_ms_init_cached -k` in `modules/completion-carapace/init.zsh` and `_ms_bash_init_cached -k` in `core/bash/backends.bash` (section 6.3).
- Align Bash completion loading in `core/bash/interactive.bash` / `core/bash/backends.bash` so active Carapace owns commands with managed specs (unless excluded via `CARAPACE_EXCLUDES`) while native Bash completions take over when Carapace is inactive or excluded (section 6.4).
- Update user/module authoring documentation (`docs/` and `tests/README.md` contract inventory).

**Tests**

- `tests/spec/contract/carapace_completions_spec.sh`:
  - End-to-end `carapace <cmd> export ...` for `marksharc`, `launch-session`, `launch-repo`, and `cwf-new` in temporary `HOME` (skipped cleanly when `carapace` is absent), proving dynamic hosts, repos, worktrees, modules, installers, update steps, and branches.
  - Managed symlink lifecycle: creation, non-MarkSharc conflict preservation, stale pruning on disable, `marksharc uninstall` cleanup, `marksharc doctor` diagnostics, and `_ms_init_cached` key invalidation.
  - Zsh and Bash Carapace-active vs native-fallback and `CARAPACE_EXCLUDES` precedence specs.

**Done when**

- With `completion-carapace` enabled, Carapace completes all four commands end-to-end on macOS and Linux.
- Disabling `completion-carapace` or running `marksharc uninstall` cleans up managed symlinks without touching user-authored specs.
- `marksharc doctor`, docs, and `tests/check` (including install E2E) pass on macOS and Ubuntu.
