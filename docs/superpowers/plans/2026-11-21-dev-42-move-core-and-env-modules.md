# DEV-42 (P2.2) — Move the core and the environment/tool modules — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bring the zsh core loader and the 26 P1.5 environment/tool modules from `mark-desktop-files` into this repository, with their specs, a new POSIX-sh cross-shell contract suite wired into CI, and the personal-value lint — green on macOS locally and wired for Ubuntu CI.

**Architecture:** The source tree keeps the loader at `config/zsh/core` with modules at `config/zsh/modules`; this repository's layout (spec 6.2) is `core/zsh/` and `modules/`. The copy is mechanical except a small, enumerated set of path rewrites (`$MARKSHARC_HOME/core/X` → `$MARKSHARC_HOME/core/zsh/X`). Specs move from the source's `tests/shell/spec/zsh/` into this repo's `tests/spec/zsh/`, adapted from `MDF_ROOT`/`config/zsh` paths to `MARKSHARC_ROOT` and the new layout. The contract suite is a new `tests/spec/contract/` directory run under `--shell sh`, launching the real zsh core in a sandboxed HOME.

**Tech stack:** zsh 5.9+, ShellSpec 0.28.1 (pinned), POSIX sh, GitHub Actions (macos-latest, ubuntu-latest).

**Spec:** [specs/MARKSHARC-SPEC.md](../../specs/MARKSHARC-SPEC.md) sections 6.1–6.10, 7, 8, 9, 10; [specs/MARKSHARC-PLAN.md](../../specs/MARKSHARC-PLAN.md) P2.2 with P1.4/P1.5/P1.7/P2.1 context.

**Source:** `/Users/mark/etc/mark-desktop-files` @ `dcdb605a36bdf821b39eddd5f0bd2095bc7ec81d` (read-only for this unit).

## Global Constraints

- macOS and Linux are both supported. Native Windows is not a target.
- Shell startup is quiet, offline, and makes no installs. Batch and agent sessions print nothing.
- A missing optional tool or directory never breaks startup.
- Portable code (`core/`, `modules/`, `templates/`) contains no personal values (user, host, org, or site names; home paths).
- The framework checkout is never written to at run time. State goes to `~/.cache/marksharc` and `~/.local/state/marksharc`.
- No agent configuration is committed. The workflow tool is `cwf`.
- Every behaviour change ships with a spec. Tests use a temporary HOME and command stubs, never real services.
- Conventional Commit subjects; commits carry the `Co-Authored-By: Claude <noreply@anthropic.com>` trailer.
- Implementation commits that move code record `Source: mark-desktop-files dcdb605a36bdf821b39eddd5f0bd2095bc7ec81d`.
- Never modify `/Users/mark/etc/mark-desktop-files` or `/data/work/mark/marksharc` (a possible other checkout) or installed dotfiles.
- No new dependencies; no toolchain changes; no generated files hand-edited (none exist in scope).

## Scope decisions (from the packet and plan, recorded so executors do not re-litigate)

- **Modules copied (exactly these 26):** path, brew, zsh-options, editor, pager, ls, ps, nav, zoxide, completion, completion-fzf-tab, command-not-found, history-atuin, history-native, prompt-starship, node-nvm, go-gvm, python, bun, pnpm, rust, go, lmstudio, cuda, direnv, greeting. Nothing else: no P1.6 system/workflow modules (agent, ssh-agent, x11, docker, mux, titles, herdr, wezterm, cc-providers, git-worktree, cwf, fish-bridge, cloud), no private/transitional overlay modules.
- **Specs moved (adapted):** core_session, core_phases, core_modules, core_cache, core_reload, core_env, core_agent, startup, path, manager_paths, environment, tools, ps, omz_removal, history, overlay, modules, module_specs, personal_values (+ its `personal-values-check.py`).
- **Specs deliberately not moved:** `native_spec.sh` (already here, byte-identical), `pruning_spec.sh` (P1.1 guards against code that never enters this repo — vacuous), `system_modules_spec.sh` and `provider_cli_spec.sh` (P1.6 modules — they arrive with P2.3/DEV-43), `history_import_spec.sh` (tests `scripts/import-legacy-history.zsh`, a one-time migration tool that is not part of the module batch and has no marksharc destination yet — reported as a follow-up).
- **Shipped stub deferred:** the source's `config/zsh/.zshenv.{mac,linux}` ship with the installer in P2.4 (DEV-44). This unit's fixtures generate the two-line stub (`export MARKSHARC_HOME=…; source core/zsh/zshenv.zsh`). Two stub-artifact examples in `core_session_spec` (`stub_case`, `missing_core_case`) are deferred to P2.4 with the stub; the fallback behaviour itself is a P2.4 acceptance item, unchanged.
- **Private content stays behind:** `core_env_spec`'s `plesk_case` becomes a neutral synthesized-overlay case; `overlay_spec` drops `private_layout_case` and `disabled_hook_case` (they reference the author's private overlay and the P1.6 `cwf` module); `startup_spec` drops the envman/herdr/cwf event assertions and the wezterm/cloud installer parts of `maintenance_case` (all P1.6/private); `history_spec`'s `ordering_case` drops its `titles` assertion (P2.3) but keeps starship/atuin ordering. No future acceptance criterion is weakened: P2.3 restores its own module coverage when those modules land.

## Adaptation rules applied to every moved file

Mechanical (applied by the commands in the tasks):

