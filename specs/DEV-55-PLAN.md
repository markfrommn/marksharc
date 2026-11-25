# DEV-55 — Opt-in Carapace completion module implementation plan

> **For agentic workers:** Implement task-by-task with behavior specs covering mutual exclusion, missing binary fallback, options, and switching. Keep work on the DEV-55 branch; phase-lite owns the final save and share steps.

**Goal:** Add an opt-in `completion-carapace` module for zsh (P3.7) with configurable bridges and excludes, mutually exclusive with `completion-fzf-tab` unless the overlay forces both, plus a clean way to switch between them in a fresh shell (`exec zsh -l`). Evaluation after real-world use was moved to `DEV-73`.

**Authority:** `specs/MARKSHARC-SPEC.md` §§ 4.2, 5, 6.4, 6.5, 6.9, 6.10, 7.1, 8, 10; `specs/MARKSHARC-PLAN.md` P3.7; Linear `DEV-55` and `DEV-73`.

## Global constraints

- Zsh only; fish and bash are explicitly out of scope for DEV-55.
- Opt-in by default: installing `carapace` alone must not activate Carapace or disable `completion-fzf-tab`.
- Startup stays quiet, fast, and offline: `carapace _carapace zsh` runs through `_ms_init_cached`, keyed on `CARAPACE_BRIDGES` and `CARAPACE_EXCLUDES`, and never runs in batch or agent shells.
- A missing `carapace` binary never breaks startup and leaves `completion-fzf-tab` active as the automatic fallback.
- File-scope declarations say `-g`; every module is safe to source twice and to reload.
- Public modules hold no personal values. Tests use a temporary HOME and command stubs only.

## Decisions

1. **Load order (spec 6.4 completion band 70–79).** `completion` 70 → `completion-fzf-tab` 71 → `completion-carapace` 72 → `fzf-fish` 75 → `herdr` 78 → `cwf` 79. Both UI modules load after `compinit` and before `history-atuin` (83), `zsh-autosuggestions` (95), and `zsh-syntax-highlighting` (99).
2. **Opt-in activation and mutual exclusion.** Core helpers `_ms_completion_carapace_wanted`, `_ms_completion_carapace_active`, and `_ms_completion_fzf_tab_active` live in `core/zsh/lib/modules.zsh` so `completion-fzf-tab` (order 71) and `completion-carapace` (order 72) agree before either runs.
   - In default all-modules overlays, `completion-carapace` is inactive until `set completion-carapace.enable on`.
   - In explicit-list overlays, listing `module completion-carapace` activates it unless `set completion-carapace.enable off` overrides it.
   - When Carapace is active, `completion-fzf-tab` is suppressed unless `set completion-carapace.allow_fzf_tab on` (or `MARKSHARC_COMPLETION_UI=both`).
   - If `carapace` is missing from PATH, `completion-carapace` is skipped and `completion-fzf-tab` stays active.
3. **Options and cache invalidation.** `modules/completion-carapace/module.conf` declares `enable` (`off`), `bridges` (`zsh,fish,bash`), `excludes` (`""`), and `allow_fzf_tab` (`off`), plus `requires command carapace` and `package brew carapace`. Both comma- and space-separated lists normalize to comma-separated `CARAPACE_BRIDGES` / `CARAPACE_EXCLUDES`; empty, `off`, or `none` unsets them. `_ms_init_cached -k "${CARAPACE_BRIDGES-}|${CARAPACE_EXCLUDES-}"` ensures option edits invalidate the cached init script. `MARKSHARC_CARAPACE_ACTIVE` tracks module-owned exports so switching off across `exec zsh -l` clears stale inherited `CARAPACE_BRIDGES` / `CARAPACE_EXCLUDES`.
4. **Switching between UIs.** Persistent switching edits `completion-carapace.enable` (and optionally `allow_fzf_tab`) in the overlay or `hosts/<host>.conf`. Session switching uses `MARKSHARC_COMPLETION_UI` (`carapace`, `fzf-tab`, `both`, `native`) or the autoloaded `completion-ui` helper in `modules/completion/functions/zsh/completion-ui`, which sets/clears `MARKSHARC_COMPLETION_UI` and suggests `exec zsh -l` to apply.
5. **Diagnostics and Day 2.** `marksharc doctor` reports missing `carapace` when `completion-carapace` is enabled (whether via `set completion-carapace.enable on` or explicit `module completion-carapace`, without duplicate warnings) and suppresses missing `fzf-tab` plugin complaints while Carapace is actively suppressing fzf-tab. `marksharc bootstrap` includes `brew "carapace"` from `module.conf`.

