# Bash environment parity implementation plan

> Execute this unit through `$phase DEV-50` with the `common-developer` agent and the normal phase reviews.

**Goal** — Give Bash and Bash-based agents the same PATH and tool exports as zsh, with silent startup.

**Architecture** — Extend the existing renderer with a native Bash emitter driven by the same module order, directives, guards, and overlay precedence. The installed Bash startup files source a small loader that consumes the per-host Bash cache. Use Bash built-ins on warm startup and keep the existing renderer responsible for explicitly generated artifacts.

**Stack** — Existing zsh renderer, POSIX installer, native Bash, and ShellSpec 0.28.1. Exercise `/bin/bash` explicitly on Linux and macOS because it is the requested agent shell path.

**Authority** — [P3.2](../../../specs/MARKSHARC-PLAN.md#p32--bash-environment-parity-dev-50) and [MarkSharc Specification](../../../specs/MARKSHARC-SPEC.md) sections 4.2, 6.2, 6.5–6.7, 6.10, 7.1, 8, and 10.

**Precondition** — P3.1 is merged in PR #7 and DEV-49 is Done. The operator confirmed the live before-and-after PATH and environment comparison on Mac and sol. The operator approved skipping real `herdr completion zsh` verification.

## Constraints

- Test under temporary HOME and XDG directories using command stubs. Keep stdout and stderr separate, and keep runtime writes inside cache and state.
- Preserve directives as data, including spaces, literal quotes, and shell metacharacters. Keep command, file, and directory guards live, with OS and host guards resolved at render time.
- Preserve underlying PATH order, inheritance, deduplication, and manager precedence. Bash stays in the env phase, including when invoked with a terminal.
- `agent.bash_env` defaults off. The documented `bash -c` path uses either a configured `BASH_ENV` or a parent that already exports the environment. Bash does not read `.bashrc` on an ordinary noninteractive, nonlogin invocation.

## 1. Render and load the Bash environment

Touch `core/zsh/lib/render.zsh`, `core/zsh/lib/rendered.zsh`, and `modules/agent/module.conf`. Add `core/bash/env.bash`, `core/bash/bashrc.bash`, and `tests/spec/contract/bash_spec.sh`. Use `tests/spec/zsh/render_spec.sh` for renderer-specific checks.

- [ ] Write a renderer test for `env.bash` beside `env.zsh`. Check Bash syntax, identical content across repeated renders of unchanged inputs, literal hostile values, and recovery when the Bash artifact is missing. Cover a guard that becomes true after render without rerunning a generator.
- [ ] Write a cross-shell contract test using the same initial PATH and overlay. Compare PATH, the render ID, host facts, and representative tool exports with `zsh -c` and `zsh -lc`. Cover inherited `bash -c`, isolated `bash -c` with the managed hook, and `bash -lc`. Assert empty startup stdout and stderr for batch, Claude Code, and Codex marker variants.
- [ ] Run `tests/run-tests --shell zsh spec/zsh/render_spec.sh` and `tests/run-tests --shell sh spec/contract/bash_spec.sh`. Confirm the new examples fail at the missing Bash artifact or loader.
- [ ] Emit the Bash artifact from the same parsed plan as zsh and publish it through the per-host render cache. Include it in validity and recovery checks. Preserve input order and safe quoting. Close the parity gaps from the native zsh env phase, including the PATH finalizer's module and shim bins, optional tool and manager paths, and Go's `GOROOT` reconciliation. Test inherited unmanaged entries and re-sourcing separately.
- [ ] Implement the Bash loaders with quiet handling for a missing cache and the existing env-only render path for recovery. Export MarkSharc's `BASH_ENV` only when the option is enabled. Test opt-in, opt-out, repeated sourcing, and a caller-provided hook so ownership is explicit. Preserve the caller's shell flags.
- [ ] Rerun the focused suites and commit the green renderer and startup work.

## 2. Install and restore Bash startup files

Touch `install.sh`, `core/cli/uninstall`, `tests/spec/install/installer_spec.sh`, `tests/spec/install/rerun_spec.sh`, `tests/spec/install/uninstall_spec.sh`, and `tests/e2e/install-e2e.sh`.

- [ ] Add failing tests for a fresh install, an upgrade from a zsh-only manifest, and an idempotent rerun. Test a regular `.bashrc` and a `.bash_profile` symlink. Verify dry-run leaves them intact, install preserves their recovery records, and uninstall restores both. Exercise paths with spaces and a foreign replacement file.
- [ ] Run `tests/run-tests --shell sh spec/install` and confirm the new cases fail because the Bash stubs and their recovery records are missing.
- [ ] Install both Bash stubs using the existing backup and manifest conventions. When upgrading, retain existing zsh backup records while adding Bash records. Refuse collisions before writes, preserve edited managed stubs, and keep older manifests readable by uninstall.
- [ ] Extend the fresh-HOME e2e to launch the installed `bash -lc`, exercise `BASH_ENV` in a nonlogin child, and check that uninstall removes the managed Bash stubs. Compare only MarkSharc exports and PATH when shell-specific variables differ.
- [ ] Rerun the focused install suite and `tests/e2e/install-e2e.sh "$PWD"`, then commit.

## 3. Document and verify the delivered contract

- [ ] Update `README.md`, `docs/DEVELOPING.md`, `templates/overlay/README.md`, `tests/README.md`, and `CHANGELOG.md` where the delivered behavior applies. Show `set agent.bash_env on` and `SHELL=/bin/bash claude` or `SHELL=/bin/bash codex` from a configured parent that has applied the option. Describe reinstall and rollback for existing users.
- [ ] Run `tests/check`, `tests/e2e/install-e2e.sh "$PWD"`, and `git diff --check`. Check repeated isolated renders for drift and ensure generated files stay outside the checkout.
- [ ] Exercise both real shell binaries through the installed stubs and agent child invocation. Record which parts of the actual Claude Code and Codex launch contract can be verified without credentials or service access.
- [ ] Complete quality review, stack-check, configured reviews, and exact-head macOS and Ubuntu CI through the phase runbook. Record the delivered outcome and gaps against P3.2 before handoff.