1. `MDF_ROOT/config/zsh/core` → `MARKSHARC_ROOT/core/zsh`
2. `MDF_ROOT/config/zsh/modules` → `MARKSHARC_ROOT/modules`
3. `MDF_ROOT/tests/shell` → `MARKSHARC_ROOT/tests`
4. remaining `MDF_ROOT` → `MARKSHARC_ROOT`
5. `"$MARKSHARC_HOME/core/zshenv.zsh"` and the same pattern for `zshrc.zsh`, `zprofile.zsh`, `zlogin.zsh`, `reload.zsh`, `phase.zsh`, `finalize.zsh`, and `core/lib/` → insert `zsh/` after `core/` (i.e. `core/zsh/zshenv.zsh`, `core/zsh/lib/…`). In specs, `$MS_HOME/core/lib/util.zsh` → `$MS_HOME/core/zsh/lib/util.zsh`.

Hand edits are enumerated per file in the tasks below.

---

### Task 1: Refresh the authority documents from the source

The destination `specs/` holds older copies; the packet requires replacing them with the current source files (read from the source — done; content preserved verbatim).

**Files:**
- Modify: `specs/MARKSHARC-SPEC.md`, `specs/MARKSHARC-PLAN.md`

- [ ] **Step 1: Copy the source documents**

```sh
cp /Users/mark/etc/mark-desktop-files/specs/MARKSHARC-SPEC.md specs/MARKSHARC-SPEC.md
cp /Users/mark/etc/mark-desktop-files/specs/MARKSHARC-PLAN.md specs/MARKSHARC-PLAN.md
```

- [ ] **Step 2: Verify byte-identity with the source**

Run: `cmp specs/MARKSHARC-SPEC.md /Users/mark/etc/mark-desktop-files/specs/MARKSHARC-SPEC.md && cmp specs/MARKSHARC-PLAN.md /Users/mark/etc/mark-desktop-files/specs/MARKSHARC-PLAN.md && echo identical`
Expected: `identical`

- [ ] **Step 3: Commit**

```bash
git add specs/MARKSHARC-SPEC.md specs/MARKSHARC-PLAN.md
git commit -m "docs(specs): refresh MARKSHARC-SPEC and MARKSHARC-PLAN from mark-desktop-files

Source: mark-desktop-files dcdb605a36bdf821b39eddd5f0bd2095bc7ec81d

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 2: Commit this plan

**Files:**
- Create: `docs/superpowers/plans/2026-11-21-dev-42-move-core-and-env-modules.md`

- [ ] **Step 1: Commit the plan document**

```bash
git add docs/superpowers/plans/2026-11-21-dev-42-move-core-and-env-modules.md
git commit -m "docs(plan): DEV-42 task plan for moving the core and env modules

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 3: Harness support for the moved core/module specs

The source suite's zsh-only helpers (`ms_fixture`, `ms_mod`, `ms_run`, `ms_pty`, `ms_fixture_full`, `ms_unit`, `ms_copy_module`, `load_mfn`, `module_run`) live in `tests/shell/spec/support/{fixtures,core}.sh` and reference the source layout. This repo's `spec_helper.sh` is shared with the `--shell sh` suites, so the zsh-only file must be sourced conditionally (POSIX sh would fail parsing zsh syntax in `core.sh`).

**Files:**
- Create: `tests/spec/support/core.sh`
- Modify: `tests/spec/spec_helper.sh`
- Test: existing suites must stay green (`tests/check`)

**Interfaces (consumed by every moved zsh spec):**
- `ms_fixture` — copies `$MARKSHARC_ROOT/core` to `$MS_HOME/core`, creates `$MS_HOME/modules`, writes a generated `$HOME/.zshenv` stub: `export MARKSHARC_HOME="$MS_HOME"` then `source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"`.
- `ms_fixture_full` — same plus copies `$MARKSHARC_ROOT/modules` to `$MS_HOME/modules`. No overlay copy (this repo has none); tests synthesize overlays under `$XDG_CONFIG_HOME/marksharc`.
- `ms_mod <module> <relative-file> <content>` — write a fixture module file.
- `ms_env` — set the `MS_ENV` array for hermetic children (`HOME PATH TERM=dumb SHLVL=2 MARKSHARC_MODULE_GUARD=0 OPLOG TEST_ROOT XDG_*`).
- `ms_run [VAR=value …] zsh-args…` — `env -i` child zsh; stdout→`$TEST_ROOT/out`, stderr→`$TEST_ROOT/err`.
- `ms_pty [VAR=value …] zsh-args…` — same under `tests/support/pty_socket.py`.
- `ms_unit [VAR=value …] <script>` — `zsh -f` with the repo's core libs preloaded, `MARKSHARC_HOME=$MARKSHARC_ROOT`, `_ms_verbose=0`, `MARKSHARC_SESSION=${MARKSHARC_SESSION:-batch}`, `_ms_facts` run, `_ms_env_rebuild=1`, `_ms_env_finalizers=()`.
- `ms_copy_module <name>…` — copy real modules into the fixture tree.
- `load_mfn <module> [fn…]` — put `$MARKSHARC_ROOT/modules/<m>/functions/zsh` on `fpath` and autoload.
- `module_run <module> <zsh-code>` — clean `zsh -f` child with the module's `init.zsh` as `$MOD_INIT` and its functions on fpath.

- [ ] **Step 1: Write `tests/spec/support/core.sh`**

