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

The implementation touches `core/zsh/lib/render.zsh`, `core/zsh/lib/rendered.zsh`, `core/zsh/lib/render-bash.zsh`, and `modules/agent/`. The Bash entry points and PATH builder live in `core/bash/`. The Bash emitter and startup checks live in `tests/spec/contract/bash_spec.sh`.

- [x] Check the Bash artifact for valid syntax, repeatable output, literal hostile values, and missing-cache recovery. Exercise a late directory guard without rerunning a generator.
- [x] Compare MarkSharc PATH and environment against zsh from a common starting PATH and overlay. Cover inherited `bash -c`, isolated `bash -c` with the managed hook, and installed `bash -lc`. Exercise batch and agent markers with quiet startup.
- [x] Run the new Bash contract examples before their implementation and rerun them after each change. Run the existing zsh renderer checks through the complete zsh suite.
- [x] Emit and recover the Bash artifact using the per-host cache. Preserve directive order and safe quoting. Exercise native PATH and tool setup, including module and shim bins, manager precedence, custom tiers and repeat sourcing.
- [x] Implement the quiet Bash hook and opt-in `BASH_ENV` setting. Exercise existing hooks and isolated startup.
- [x] Commit the renderer and startup work with the focused suites green.

## 2. Install and restore Bash startup files

Touch `install.sh`, `core/cli/uninstall`, `tests/spec/install/installer_spec.sh`, `tests/spec/install/rerun_spec.sh`, `tests/spec/install/uninstall_spec.sh`, and `tests/e2e/install-e2e.sh`.

- [x] Add installer regressions for fresh and legacy installs, reruns, original regular files and symlinks, interrupted upgrades, and edited stubs.
- [x] Observe the new install tests fail before implementing the Bash backup and restore behavior.
- [x] Install both Bash stubs using the existing backup and manifest conventions. Preserve earlier zsh backups and handle recovery on retry.
- [x] Exercise the installed `bash -lc` in the contract suite and the nonlogin `BASH_ENV` hook in the fresh-HOME e2e. Check that uninstall removes both managed Bash stubs.
- [x] Rerun the install suite and the fresh-HOME checkout and clone e2e.

## 3. Document and verify the delivered contract

- [x] Update the user, developer, overlay and test documentation and the changelog. Document opt-in, agent commands, reinstall and rollback.
- [x] Run `tests/check`, the install e2e and `git diff --check`. Verify repeated isolated renders produce identical Bash output only in the cache.
- [x] Exercise both real shell binaries through the installed stubs and through agent child-shell stubs. Live Claude Code and Codex launches remain unverified.
- [x] Complete independent quality review and stack-check. The fixes preserve worktree settings in child processes, clear the managed hook on opt-out, and keep activated environments ahead of managers.
- [x] Verify the implementation on hosted macOS and Ubuntu. The four jobs pass on `e15f80f` in the [implementation CI run](https://github.com/markfrommn/marksharc/actions/runs/45140522192). The [delivery PR](https://github.com/markfrommn/marksharc/pull/9) records the local review disposition and remaining live-agent verification gap.
