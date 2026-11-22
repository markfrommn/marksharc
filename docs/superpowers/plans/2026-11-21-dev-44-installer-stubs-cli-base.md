# DEV-44 (P2.4) — Installer, stubs, and CLI base — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give marksharc its Day 0 path (`install.sh`, the `~/.zshenv` stub with a safe fallback, the template overlay) and the `marksharc` command (`reload`, `module list|enable|disable`, `uninstall`, `version`), proven in a temporary HOME and in a CI end-to-end job.

**Architecture:** `install.sh` (POSIX sh) resolves the framework checkout (`--home`, else its own checkout, else a clone), wires the overlay, moves the HOME zsh dotfiles into a timestamped backup under the state dir, writes the stub and an install manifest. The stub sets `MARKSHARC_HOME` and sources `core/zsh/zshenv.zsh`; on any load failure it sets a minimal PATH and prints one stderr line. `bin/marksharc` is a thin zsh dispatcher to executable zsh scripts in `core/cli/` (spec 6.2, 6.11). `marksharc reload` must act on the current shell, so the init phase defines a `marksharc` function that handles `reload` and delegates the rest to `bin/marksharc`.

**Tech stack:** POSIX sh (installer, e2e script), zsh 5.9+ (CLI, stub), ShellSpec 0.28.1 (pinned), shellcheck, GitHub Actions (macos-latest, ubuntu-latest).

**Spec:** [specs/MARKSHARC-SPEC.md](../../specs/MARKSHARC-SPEC.md) sections 6.1, 6.2, 6.3, 6.5, 6.6, 6.10, 6.15, 10, 11; [specs/MARKSHARC-PLAN.md](../../specs/MARKSHARC-PLAN.md) P2.4 and the global constraints.

## Global Constraints