```zsh
# zsh-only helpers for the core loader specs. Each example gets its own HOME
# (fixture_setup); the core is copied into $MS_HOME so nothing writes into the repo.
# Sourced from spec_helper.sh only under zsh (it is not POSIX).
ms_fixture() {
  MS_HOME="$TEST_ROOT/ms"; export MS_HOME
  mkdir -p "$MS_HOME/modules"
  cp -R "$MARKSHARC_ROOT/core" "$MS_HOME/core"
  # The installer's stub ships with P2.4; specs use this generated equivalent.
  print -r -- "export MARKSHARC_HOME=\"$MS_HOME\"
source \"\$MARKSHARC_HOME/core/zsh/zshenv.zsh\"" > "$HOME/.zshenv"
}
# ms_mod <module> <relative-file> <content>
ms_mod() {
  local dir="$MS_HOME/modules/$1"
  mkdir -p "$dir/${2:h}"
  print -r -- "$3" > "$dir/$2"
}
# Hermetic child environment; leading VAR=value arguments are added to it.
ms_env() {
  # SHLVL > 1 keeps nested test shells from behaving like a fresh login.
  MS_ENV=( HOME="$HOME" PATH="$PATH" TERM=dumb SHLVL=2 MARKSHARC_MODULE_GUARD=0 OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT"
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME"
    XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" )
}
# ms_run [VAR=value ...] zsh-args... ; stdout/stderr go to $TEST_ROOT/out and $TEST_ROOT/err
ms_run() {
  ms_env
  local -a extra=()
  while [[ $1 == [A-Za-z_]*=* ]]; do extra+=( "$1" ); shift; done
  env -i "${MS_ENV[@]}" "${extra[@]}" /bin/zsh "$@" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
}
# ms_pty [VAR=value ...] zsh-args... ; combined output in $TEST_ROOT/out
ms_pty() {
  ms_env
  local -a extra=()
  while [[ $1 == [A-Za-z_]*=* ]]; do extra+=( "$1" ); shift; done
  "$PYTHON" "$MARKSHARC_ROOT/tests/support/pty_socket.py" pty env -i "${MS_ENV[@]}" "${extra[@]}" /bin/zsh "$@" > "$TEST_ROOT/out" 2>&1
}
# ms_fixture_full: copy the whole public tree (core and modules) so a spec
# can patch files without touching the repository. The overlay is per-test.
ms_fixture_full() {
  MS_HOME="$TEST_ROOT/ms"; export MS_HOME
  mkdir -p "$MS_HOME"
  cp -R "$MARKSHARC_ROOT/core" "$MS_HOME/core"
  cp -R "$MARKSHARC_ROOT/modules" "$MS_HOME/modules"
  print -r -- "export MARKSHARC_HOME=\"$MS_HOME\"
source \"\$MARKSHARC_HOME/core/zsh/zshenv.zsh\"" > "$HOME/.zshenv"
}
# ms_unit [VAR=value ...] <script>: run <script> in zsh -f (no rc files) with the core
# libraries loaded from the repository, so a module file can be exercised directly with
# preset facts. Output goes to $TEST_ROOT/out and $TEST_ROOT/err.
ms_unit() {
  ms_env
  local -a extra=()
  while [[ $1 == [A-Za-z_][A-Za-z0-9_]#=[^[:space:]]# ]]; do extra+=( "$1" ); shift; done
  local pre='MARKSHARC_HOME="$MARKSHARC_ROOT"; _ms_verbose=0; MARKSHARC_SESSION=${MARKSHARC_SESSION:-batch}
for _l in util session facts cache modules; do source "$MARKSHARC_HOME/core/zsh/lib/$_l.zsh"; done
_ms_facts; _ms_env_rebuild=1; typeset -ga _ms_env_finalizers=()
'
  env -i "${MS_ENV[@]}" MARKSHARC_ROOT="$MARKSHARC_ROOT" "${extra[@]}" /bin/zsh -f -c "$pre$1" > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" < /dev/null
}
# ms_copy_module <name>...: copy real modules into the core fixture.
ms_copy_module() {
  local m
  for m in "$@"; do cp -R "$MARKSHARC_ROOT/modules/$m" "$MS_HOME/modules/$m"; done
}
# load_mfn <module> [fn...]: put a module's functions/zsh on fpath and autoload the named
# functions (every file when none are named), the way the module loader does; internal helpers
# resolve too.
load_mfn() {
  local dir="$MARKSHARC_ROOT/modules/$1/functions/zsh" fn
  shift
  fpath=( "$dir" ${fpath:#$dir} )
  (( $# )) || set -- "$dir"/*(N-.:t)
  for fn; do unfunction "$fn" 2>/dev/null; autoload -Uz "$fn"; done
}
# module_run <module> <zsh-code>: run code in a clean zsh -f child with the module's init.zsh
# available as $MOD_INIT and the module's functions on fpath. Output goes to $TEST_ROOT/out.
module_run() {
  local mod=$1 code=$2 moddir="$MARKSHARC_ROOT/modules/$1"
  env -i HOME="$HOME" PATH="$PATH" TERM=dumb OPLOG="$OPLOG" TEST_ROOT="$TEST_ROOT" MOD_DIR="$moddir" \
    XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
    /bin/zsh -f -c 'fpath=( "$MOD_DIR/functions/zsh"(N) $fpath ); autoload -Uz "$MOD_DIR"/functions/zsh/*(N:t); MOD_INIT=$MOD_DIR/init.zsh; '"$code" > "$TEST_ROOT/out" 2>&1 < /dev/null
}
```

- [ ] **Step 2: Source it conditionally from `tests/spec/spec_helper.sh`**

Full new content:

```sh
# shellcheck shell=sh
# Loaded by ShellSpec (see tests/.shellspec) from the tests directory.
# shellcheck source=tests/spec/support/fixtures.sh
. ./spec/support/fixtures.sh
# zsh-only core-loader helpers (not POSIX; only the zsh suites may see them).
if [ -n "${ZSH_VERSION:-}" ]; then
  # shellcheck source=tests/spec/support/core.sh
  . ./spec/support/core.sh
fi
spec_helper_configure() {
  before_each fixture_setup
  after_each fixture_teardown
}
```

- [ ] **Step 3: Verify the existing suites stay green**

Run: `tests/check`
Expected: lint ok, zsh suite (native, smoke) passes, repo suite passes. Nothing else changes yet.

- [ ] **Step 4: Commit**