## File map

- Create `modules/completion-carapace/{module.conf,init.zsh,tests/carapace_spec.sh}` and symlink `tests/spec/zsh/modules/completion-carapace`.
- Create `modules/completion/functions/zsh/completion-ui`.
- Modify `core/zsh/lib/modules.zsh`, `modules/completion/init.zsh`, `modules/completion-fzf-tab/init.zsh`, `core/cli/doctor`.
- Modify `templates/overlay/config.conf`, `tests/spec/zsh/{modules_spec.sh,doctor_spec.sh,day2_spec.sh}`.
- Update `README.md`, `CHANGELOG.md`, `tests/README.md`, `specs/MARKSHARC-SPEC.md`, `specs/MARKSHARC-PLAN.md`, and Linear `DEV-73`.

## Tasks

### Task 1: Core mutual-exclusion predicates and completion-carapace module
- [x] Add `_ms_completion_carapace_wanted`, `_ms_completion_carapace_active`, and `_ms_completion_fzf_tab_active` in `core/zsh/lib/modules.zsh`.
- [x] Add `modules/completion-carapace/{module.conf,init.zsh}`, update `modules/completion-fzf-tab/init.zsh` and `modules/completion/init.zsh`, and add `modules/completion/functions/zsh/completion-ui`.
- [x] Update `core/cli/doctor` and `templates/overlay/config.conf`.

### Task 2: Specs for mutual exclusion, missing binary, options, switching, doctor, and Day 2
- [x] Add `modules/completion-carapace/tests/carapace_spec.sh` and link it from `tests/spec/zsh/modules/completion-carapace`.
- [x] Update `tests/spec/zsh/modules_spec.sh` (band 70–79), `tests/spec/zsh/doctor_spec.sh`, and `tests/spec/zsh/day2_spec.sh`.

### Task 3: Documentation, tracker handoff, and verification
- [x] Update `README.md`, `CHANGELOG.md`, `tests/README.md`, `specs/MARKSHARC-SPEC.md`, `specs/MARKSHARC-PLAN.md`, and Linear `DEV-73` with Carapace focus areas and user choices.
- [x] Run repository checks (`tests/lint`, zsh, contract, install, and repo suites).
- [x] Run local CodeRabbit review (`local-review-coderabbit`) and self-review.

## Outcome

Implemented as planned:

- `modules/completion-carapace` loads at order 72 (zsh-only, opt-in via `set completion-carapace.enable on` or explicit `module completion-carapace`), exports normalized `CARAPACE_BRIDGES` (default `zsh,fish,bash`) and `CARAPACE_EXCLUDES`, and caches `carapace _carapace zsh` via `_ms_init_cached` keyed on both variables.
- `completion-fzf-tab` (order 71) is suppressed automatically when Carapace is active unless `set completion-carapace.allow_fzf_tab on` or `MARKSHARC_COMPLETION_UI=both`. When `carapace` is missing from PATH, startup stays silent and falls back to `completion-fzf-tab`.
- `completion-ui` (`modules/completion/functions/zsh/completion-ui`) inspects active completion UI state and switches per-session via `MARKSHARC_COMPLETION_UI` with `exec zsh -l` guidance; `completion/init.zsh` clears stale inherited module-owned Carapace exports when switching off across `exec zsh -l`.
- `core/cli/doctor` reports missing `carapace` when `completion-carapace` is enabled and suppresses missing `fzf-tab` plugin errors while Carapace is suppressing fzf-tab. `package brew carapace` registers Carapace for `marksharc bootstrap`.
- Linear `DEV-73` updated with Carapace evaluation focus areas and user choices from this implementation.

### Verification

- `tests/lint`: ok (205 files)
- `tests/run-tests --shell zsh spec/zsh`: 514 examples, 0 failures, 1 platform skip (`history_spec.sh` macOS Terminal file)
- `tests/run-tests --shell sh spec/contract`: 68 examples, 0 failures
- `tests/run-tests --shell sh spec/install` (detached from `/dev/tty`): 65 examples, 0 failures
- `tests/run-tests --shell sh spec/repo`: 35 examples, 0 failures
- `tests/run-fish-units`: skipped locally (`fishtape 3.0.1` not installed on this host; no fish files modified; runs in CI)
- Local CodeRabbit review: `provider_result: skipped:wrong-organization` (`coderabbit auth status` reported `Organization: convoyai`, expected `markfrommn`; remediation: `coderabbit auth org` and select `markfrommn`)