- macOS and Linux are both supported. Shell startup is quiet, offline and installs nothing; batch and agent sessions print nothing (the load-failure fallback line is the one deliberate exception, stderr only).
- The framework checkout is never written at run time. `install.sh` writes only HOME, the XDG config, data (clone only), state and cache locations it is told about.
- Portable code (`core/`, `modules/`, `templates/`) holds no personal values; keep `bin/` clean too. The public repository URL lives only in `install.sh` and the README (project identity).
- No new dependency or toolchain change: sh, zsh, git, ShellSpec, shellcheck and python3 only.
- Tests use a temporary HOME and command stubs, never the real HOME or the network (the clone path uses a local bare repository).
- Scope stops at P2.4: no `render`, `sync`, `doctor`, `bootstrap`, `update`, fish or bash wiring.
- Conventional Commit subjects; every commit ends with `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Operator decisions (binding)

1. Framework source: `--home` wins; else the installer's own checkout (its directory holds `core/zsh/zshenv.zsh`); else clone `${MARKSHARC_REPO:-https://github.com/markfrommn/marksharc.git}` into `${XDG_DATA_HOME:-~/.local/share}/marksharc`, reusing an existing clone without pulling.
2. Existing `~/.zshenv ~/.zshrc ~/.zprofile ~/.zlogin ~/.zlogout` are moved to `${XDG_STATE_HOME:-~/.local/state}/marksharc/backup/<stamp>/`, with a manifest; symlinks are recorded by target and restored as symlinks; a re-run on our own stub makes no new backup.
3. `marksharc uninstall` restores from the manifest, removes the stub and the generated ZDOTDIR, keeps framework, overlay and cache, and prints how to remove the rest. `--purge` also deletes the cache and state dirs and an installer-made clone (never a `--home` checkout, never the overlay), after a confirmation (`--yes` for non-interactive use). Everything is validated before the first deletion.
4. The load-failure line is printed in every session class, to stderr only.
5. The template overlay has no active `module` lines, one commented `# module <name> off` line per public module, and commented `set` examples.
6. `--overlay` path: symlink at the config dir; URL: git clone there; no flag: copy the template only when nothing exists. An existing overlay is never modified; a conflicting existing overlay is an error before any write.
7. Never `chsh`; print the hint when the login shell is not zsh.
8. Done-when: temp-HOME specs plus a CI job (macOS and Ubuntu) running `tests/e2e/install-e2e.sh`.

## Defaults chosen here

- `marksharc` function (init phase, `core/zsh/zshrc.zsh`): `reload [--verbose|-v]` sources `core/zsh/reload.zsh` in the current shell (quiet unless verbose, `cs`/`li` stay verbose); every other subcommand runs `$MARKSHARC_HOME/bin/marksharc`. `bin/marksharc reload` run directly explains it needs a marksharc shell and exits 1.
- `bin/` reaches PATH in every session class through the `user` tier of the path module (`_ms_path_contribute`); the fallback PATH of the stub also lists it.
- `version`: root `VERSION` file plus `git describe --tags --always --dirty` when the framework is a git checkout.
- Manifest: line-oriented `key=value` (`file=<name>`, `link=<name>=<target>`), readable by POSIX sh and zsh, paths with spaces survive. Canonical file `${XDG_STATE_HOME:-~/.local/state}/marksharc/install.manifest`.
- `module enable|disable` edit the overlay `config.conf` line by line. In non-explicit mode (no active `module <name>` line) `enable` only un-switches an off line and never adds a `module <name>` line (that would flip the loader to explicit-list mode); `disable` of the last explicit module is refused for the same reason.
- `local/pre.zsh` is not shipped in the template: no phase sources it yet (only `local/post.zsh` is consumed by `core/zsh/zshrc.zsh`).
- The stub's fallback reports a failed load with one line of its own; any diagnostic zsh prints for a syntax error inside the core is not suppressed (it would also hide interactive module diagnostics). The stub wraps the `source` in a `{ } always { }` block, because a parse error in a sourced file aborts an enclosing `if`/`else` before the else branch can run.
- `marksharc uninstall` renames the manifest to `install.manifest.restored` after a default uninstall (a second run reports nothing to uninstall; the backup directory stays until `--purge`); the purge targets are validated against the manifest (basename `marksharc`, never inside the overlay).
- `tests/support/pty_socket.py` gains an optional `PTY_INPUT` so a spec can answer the `--purge` prompt on a terminal.
- `module list` reads the loader's tables through `_ms_discover_all` (disabled modules stay in, flagged in `_ms_mod_enabled`); the CLI computes only the two facts it needs (OS, host) so that listing never writes the fact cache.

---

### Task 1: Commit this plan

- [ ] Commit `docs/superpowers/plans/2026-11-21-dev-44-installer-stubs-cli-base.md` (`docs(plan): ...`).

### Task 2: Template overlay (TDD)

**Files:** Delete `templates/overlay/.gitkeep`; create `templates/overlay/{README.md,config.conf,hosts/.gitkeep,local/post.zsh}`; create `tests/spec/zsh/template_overlay_spec.sh`.

- [ ] Spec: config.conf has no active `module` line; lists `# module <name> off` for exactly the modules in `modules/`; loads through `_ms_config_load` as non-explicit with nothing disabled; every commented `set` example names a real option; the template loads in a real tree quietly.
- [ ] Watch it fail; write the template; green.

### Task 3: Core hooks (TDD)

**Files:** `core/zsh/zshrc.zsh` (`marksharc` function), `core/zsh/reload.zsh` (quiet reload), `modules/path/env.zsh` (bin on PATH), `VERSION`; spec `tests/spec/zsh/core_cli_spec.sh` (reload function part).

- [ ] Specs: the `marksharc` function exists only in interactive sessions; `marksharc reload` re-runs env and init in the current shell without a trace, `--verbose` traces like `cs`; other subcommands delegate; `bin` is on PATH in batch, agent and interactive classes; the path goldens still hold.
- [ ] Implement; green.

### Task 4: CLI base (TDD)

**Files:** `bin/marksharc`, `core/cli/{version,reload,module,uninstall}` (executable zsh), small loader refactor in `core/zsh/lib/modules.zsh` so `module list` sees disabled modules (`_ms_discover_all`); specs in `tests/spec/zsh/core_cli_spec.sh`.

- [ ] Specs: usage and unknown command; `version` output and git describe; `reload` direct explanation; `module list` statuses (enabled, disabled, skipped by requires), private overlay module; `enable`/`disable` (template comment lines, explicit mode, last-explicit refusal, unknown name, missing overlay, idempotence, host override warning, symlinked config.conf, no overlay modification outside config.conf).
- [ ] Implement; green.

### Task 5: install.sh (TDD)

**Files:** `install.sh`; specs `tests/spec/install/installer_spec.sh`.

- [ ] Specs (sh suite, temporary HOME): preconditions (zsh and git missing, old zsh) fail before any write; fresh install (stub, manifest, template overlay, hint when SHELL is not zsh); existing regular and symlinked dotfiles backed up and removed; foreign `~/.zshenv` backed up; idempotent re-run (no new backup, backup intact, stub rewrite when home changes); `--dry-run` writes nothing and prints the plan; `--overlay` path, URL (local bare repo) and conflict; clone path with a local bare repository and reuse; `--home` invalid; spaces in paths; unknown option.
- [ ] Implement; green. shellcheck clean (spec).

### Task 6: Uninstall and load-failure fallback (TDD)

**Files:** `core/cli/uninstall`; specs `tests/spec/install/uninstall_spec.sh`, `tests/spec/zsh/fallback_spec.sh`.

- [ ] Specs: restore (files and symlinks), stub and zdot removed, overlay/framework/cache kept, instructions printed; conflicts and missing backup files fail before any change; `--purge` needs `--yes` or a tty, deletes cache, state and an installer clone, never a `--home` checkout or the overlay; install, uninstall, install round trip. Fallback: missing and unreadable core, failing core, PATH reset, exactly one stderr line, stdout empty, batch and interactive (PTY).
- [ ] Implement; green.

### Task 7: End-to-end script and CI

**Files:** `tests/e2e/install-e2e.sh`, `tests/spec/install/e2e_spec.sh`, `.github/workflows/ci.yml` (job `install-e2e`), `tests/check`.

- [ ] `tests/e2e/install-e2e.sh <checkout>`: fresh HOME, `install.sh --home`, then login zsh and interactive zsh start without stderr, `MARKSHARC_SESSION` set, `marksharc` resolves; optional PTY interactive check when python3 exists; `marksharc version`; uninstall; stub gone.
- [ ] Wire `spec/install` into `tests/check` and CI; add the job on both OSes.

### Task 8: Docs, inventory, changelog, gates

- [ ] README: replace the status note with the Day 0 commands (`curl | sh` and clone-first). CHANGELOG line. `tests/README.md` inventory rows and layout row. `docs/DEVELOPING.md` mention of the e2e script.
- [ ] Gates: `tests/check`; the e2e script directly; `stack-check` with `origin/main...HEAD`.

## Review fixes (second pass)

- A re-run on a missing or replaced stub with backups recorded in the manifest stops before any write (the manifest would otherwise lose the backups); the message names the backup and the uninstall command. Specs: `tests/spec/install/rerun_spec.sh`.
- The manifest records a stub fingerprint (`stub_sum`, `cksum`). A stub that differs from it was edited: install keeps a copy in `$STATE/marksharc/replaced/`, uninstall writes `~/.zshenv.marksharc-removed`; both print the path.
- `MARKSHARC_CONFIG` is written to the stub unless the overlay is `~/.config/marksharc` (judged against `$HOME`, not `$XDG_CONFIG_HOME`); non-default `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `XDG_DATA_HOME` produce a warning because the stub cannot carry them; uninstall names `XDG_STATE_HOME` when it finds no manifest. Trailing slashes of `MARKSHARC_CONFIG` are stripped.
- `bin/marksharc` runs the CLI programs with `zsh -f` and the programs derive `MARKSHARC_HOME` from their own path, so a checkout never acts on the one the stub names.
- `tests/e2e/install-e2e.sh` runs the `--home` pass and the piped, cloning pass (README `curl | sh` path).
- Reload: `marksharc reload` stays the in-shell function (spec 6.10); module code is made function-safe. Every file-scope declaration in module `env.zsh`/`init.zsh` now says `-g`; `tests/support/function-safe-check.py` (modules, core, overlay hooks) and `tests/spec/zsh/function_safe_spec.sh` enforce it, plus a PTY spec comparing `marksharc reload` with `cs`. Rule documented in spec 6.4, `templates/overlay/local/post.zsh` and the overlay README. `core/zsh/zshenv.zsh` ends with `true`. The `reload` explainer no longer suggests `cs`/`li`.

Known limitations (left as they are): clone provenance is lost after uninstall plus reinstall (the clone is then treated as pre-existing, the safe direction); an install interrupted between the manifest write and the dotfile removal leaves HOME files that uninstall reports as conflicts; disabling the path module removes `bin/` from PATH; a parse error in a core lib file does not trigger the stub fallback.

## Review fixes (third pass)

- `marksharc reload` spec made discriminating: markers are planted in module scratch variables and PS1 is exported before each reload path (`marksharc reload`, `--verbose`, `cs`); none may survive. Confirmed to fail against the pre-`-g` modules (`marksharc reload: marker left behind`).
- `function-safe-check.py` now handles here-strings, same-line and multi-line case arms, `builtin`/`command`/`exec` prefixes, and no longer flags `function { ... }` or `function name() { ... }`.
- `uninstall --purge` moves edited-stub copies from the state dir to `~/.zshenv.marksharc-replaced.<stamp>` before deleting it.
- Spec 6.4 records that cached third-party tool init output is also sourced inside the function on reload (a known limitation).
- Further known limitations: a generated ZDOTDIR is left behind when uninstall runs with a different `XDG_STATE_HOME` than new shells used; an "edited stub" copy is saved spuriously when the state directory was deleted (the stub fingerprint is gone).
