# DEV-43 (P2.3) — Move the system and workflow modules — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the P1.6 system and workflow modules from `mark-desktop-files` into this repository, with their module-local specs, the moved `system_modules` suite, restored P1.6 coverage in the shared specs DEV-42 trimmed, a passing personal-value lint, and Linux fixes only where a moved spec exposes them.

**Architecture:** The source tree keeps modules at `config/zsh/modules/<name>/` with specs in `<name>/tests/`; this repository's layout (spec 6.2) is `modules/<name>/`, and module test directories are linked from `tests/spec/zsh/modules/<name>` (the linkage contract `module_specs_spec.sh` already enforces, vacuously until now). Private/transitional modules (`convoy`, `mdf`, `mark-tools`, `site-bac`) live in the author's overlay and never enter this repo; the coverage they participated in is restored against a **synthesized** overlay built by each spec (design rule 10, DEV-42 precedent: `core_env_spec`'s `site_override_case`).

**Tech stack:** zsh 5.9+, ShellSpec 0.28.1 (pinned), POSIX sh, GitHub Actions (macos-latest, ubuntu-latest).

**Spec:** [specs/MARKSHARC-SPEC.md](../../specs/MARKSHARC-SPEC.md) sections 6.4, 6.5, 6.6, 6.13, 7.1, 10; [specs/MARKSHARC-PLAN.md](../../specs/MARKSHARC-PLAN.md) P2.3 with the P1.6 outcome and the P1.6/P1.7 implementer notes.

**Source:** `/home/mark/etc/mark-desktop-files` @ `6f4b52c33131143b07234aecf0035a1f94d8055a`, clean, tree-identical to `origin/main` `4f8469cf1544347e342289cf7d9f5bf1c29fa7e0` (read-only for this unit). Recorded in move commits as `Source: mark-desktop-files 4f8469cf1544347e342289cf7d9f5bf1c29fa7e0`.

## Global Constraints

- macOS and Linux are both supported. Shell startup is quiet, offline, and installs nothing; batch and agent sessions print nothing. A missing optional tool never breaks startup.
- Portable code (`core/`, `modules/`, `templates/`) contains no personal values (user, host, org, or site names; home paths). Values arrive from options/overlay; specs synthesize overlay fixtures with neutral names.
- No new dependency or toolchain change. Tests use a temporary HOME and command stubs, never real services.
- Never modify `/home/mark/etc/mark-desktop-files` (read-only source).
- Conventional Commit subjects; commits carry the `Co-Authored-By: Claude <noreply@anthropic.com>` trailer; move commits record the `Source:` revision above.
- Mechanical rename passes follow `memory/perl-mdf-root-move.md`: escape the dollar (`\$MDF_ROOT`), re-copy fresh before re-running, then grep for `MDF_ROOT` leftovers, `config/zsh` hand-edit cases, and `^\$MARKSHARC_ROOT` line-start insertions.
- No generated surface exists in scope; nothing to regenerate.
- Scope stops at the move: no installer, CLI, sync/doctor, or cutover work (P2.4+).

## Scope decisions (from the packet and plan, recorded so executors do not re-litigate)

- **Modules copied (exactly these 13):** agent, ssh-agent, x11, docker, mux, titles, herdr, wezterm, cc-providers, git-worktree, cwf, fish-bridge, and `cloud` (the P1.6-owned `install-krew`, per the P1.6 outcome and the DEV-42 deferral note). A grep of the source modules confirms their code has no `MDF_ROOT`/`config/zsh`/personal references: the copy is verbatim.
- **Module specs moved (adapted):** all 14 `modules/<name>/tests/*_spec.sh` files — agent (marker option), agents (ssh-agent + state migration), x11, docker, mux, titles, herdr, wezterm, providers (cc-providers, half of the old wrappers spec), cleanup (gwt-clean + pre-remove hook point), repo_sync (the repo half of the old sync spec), cwf (cwf-new + post-create hook point and copy-exclude), fish_bridge, cloud.
- **Suite specs moved (adapted):** `system_modules_spec.sh`, with the private-overlay assertions replaced by a synthesized overlay (see Task 4).
- **Specs deliberately not moved:** `provider_cli_spec.sh` — it tests the source's `bin/model-test-provider.sh`, and no `bin/` destination exists in this repository's layout (same treatment as DEV-42's `history_import_spec`; reported as a follow-up, not silently dropped).
- **Private modules excluded:** `convoy`, `mdf`, `mark-tools`, `site-bac` (the author's overlay; P1.7 territory, never portable).
- **Shared-spec restorations (Task 5):** the P1.6 pieces DEV-42 trimmed from `startup_spec`, `history_spec`, `modules_spec`, `omz_removal_spec`, `overlay_spec`. ENVMAN stays unrestored (envman is private `mark-tools` content); CWF_INIT is restored against a synthesized `COMMON_DEV_TOOLS` directory, which is the cwf module's documented, portable contract.

## Adaptation rules applied to every moved spec file

Mechanical (memory/perl-mdf-root-move.md form — escaped dollars):

1. `\$MDF_ROOT/config/zsh/core` → `\$MARKSHARC_ROOT/core/zsh`
2. `\$MDF_ROOT/config/zsh/modules` → `\$MARKSHARC_ROOT/modules`
3. `\$MDF_ROOT/tests/shell` → `\$MARKSHARC_ROOT/tests`
4. remaining `\$MDF_ROOT` → `\$MARKSHARC_ROOT`
5. `$MARKSHARC_HOME/core/<file>.zsh` and `$MS_HOME/core/lib/` → `core/zsh/…` forms (as DEV-42 rule 5).

Hand edits are enumerated per file in the tasks below. After the pass: grep for `MDF_ROOT`, `config/zsh`, and `^\$MARKSHARC_ROOT` line starts.

---

### Task 1: Commit this plan

**Files:**
- Create: `docs/superpowers/plans/2026-11-21-dev-43-move-system-workflow-modules.md`

- [ ] **Step 1: Commit the plan document**

```bash
git add docs/superpowers/plans/2026-11-21-dev-43-move-system-workflow-modules.md
git commit -m "docs(plan): DEV-43 task plan for moving the system and workflow modules

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Move the 13 modules (TDD red half)

The module specs are the failing tests for this task: they land in Task 3 but the copy order here is specs-first in spirit — Task 3 Step 2 runs them and watches them fail before this task's copy makes them pass. Executing Task 2 and Task 3 as one TDD loop is acceptable; the red run must happen before the module copy.

**Files:**
- Create: `modules/<name>/…` for the 13 modules (verbatim copies)

- [ ] **Step 1: Copy the modules verbatim**

```sh
src=/home/mark/etc/mark-desktop-files/config/zsh/modules
for m in agent ssh-agent x11 docker mux titles herdr wezterm cc-providers git-worktree cwf fish-bridge cloud; do
  cp -R "$src/$m" "modules/$m"
done
```

Verify: `ls modules | sort` equals the 26 DEV-42 names plus these 13. Verify no private strings: `grep -rnE 'markfrommn|convoy|plesk|phorn|/Users/mark|/data/work|mark-tools|site-bac' modules` prints nothing. Verify no leftover path references: `grep -rnE 'MDF_ROOT|config/zsh' modules` prints nothing outside `tests/` (the tests are adapted in Task 3; copy them fresh there).

- [ ] **Step 2: Run the moved module specs to green** (after Task 3's adaptation)

Run: `tests/run-tests --shell zsh spec/zsh/modules spec/zsh/module_specs_spec.sh`
Expected: all pass, including the linkage contract against the new symlinks.

- [ ] **Step 3: Commit**

```bash
git add modules tests/spec/zsh/modules tests/spec/zsh/module_specs_spec.sh
git commit -m "feat(modules): move the P1.6 system and workflow modules

The 13 system and workflow modules with their module-local specs: agent,
ssh-agent, x11, docker, mux, titles, herdr, wezterm, cc-providers,
git-worktree, cwf, fish-bridge, cloud. Private/transitional overlay
modules (convoy, mdf, mark-tools, site-bac) stay behind.

Source: mark-desktop-files 4f8469cf1544347e342289cf7d9f5bf1c29fa7e0

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Move and link the module specs

**Files:**
- Create: `modules/<name>/tests/*_spec.sh` (copied with the module, then adapted in place), `tests/spec/zsh/modules/<name>` symlinks

- [ ] **Step 1: Apply the mechanical adaptations to the copied tests**

```sh
perl -pi -e 's/\$MDF_ROOT\/config\/zsh\/core/\$MARKSHARC_ROOT\/core\/zsh/g;
             s/\$MDF_ROOT\/config\/zsh\/modules/\$MARKSHARC_ROOT\/modules/g;
             s/\$MDF_ROOT\/tests\/shell/\$MARKSHARC_ROOT\/tests/g;
             s/\$MDF_ROOT/\$MARKSHARC_ROOT/g;
             s{\$MARKSHARC_HOME/core/(zshenv|zshrc|zprofile|zlogin|reload|phase|finalize)\.zsh}{\$MARKSHARC_HOME/core/zsh/$1.zsh}g;
             s{\$MS_HOME/core/lib/}{\$MS_HOME/core/zsh/lib/}g;' modules/*/tests/*_spec.sh
```

Known hand edits after the pass (from the pre-move grep): `agents_spec.sh` (`core/lib/util.zsh` source line is covered by rule 1), `titles_spec.sh` (rule 2), `herdr_spec.sh` (rule 1 ×2). If any file is shredded, re-copy it fresh from the source and re-run the pass on that file only.

- [ ] **Step 2: Verify the pass is clean**

Run: `grep -rn 'MDF_ROOT' modules; grep -rn 'config/zsh' modules; grep -rn '^\$MARKSHARC_ROOT' modules`
Expected: no output.

- [ ] **Step 3: Watch the specs fail (TDD red)**

Run: `tests/run-tests --shell zsh spec/zsh/modules`
Expected: FAIL — this must run **before** Task 2 Step 1's copy (or after removing the module code); the point is a demonstrated red before green. If Task 2 already copied the code, record the red from the pre-copy run of the linkage contract (`module_specs_spec.sh` fails while the symlinks are absent).

- [ ] **Step 4: Create the symlinks**

```sh
mkdir -p tests/spec/zsh/modules
for m in agent ssh-agent x11 docker mux titles herdr wezterm cc-providers git-worktree cwf fish-bridge cloud; do
  ln -s ../../../../modules/"$m"/tests tests/spec/zsh/modules/"$m"
done
```

Verify: `tests/run-tests --shell zsh spec/zsh/module_specs_spec.sh` passes (links case and contract case).

---

### Task 4: Move `system_modules_spec.sh`, neutralized

**Files:**
- Create: `tests/spec/zsh/system_modules_spec.sh` (copied, then adapted)

- [ ] **Step 1: Copy, mechanical pass, then hand edits**

Mechanical pass as Task 3. Hand edits:

- `wiring_case`: drop `mdf-sync` and `link-cleanup` from the function list (private `mdf`/`mark-tools` content). Synthesize a neutral overlay before the PTY run. **Execution correction:** the option assignments live in the demo module's `init.zsh`, not `env.zsh` — the loader resets declared option variables to their defaults at the init plan, so an overlay sets another module's options from its init (the source's `convoy` pattern; verified by probe during execution):

```zsh
    # A neutral stand-in for the author's private overlay: roots/orgs arrive as
    # options and a private module registers a cwf-new hook (design rule 10).
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/demo-work"
    print 'describe "demo work roots"' > "$XDG_CONFIG_HOME/marksharc/modules/demo-work/module.conf"
    cat > "$XDG_CONFIG_HOME/marksharc/modules/demo-work/init.zsh" <<'DATA'
[[ -n $_ms_opt_git_worktree_roots ]] || _ms_opt_git_worktree_roots="/work/one /work/two"
[[ -n $_ms_opt_git_worktree_orgs ]] || _ms_opt_git_worktree_orgs="org-one org-two"
demo-cwf-new-hook() { :; }
typeset -gaU cwf_new_post_create_hooks cwf_new_copy_exclude
cwf_new_post_create_hooks=( demo-cwf-new-hook ${cwf_new_post_create_hooks:#demo-cwf-new-hook} )
cwf_new_copy_exclude+=( 'demo:.env' )
demo-cwf-new-hook() { :; }
DATA
```

  and change the assertions to `OPT:/work/one /work/two|org-one org-two` and `CWFHOOK:demo-cwf-new-hook demo:.env`.
- `order_case`: drop `mark-tools` from the env want-list (keep `path brew go rust bun pnpm`) and `convoy mark-tools site-bac` from the init want-list (keep `cc-providers completion herdr cwf titles x11 ssh-agent greeting`).
- `quiet_case`: unchanged.

- [ ] **Step 2: Run it**

Run: `tests/run-tests --shell zsh spec/zsh/system_modules_spec.sh`
Expected: all examples pass.

- [ ] **Step 3: Commit (with the Task 5 restorations, or separately if they land first)**

---

### Task 5: Restore P1.6 coverage in the shared specs

Every restoration is on this repo's already-adapted files (not fresh copies). The DEV-42 commit messages name each trim.

**Files:**
- Modify: `tests/spec/zsh/startup_spec.sh`, `tests/spec/zsh/history_spec.sh`, `tests/spec/zsh/modules_spec.sh`, `tests/spec/zsh/omz_removal_spec.sh`, `tests/spec/zsh/overlay_spec.sh`

- [ ] **Step 1: `startup_spec.sh`**
  - `startup_tools`: restore the `herdr` and `cwf` case-stubs verbatim from the source (drop only the envman lines — private content; update the P2.3 comment to say envman stays with the private overlay).
  - `startup_case`: restore the event list to `COMPINIT HERDR_COMPLETION CWF_INIT` (no ENVMAN), and add a synthesized tooling checkout to the fixture's extra environment: `mkdir -p "$TEST_ROOT/cdt"` in `startup_fixture` and `COMMON_DEV_TOOLS="$TEST_ROOT/cdt"` in the `extra` array, so the portable cwf module runs `cwf shell zsh` exactly once per shell.
  - `maintenance_case`: restore the `install-wezterm-terminfo` and `install-krew` iterations (source form: `load_mfn wezterm`/`load_mfn cloud` per helper).
- [ ] **Step 2: `history_spec.sh`**
  - `ordering_case`: restore the titles lines (`cd .` grep, `o_t`, `o_s < o_a && o_a < o_t`), the It description's "and before the titles cd .", and remove the P2.3 deferral comment.
  - `history_session`: restore the `cwf` (exit 1) and `herdr` (exit 0) stub lines and add them back to the `chmod` list.
- [ ] **Step 3: `modules_spec.sh`**
  - `full_start`: restore `herdr` and `cwf` to the silent-stub tool loop; keep the OPLOG-empty assertion (with no `COMMON_DEV_TOOLS` in that fixture and a silent `herdr`, the log must still be empty — the assertion now proves the P1.6 modules stay quiet too).
- [ ] **Step 4: `omz_removal_spec.sh`**
  - `cloud_startup_removal_case`: restore `herdr cwf` in the tool loop and drop the deferral comment.
- [ ] **Step 5: `overlay_spec.sh`**
  - Restore `disabled_hook_case` in neutral form: synthesize overlay module `demo-hooks` whose `init.zsh` registers `demo-cwf-new-hook` in `cwf_new_post_create_hooks` with an `_ms_init_cleanups` removal (the convoy pattern, neutral names); assert `before=1`, append `module demo-hooks off` to `config.conf`, reload, assert `after=0`. `private_layout_case` stays unrestored (it asserts the author's private tree, which never lives here) — update the comment to say so.
- [ ] **Step 6: Run the restored suites**

Run: `tests/run-tests --shell zsh spec/zsh`
Expected: the whole zsh suite passes.

- [ ] **Step 7: Commit**

```bash
git add tests/spec/zsh
git commit -m "test(zsh): restore P1.6 startup, history, module and overlay coverage

The system/workflow assertions DEV-42 deferred to this unit, with private
values replaced by synthesized overlay fixtures (COMMON_DEV_TOOLS, demo
work roots/orgs, a demo cwf-new hook). envman coverage stays with the
private overlay.

Source: mark-desktop-files 4f8469cf1544347e342289cf7d9f5bf1c29fa7e0

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Personal-value lint and Linux fixes

**Files:** any module file a moved spec proves wrong on Linux (each fix lands with its failing regression spec first).

- [ ] **Step 1: Run the lint**

Run: `tests/run-tests --shell zsh spec/zsh/personal_values_spec.sh`
Expected: pass over the enlarged portable tree (module test directories are scanned too).

- [ ] **Step 2: Full gate**

Run: `tests/check`
Expected: green — lint, zsh suite (now including `spec/zsh/modules/*` and `system_modules_spec`), contract suite, repo suite.

- [ ] **Step 3: Linux-only failures**

Any failure a moved spec exposes on this Linux worktree that the diff does not explain is fixed per the hard rules: environment comparison first, then a failing regression spec, then the behavior fix. None are expected — the source specs are stub- and fixture-based — but `agents_spec`'s PTY/socket helper, `x11_spec`'s tty probes and `repo_sync_spec`'s git fixtures are the known risk points.

---

### Task 7: CHANGELOG, test inventory, and plan outcome

**Files:**
- Modify: `CHANGELOG.md`, `tests/README.md`, `specs/MARKSHARC-PLAN.md`

- [ ] **Step 1: CHANGELOG under `## [Unreleased]` → `### Added`**

```markdown
- The 13 system and workflow modules (`modules/`): agent, ssh-agent, x11,
  docker, mux, titles, herdr, wezterm, cc-providers, git-worktree, cwf,
  fish-bridge, cloud — with their module-local specs linked from
  `tests/spec/zsh/modules/`.
```

- [ ] **Step 2: `tests/README.md` contract inventory**

Add rows for the moved suites (one per module area plus `system_modules`), and rewrite the module-tests linkage row: module-local test directories now exist and the linkage example is live, not vacuous.

- [ ] **Step 3: `specs/MARKSHARC-PLAN.md` P2.3 outcome**

Record the outcome in the P2.3 section as DEV-42 did for P2.2: what moved, the source revision, gate counts, and the explicit note that the final Mac in-place comparison is an unverified manual AC from this Linux worktree.

- [ ] **Step 4: Commit**

```bash
git add CHANGELOG.md tests/README.md specs/MARKSHARC-PLAN.md
git commit -m "docs: changelog, test inventory and P2.3 outcome for the module move

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: Gates, runtime evidence, and stack conformance

**Files:** none (verification only).

- [ ] **Step 1: Hermetic parity evidence (AC: shell startup with an overlay)**

The restored `startup_spec` mode matrix, `system_modules_spec` wiring/order/quiet cases and `overlay_spec` reload cases are the hermetic parity evidence: they drive the real tree plus a synthesized overlay through PTY, agent and batch sessions and compare against the behavior the source specs pinned. Run them and keep the counts.

- [ ] **Step 2: Full gates**

Run: `tests/check` from the worktree root. CI runs exactly these four steps (lint, zsh, contract, repo) per `.github/workflows/ci.yml`; no additional CI-required local check exists.

- [ ] **Step 3: No runtime repo writes**

Run: `git status --porcelain` before and after the gates.
Expected: unchanged apart from intended commits.

- [ ] **Step 4: stack-check**

Read `.omp/skills/stack-check/SKILL.md` and run its audit over `origin/main...HEAD`. Expected: no must-fix findings.

- [ ] **Step 5: Manual AC**

The literal final Mac in-place comparison (shell from the new repo with the overlay behaves the same as in-place on the Mac) cannot be performed from this Linux worktree: report it as an unverified manual AC.

## Self-Review Notes (completed during planning)

- **Spec coverage:** P2.3 scope items map to Tasks 2–3 (modules + their specs), 4 (system suite), 5 (restored coverage), 6 (lint + Linux fixes), 7 (docs), 8 (ACs). The packet's spec list (agents, cleanup, cwf, sync, titles, wrappers, hook-point, state-migration) maps to the 14 module spec files named in Scope decisions.
- **Private values:** every assertion the source pinned against the author's overlay is reproduced against a synthesized overlay with neutral names; the personal-value lint scans `modules/` including the moved `tests/` directories.
- **Type/name consistency:** helpers (`load_mfn`, `module_run`, `ms_*`) already exist in this repo's `tests/spec/support/core.zsh` with the same signatures the moved specs use; the symlink depth (`../../../../`) matches this repo's layout (`tests/spec/zsh/modules/<name>` → `modules/<name>/tests`).