```bash
git add tests/spec/support/core.sh tests/spec/spec_helper.sh
git commit -m "test(harness): zsh core-loader spec helpers for the moved suites

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 4: Move the core loader and its specs (TDD)

**Files:**
- Create: `core/zsh/{zshenv,zprofile,zshrc,zlogin,finalize,reload,phase}.zsh`, `core/zsh/lib/{util,session,facts,zdot,envid,modules,cache}.zsh` (copied, then adapted)
- Create: `tests/spec/zsh/core_{session,phases,modules,cache,reload,env,agent}_spec.sh` (copied, then adapted)
- Delete: `core/zsh/lib/.gitkeep`

- [ ] **Step 1: Copy the seven core specs and apply the mechanical adaptations**

```sh
src=/Users/mark/etc/mark-desktop-files/tests/shell/spec/zsh
for f in core_session core_phases core_modules core_cache core_reload core_env core_agent; do
  cp "$src/$f"_spec.sh "tests/spec/zsh/$f"_spec.sh
done
# Mechanical renames in the moved specs:
perl -pi -e 's/\Q$MDF_ROOT\E\/config\/zsh\/core/\$MARKSHARC_ROOT\/core\/zsh/g;
             s/\Q$MDF_ROOT\E\/config\/zsh\/modules/\$MARKSHARC_ROOT\/modules/g;
             s/\Q$MDF_ROOT\E\/tests\/shell/\$MARKSHARC_ROOT\/tests/g;
             s/\Q$MDF_ROOT\E/\$MARKSHARC_ROOT/g;
             s{\$MARKSHARC_HOME/core/(zshenv|zshrc|zprofile|zlogin|reload|phase|finalize)\.zsh}{\$MARKSHARC_HOME/core/zsh/$1.zsh}g;
             s{\$MS_HOME/core/lib/}{\$MS_HOME/core/zsh/lib/}g;
             s{\$MARKSHARC_HOME/core/lib/}{\$MARKSHARC_HOME/core/zsh/lib/}g;' tests/spec/zsh/core_*.sh
```

Hand edits after the mechanical pass:

- `core_session_spec.sh`: delete the `stub_case`/`'ships identical stubs with no hard-coded host paths'` example and the `missing_core_case`/`'reports a missing core with one error line and a safe PATH'` example (the shipped stub and its fallback arrive with the P2.4 installer; see Scope decisions).
- `core_env_spec.sh`:
  - `dname_case`: delete the `if [[ -d /opt/psa ]]; then want=plesk-phorn; else` branch and its `fi` pairing so `want` comes only from `domainname`/resolv.conf (the core has no site mappings in this repo).
  - Replace `plesk_case` with a neutral overlay-override case:

```zsh
  site_override_case() {
    emulate -L zsh
    # The portable core holds no site names; a private overlay module may set them.
    ms_fixture_full
    mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/site-demo"
    print 'describe "site demo"' > "$XDG_CONFIG_HOME/marksharc/modules/site-demo/module.conf"
    print 'dname=demo-site' > "$XDG_CONFIG_HOME/marksharc/modules/site-demo/env.zsh"
    ms_run -c 'print -r -- "$dname"' || return 1
    [[ $(<"$TEST_ROOT/out") == demo-site ]]
  }
  It 'lets a private overlay module own the site name, not the core'
    When run site_override_case
    The status should be success
  End
```

  (The old `! grep -riE 'plesk|phorn' … core` assertion is superseded by the Task 7 personal-value lint.)
- `core_agent_spec.sh`: no hand edits beyond the mechanical pass (`ms_fixture_full` no longer copies an overlay; the `print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"` line stays valid once modules exist — this spec runs after Task 5's module copy in the suite, but it must pass standalone too, so guard it: keep the line; the file is copied in Task 5, and `core_agent_spec` moves to Task 5's batch. **Decision: move `core_agent_spec.sh` to Task 5** because its fixture patches `modules/brew`.)

- [ ] **Step 2: Run the moved core specs and watch them fail**

Run: `tests/run-tests --shell zsh spec/zsh/core_session_spec.sh spec/zsh/core_phases_spec.sh spec/zsh/core_modules_spec.sh spec/zsh/core_cache_spec.sh spec/zsh/core_reload_spec.sh spec/zsh/core_env_spec.sh`
Expected: FAIL — examples error because `$MARKSHARC_ROOT/core/zsh` does not exist yet (`ms_fixture`'s `cp -R` fails / sourced files missing).

- [ ] **Step 3: Copy the core and apply the layout adaptation**

```sh
mkdir -p core/zsh
cp -R /Users/mark/etc/mark-desktop-files/config/zsh/core/ core/zsh/
rm -f core/zsh/lib/.gitkeep
```

Then edit exactly these lines:

`core/zsh/zshenv.zsh`:
- `MARKSHARC_HOME=${${(%):-%N}:A:h:h}` → `MARKSHARC_HOME=${${(%):-%N}:A:h:h:h}` (the file is one directory deeper)
- both `…$MARKSHARC_HOME/core/lib/$_ms_lib.zsh…` → `$MARKSHARC_HOME/core/zsh/lib/$_ms_lib.zsh`
- `source "$MARKSHARC_HOME/core/phase.zsh"` → `source "$MARKSHARC_HOME/core/zsh/phase.zsh"`
- `source "$MARKSHARC_HOME/core/finalize.zsh"` → `source "$MARKSHARC_HOME/core/zsh/finalize.zsh"`

`core/zsh/zshrc.zsh`:
- aliases: `"$MARKSHARC_HOME/core/reload.zsh"` ×2 → `"$MARKSHARC_HOME/core/zsh/reload.zsh"`
- `source "$MARKSHARC_HOME/core/phase.zsh"` → `core/zsh/phase.zsh`

`core/zsh/reload.zsh`: the four `core/{zshenv,zprofile,zshrc,zlogin}.zsh` references → `core/zsh/…`

`core/zsh/lib/zdot.zsh`:
- `typeset -g _ms_zdot_version=1` → `=2` (the generated stub text changes; any v1 zdot written against the source layout must regenerate)
- generated line: `[[ -r \${MARKSHARC_HOME-}/core/$name.zsh ]] && source \"\$MARKSHARC_HOME/core/$name.zsh\"` → `…/core/zsh/$name.zsh` in both places

`core/zsh/lib/envid.zsh`: no change — `"$MARKSHARC_HOME"/core/**/*` still covers `core/zsh`.

- [ ] **Step 4: Verify the moved core specs pass**

Run: `tests/run-tests --shell zsh spec/zsh/core_session_spec.sh spec/zsh/core_phases_spec.sh spec/zsh/core_modules_spec.sh spec/zsh/core_cache_spec.sh spec/zsh/core_reload_spec.sh spec/zsh/core_env_spec.sh`
Expected: all pass.

- [ ] **Step 5: Run the full local gate**

Run: `tests/check`
Expected: green (lint checks the new `.zsh` files with `zsh -n`).

- [ ] **Step 6: Commit**

```bash
git add core/zsh tests/spec/zsh/core_session_spec.sh tests/spec/zsh/core_phases_spec.sh tests/spec/zsh/core_modules_spec.sh tests/spec/zsh/core_cache_spec.sh tests/spec/zsh/core_reload_spec.sh tests/spec/zsh/core_env_spec.sh
git commit -m "feat(core): move the zsh core loader from mark-desktop-files

Session classes, env/init phases, module loader, tiered-PATH hooks, cached
tool init, generated ZDOTDIR and verbose reload, relocated from
config/zsh/core to core/zsh per spec 6.2.

Source: mark-desktop-files dcdb605a36bdf821b39eddd5f0bd2095bc7ec81d

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 5: Move the 26 P1.5 modules and their specs (TDD)

**Files:**
- Create: `modules/<name>/…` for the 26 modules listed in Scope decisions (copied verbatim — the earlier grep confirmed no `config/zsh`, `core/`-relative, or `MDF_` references in any of them)
- Create: `tests/spec/zsh/{core_agent,startup,path,manager_paths,environment,tools,ps,omz_removal,history,overlay,modules,module_specs}_spec.sh` (copied, then adapted)
- Delete: `modules/.gitkeep`

- [ ] **Step 1: Copy the twelve spec files and apply mechanical adaptations**

```sh
src=/Users/mark/etc/mark-desktop-files/tests/shell/spec/zsh
for f in core_agent startup path manager_paths environment tools ps omz_removal history overlay modules module_specs; do
  cp "$src/$f"_spec.sh "tests/spec/zsh/$f"_spec.sh
done
perl -pi -e '…same five rules as Task 4…' tests/spec/zsh/{core_agent,startup,path,manager_paths,environment,tools,ps,omz_removal,history,overlay,modules,module_specs}_spec.sh
```

Hand edits after the mechanical pass:

- `startup_spec.sh`:
  - `startup_tools`: delete the `herdr` and `cwf` stubs and the `mkdir -p "$HOME/.config/envman"` + `envman/load.sh` lines (P1.6/private modules are not here).
  - `startup_case`: in the tty-mode event loop, delete `ENVMAN HERDR_COMPLETION CWF_INIT` from the event list so it reads `for event in COMPINIT`.
  - `quiet_case`: replace `'marksharc: module mark-tools: init.zsh'` with `'marksharc: module pager: init.zsh'`.
  - `maintenance_case`: keep only the `install-gvm` iteration — replace the loop with a single `load_mfn go-gvm` + `install-gvm` failure-propagation check; delete the `install-wezterm-terminfo` and `install-krew` cases (their modules arrive in P2.3/L1).
  - `offline_startup_case`: delete the `print … > "$MS_HOME/zsh.plugins"` line (the registry is the module's own `modules/completion-fzf-tab/zsh.plugins`, already copied).
- `history_spec.sh`:
  - `ordering_case`: delete the `titles` lines (`cd .` grep and `o_t` comparison); keep the atuin-init-before-policy assertion and the `o_s < o_a` order check. Leave a comment: `# titles (order 90) re-asserts its cd . kick here when P2.3 lands it.`
  - `history_session`: delete the `cwf` and `herdr` stub lines (modules absent); keep the `go`, `fortune`, `git`, `zoxide`, `starship`, `atuin` stubs.
- `omz_removal_spec.sh`:
  - `no_live_omz_references_case`: change the `git grep` pathspec to `-- core modules` (drop `etc/links etc/oh-my-zsh etc/zsh_plugins.txt`, which never existed here).
  - `cloud_startup_removal_case`: delete the `herdr cwf` stubs from the tool loop.
- `overlay_spec.sh`: delete `private_layout_case` (author's private overlay) and `disabled_hook_case` (`cwf` module hook); both return with P2.3/private-overlay work. Everything else synthesizes its own overlay already.
- `modules_spec.sh`:
  - `band_case`: keep the band table verbatim (names not yet present simply never match; the bands are spec 6.4).
  - `layout_case`: rewrite for this repo's layout:

```zsh
  layout_case() {
    emulate -L zsh
    # The public tree holds the core and the module directories, nothing else.
    local -a found=( "$MARKSHARC_ROOT"/modules/*(N:t) )
    (( $#found > 0 )) || { print 'no modules'; return 1; }
    [[ -r $MARKSHARC_ROOT/core/zsh/zshenv.zsh && -d $MARKSHARC_ROOT/core/zsh/lib ]] || return 2
    [[ ! -e $MARKSHARC_ROOT/modules/legacy ]] || return 3
  }
```

- `module_specs_spec.sh`:
  - `links_case`: adapt to this repo — iterate `"$MARKSHARC_ROOT"/modules/*/tests(N/)` and require a link from `tests/spec/zsh/modules/<name>` (vacuously true today; keeps spec 6.4's rule for when module-local tests appear).
  - `contract_case`: scan `"$MARKSHARC_ROOT"/modules/*/module.conf(N)` only; delete the `*/marksharc/modules/*` private-band branch (private modules never live in this repo).

- [ ] **Step 2: Run the moved specs and watch them fail**

Run: `tests/run-tests --shell zsh spec/zsh/path_spec.sh spec/zsh/ps_spec.sh spec/zsh/tools_spec.sh`
Expected: FAIL — `$MARKSHARC_ROOT/modules/<name>` do not exist.

- [ ] **Step 3: Copy the 26 modules verbatim**

```sh
src=/Users/mark/etc/mark-desktop-files/config/zsh/modules
for m in path brew zsh-options editor pager ls ps nav zoxide completion completion-fzf-tab command-not-found history-atuin history-native prompt-starship node-nvm go-gvm python bun pnpm rust go lmstudio cuda direnv greeting; do
  cp -R "$src/$m" "modules/$m"
done
rm -f modules/.gitkeep
```

Verify no out-of-batch module leaked: `ls modules | sort` must equal exactly the 26 names. Verify no private strings: `grep -rnE 'markfrommn|convoy|plesk|phorn|/Users/mark|/data/work' modules core` must print nothing.

- [ ] **Step 4: Run the moved module specs to green**

Run: `tests/run-tests --shell zsh spec/zsh`
Expected: the whole zsh suite passes (native, smoke, core_*, startup, path, manager_paths, environment, tools, ps, omz_removal, history, overlay, modules, module_specs).

- [ ] **Step 5: Fix any Linux-incompatible failures found by inspection**

Known risk points to review before declaring done (the local Mac cannot prove Linux):
- `core_env_spec` `dname_case` handles a missing `domainname` command (already written defensively — verify the `want=` fallback still works when neither `domainname` nor a resolv.conf search line exists).
- `ps_spec` uses stubbed `ps` output only — portable.
- `/bin/zsh` must exist on ubuntu-latest (usrmerge: yes).
- `file_mode`/PTY helpers are already dual-platform.
Any change here is a behaviour fix and needs its own spec adjustment note in the commit.

- [ ] **Step 6: Run the full local gate**

Run: `tests/check`
Expected: green.

- [ ] **Step 7: Commit**

```bash
git add modules tests/spec/zsh
git commit -m "feat(modules): move the P1.5 environment and tool modules

The 26 environment and tool modules with their specs: path, brew,
zsh-options, editor, pager, ls, ps, nav, zoxide, completion,
completion-fzf-tab, command-not-found, history-atuin, history-native,
prompt-starship, node-nvm, go-gvm, python, bun, pnpm, rust, go, lmstudio,
cuda, direnv, greeting. P1.6 system/workflow modules and the private
overlay stay behind for P2.3.

Source: mark-desktop-files dcdb605a36bdf821b39eddd5f0bd2095bc7ec81d

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 6: Cross-shell contract suite and CI wiring (TDD)

Spec 8 requires a ShellSpec suite hosted by POSIX `sh` that launches the shells. This unit adds the zsh half, structured so bash/fish Describes join later. It launches the **real** tree via `MARKSHARC_ROOT` (that is the contract being proved), in the sandboxed fixture HOME.

**Files:**
- Create: `tests/spec/contract/zsh_spec.sh`
- Modify: `tests/check`, `.github/workflows/ci.yml`, `tests/README.md`

- [ ] **Step 1: Write the contract suite**

`tests/spec/contract/zsh_spec.sh`:

```sh
# Cross-shell startup contract (spec 8), launched from POSIX sh. Today only the
# zsh core exists; the bash (P3.2) and fish (P4.1) phases add their own
# Describes here, launching core/bash and core/fish the same way.
Describe 'cross-shell contract: zsh core'
  # The suite drives the real tree: MARKSHARC_HOME is this checkout.
  zshenv_stub() {
    printf '%s\n' "export MARKSHARC_HOME=\"$MARKSHARC_ROOT\"" \
      'source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"' > "$HOME/.zshenv"
  }
  # zsh_child [VAR=value ...] <flags> <command>: hermetic child under the fixture HOME.
  zsh_child() {
    env -i HOME="$HOME" PATH="$PATH" TERM=dumb \
      XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
      XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" \
      OPLOG="$OPLOG" "$@" zsh -f
  }
  ...
```

(The executor writes the full file; the required examples and their assertions are exactly:)

1. **`batch, login and non-tty interactive shells are silent and see the same environment`** — write the stub; for each of `-c`, `-lc`, `-ic`: run `env -i HOME PATH TERM XDG_* zsh $flags 'print -r -- "$MARKSHARC_ENV|$MARKSHARC_SESSION|$MARKSHARC_HOME"'` with stdout→`$TEST_ROOT/out`, stderr→`$TEST_ROOT/err`; assert status 0, `err` empty, output matches `1.$MARKSHARC_OS-pattern|batch|$MARKSHARC_ROOT` (capture `MARKSHARC_OS` dynamically or just assert the `|batch|$MARKSHARC_ROOT` suffix and non-empty id), and the `MARKSHARC_ENV` value is identical across the three runs.
2. **`agent markers keep every mode silent`** — for markers `CLAUDECODE=1` and `AI_AGENT=claude`, for flags `-c` and `-ic`: assert status 0, empty stderr, and the printed session is `agent`.
3. **`re-sourcing the env phase changes nothing`** — `zsh -c 'local before=$PATH; source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"; [[ $PATH == $before ]] && print steady'`; assert output is `steady` and stderr empty.
4. **`startup writes only inside the cache and state directories`** — `touch "$TEST_ROOT/stamp"`, sleep 1, run the three modes (`-c`, `-lc`, `-ic`); assert `find "$MARKSHARC_ROOT" -newer "$TEST_ROOT/stamp" -not -path '*/.git/*' -not -name .git` prints nothing; assert every regular file under `$HOME` is `$HOME/.zshenv` or under `$HOME/config`, `$HOME/cache`, `$HOME/data`, or `$HOME/state`; assert `$XDG_STATE_HOME/marksharc/zdot/.zshrc` exists after the login/interactive runs.

- [ ] **Step 2: Prove the suite can fail (mutation check), then passes**

Run once with the stub pointing at an empty directory (`export MARKSHARC_HOME="$TEST_ROOT/empty"`) in a scratch copy of the suite — expect the silent-startup examples to fail (the stub's source line fails / no `MARKSHARC_ENV`). Then run the real thing:

Run: `tests/run-tests --shell sh spec/contract`
Expected: all examples pass.

- [ ] **Step 3: Wire the suite into `tests/check` and CI**

`tests/check` — insert between the zsh and repo suites:

```sh
"$here/run-tests" --shell sh spec/contract
```

`.github/workflows/ci.yml` — insert after the `zsh suite` step:

```yaml
      - name: Contract suite
        run: tests/run-tests --shell sh spec/contract
```

`tests/README.md` — add a `spec/contract/` row to the layout table ("Contract suite run with `--shell sh`: launches the real zsh core (bash and fish join in their phases) and proves quiet startup, environment availability, idempotent re-source and writes confined to cache/state") and the run line `tests/run-tests --shell sh spec/contract`.

- [ ] **Step 4: Run the full local gate**

Run: `tests/check`
Expected: green, including the new contract suite.

- [ ] **Step 5: Commit**

```bash
git add tests/spec/contract tests/check .github/workflows/ci.yml tests/README.md
git commit -m "test(contract): cross-shell startup contract suite, wired into CI

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 7: Personal-value lint for the portable tree

P1.7's lint must pass in the public repo (AC 6). The checker and its spec move with the paths pointed at this repo's portable surface.

**Files:**
- Create: `tests/support/personal-values-check.py`, `tests/spec/zsh/personal_values_spec.sh`

- [ ] **Step 1: Copy the checker and adapt its scanned roots**

`tests/support/personal-values-check.py`: copy from the source, then change:

```python
paths = [root / "core", root / "modules", root / ".zshenv.mac", root / ".zshenv.linux"]
```

to:

```python
paths = [root / "core", root / "modules", root / "templates"]
```

(The `~/.zshenv` stub ships with the installer in P2.4 and joins the list then.)

- [ ] **Step 2: Copy the spec and adapt**

`personal_values_spec.sh`: mechanical rename pass; `real_case` becomes:

```zsh
  real_case() { "$PYTHON" "$MARKSHARC_ROOT/tests/support/personal-values-check.py" "$MARKSHARC_ROOT"; }
```

The `lint_case` fixture tree is unchanged (it builds its own candidate tree with `core/`, `modules/`).

- [ ] **Step 3: Run the spec**

Run: `tests/run-tests --shell zsh spec/zsh/personal_values_spec.sh`
Expected: both examples pass.

- [ ] **Step 4: Commit**

```bash
git add tests/support/personal-values-check.py tests/spec/zsh/personal_values_spec.sh
git commit -m "test(hygiene): personal-value lint over the portable tree

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 8: CHANGELOG and the contract inventory

**Files:**
- Modify: `CHANGELOG.md`, `tests/README.md`

- [ ] **Step 1: Add CHANGELOG entries under `## [Unreleased]` → `### Added`**

```markdown
- Zsh core loader (`core/zsh/`): session classes, env/init phases, module
  loader, tiered PATH builder hooks, cached tool init, generated ZDOTDIR,
  verbose reload (`cs`/`li`).
- The 26 environment and tool modules (`modules/`): path, brew, zsh-options,
  editor, pager, ls, ps, nav, zoxide, completion, completion-fzf-tab,
  command-not-found, history-atuin, history-native, prompt-starship,
  node-nvm, go-gvm, python, bun, pnpm, rust, go, lmstudio, cuda, direnv,
  greeting.
- Cross-shell contract suite (`tests/spec/contract/`), run in CI on macOS and
  Ubuntu.
- Personal-value lint over the portable tree.
```

- [ ] **Step 2: Extend the contract inventory in `tests/README.md`**

Add one row per moved spec to the inventory table:

| Area | Behaviour | Spec |
| --- | --- | --- |
| Core | Session classes; silent batch/agent startup; marker override; PTY interactive | `spec/zsh/core_session_spec.sh` |
| Core | Env/init phase ordering through generated ZDOTDIR; MARKSHARC_ENV inherit-skip; zprofile PATH re-assert | `spec/zsh/core_phases_spec.sh` |
| Core | Module discovery, order, requires, options, fpath, idempotency, failure containment, guard cache | `spec/zsh/core_modules_spec.sh` |
| Core | Cached tool init: hit/miss keys, symlink resolution, missing/failing tools, unwritable cache, empty output, fixed PATH | `spec/zsh/core_cache_spec.sh` |
| Core | `cs`/`li` reload: rebuild, trace, session kept, edit pickup | `spec/zsh/core_reload_spec.sh` |
| Core | Host facts, dname, exports, ZDOTDIR generation and read-only fallback, no repo writes, umask cache | `spec/zsh/core_env_spec.sh` |
| Core | Agent/batch quiet on the full tree; gvm selection without forks | `spec/zsh/core_agent_spec.sh` |
| Startup | Mode matrix quiet/reload; greeting opt-in; offline pinned plugin and cached completion; cached init reuse; installer failure propagation | `spec/zsh/startup_spec.sh` |
| path | Tier order goldens (macOS/Linux/modules), placement, reload, dot rule, spaces, tiers option, pending commands, env finalizers, requires-after-brew | `spec/zsh/path_spec.sh` |
| node-nvm, go-gvm, python | Manager tier ahead of brew in every class; nvm alias resolution; gvm selection and GOROOT; hooks; pyenv vs uv | `spec/zsh/manager_paths_spec.sh` |
| brew, core libs | setup-homebrew variants; host-fact seams | `spec/zsh/environment_spec.sh` |
| Tool modules | brew/go/rust/bun/pnpm/lmstudio/cuda env placement; ls/pager/zsh-options/nav/zoxide/starship/direnv/greeting/completion init | `spec/zsh/tools_spec.sh` |
| ps | Seven helpers, header kept, self-match excluded, portable flags | `spec/zsh/ps_spec.sh` |
| OMZ keepers | No OMZ references; no cloud startup; plugin loader kinds, pins, update, no-eval; nav widgets; coloured man; command-not-found | `spec/zsh/omz_removal_spec.sh` |
| history-atuin, history-native | Wrapper over atuin, policy, native fallback, no stray history files | `spec/zsh/history_spec.sh` |
| Overlay | Private module root, host config, env-id invalidation, reload paths, function ownership, post hook, option restore | `spec/zsh/overlay_spec.sh` |
| Modules | Bands, double-source idempotency, layout, interactive load | `spec/zsh/modules_spec.sh` |
| Modules | module.conf contract; module tests linkage | `spec/zsh/module_specs_spec.sh` |
| Hygiene | Personal-value lint over the portable tree | `spec/zsh/personal_values_spec.sh` |
| Contract | Quiet batch/agent startup, same environment in every zsh mode, idempotent re-source, writes confined to cache/state | `spec/contract/zsh_spec.sh` |

- [ ] **Step 3: Commit**

```bash
git add CHANGELOG.md tests/README.md
git commit -m "docs: changelog and test inventory for the core and module move

Co-Authored-By: Claude <noreply@anthropic.com>"
```

---

### Task 9: Runtime verification on the Mac (AC 4) and final gates

**Files:** none (verification only).

- [ ] **Step 1: Safe direct startup check against this worktree**

In an isolated HOME (never the real one, never `/data/work/mark/marksharc`):

```sh
tmp=$(mktemp -d /tmp/marksharc-ac4.XXXXXX)
mkdir -p "$tmp/config" "$tmp/cache" "$tmp/data" "$tmp/state"
printf 'export MARKSHARC_HOME="%s"\nsource "$MARKSHARC_HOME/core/zsh/zshenv.zsh"\n' \
  "$PWD" > "$tmp/.zshenv"
env -i HOME="$tmp" PATH=/usr/bin:/bin:/usr/sbin:/sbin TERM=dumb \
  XDG_CONFIG_HOME="$tmp/config" XDG_CACHE_HOME="$tmp/cache" \
  XDG_DATA_HOME="$tmp/data" XDG_STATE_HOME="$tmp/state" \
  /bin/zsh -c 'print -r -- "session=$MARKSHARC_SESSION env=${MARKSHARC_ENV:+set}"; print -r -- $MARKSHARC_HOME'
```

Expected: `batch env=set`, the worktree path, no other output.

- [ ] **Step 2: Verbose evidence that the environment/tool modules load**

Same environment plus `MARKSHARC_VERBOSE=1`, capture stderr:

```sh
env -i … MARKSHARC_VERBOSE=1 /bin/zsh -c ':' 2> "$tmp/trace"
grep -c '^marksharc: module ' "$tmp/trace"
```

Expected: trace lines for the env phase of path, brew, node-nvm, go-gvm, python, bun, pnpm, rust, go, lmstudio, cuda (skips with reasons where a tool is absent). Interactive init evidence: run under the PTY helper with stubbed `starship`/`atuin`/`zoxide` (stubs first on PATH in the child's env), assert `READY` prints and the trace shows the init-phase modules (zsh-options, editor, pager, ls, ps, nav, completion, …, greeting skipped).

- [ ] **Step 3: Prove no runtime repo writes**

Run: `git status --porcelain` before and after Steps 1–2.
Expected: unchanged (all writes land in `$tmp`).

- [ ] **Step 4: The literal path check**

`ls -ld /data/work/mark/marksharc` — if it does not resolve to this worktree, record AC 4's literal-path form as **pending** (per the packet: verify against this worktree, report the literal path as pending).

- [ ] **Step 5: Full gates and stack conformance**

Run: `tests/check`; then every CI step the gate does not cover (none beyond it after Task 6 — CI is lint + zsh + contract + repo suites); then invoke the `stack-check` skill with `origin/main...HEAD` and confirm no must-fix findings.

## Self-Review Notes (completed during planning)

- **Spec coverage:** P2.2 scope items map to Tasks 1 (docs refresh), 3–5 (core + modules + moved specs), 6 (contract suite + CI), 7 (personal-value lint), 8 (CHANGELOG), 9 (runtime AC 4). "Fix what the first Linux CI run exposes" is covered by Task 5 Step 5's review plus CI wiring; genuinely unverifiable Linux behaviour is reported as a platform gap.
- **Placeholder scan:** Task 6 Step 1 gives the suite skeleton plus the exact assertions; the executor writes the file — acceptable because the assertions are enumerated exhaustively.
- **Type/name consistency:** helper names (`ms_*`, `load_mfn`, `module_run`) match the source specs verbatim; `MARKSHARC_ROOT` matches the existing harness; the `core/zsh/` prefix is applied uniformly by rule 5.
