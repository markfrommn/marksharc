# DEV-87 Carapace managed spec wiring, lifecycle, and end-to-end parity

Deliver L8.3 from [COMPLETION-PLAN.md](COMPLETION-PLAN.md) under [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md)
and [COMPLETION-SPEC.md](COMPLETION-SPEC.md) (sections 6 and 8).

## Scope

1. **Carapace specs directory resolution and managed symlink reconciliation (sections 6.1, 6.2)**
   - Add `core/zsh/lib/carapace.zsh` with:
     - `_ms_carapace_specs_dir`: resolves `$XDG_CONFIG_HOME/carapace/specs` when `XDG_CONFIG_HOME` is set, else `$HOME/Library/Application Support/carapace/specs` on macOS (`darwin`), else `$HOME/.config/carapace/specs` on Linux.
     - `_ms_carapace_render_enabled`: checks whether `completion-carapace` is active in the render plan via `completion-carapace.enable` or explicit `module completion-carapace` (honoring explicit `enable off`).
     - `_ms_carapace_reconcile_symlinks`: creates/updates symlinks from Carapace's specs directory to `$cache/completions/carapace/<cmd>.yaml` when enabled, tracks managed symlinks in `$cache/carapace-specs-manifest` (`<cmd><TAB><link-path><TAB><target-path>`), preserves existing non-MarkSharc files and foreign symlinks with a stderr warning, and prunes stale managed symlinks when modules or `completion-carapace` are disabled.
   - Invoke `_ms_carapace_reconcile_symlinks` from `_ms_render` in `core/zsh/lib/render.zsh` during explicit full renders (`_ms_render_generate == 1`), keeping `marksharc render --env-only` strictly out of Carapace symlinks.

2. **Uninstall cleanup and doctor diagnostics (sections 6.2, 6.5)**
   - Update `core/cli/uninstall` to read all host `carapace-specs-manifest` files under the MarkSharc cache root before any `--purge` cache deletion and remove only still-owned symlinks, leaving user-authored Carapace specs untouched.
   - Update `core/cli/doctor` to verify rendered Carapace specs when `completion-carapace` is enabled and `carapace` is installed: report missing or broken managed symlinks (suggesting `marksharc render`) and report non-MarkSharc file or foreign-symlink conflicts at managed spec paths.

3. **Cache invalidation and zsh/Bash precedence (sections 6.3, 6.4)**
   - Fold a zero-fork fingerprint of `$cache/carapace-specs-manifest` (sorted managed command names + `render-id`) into `_ms_init_cached -k` in `modules/completion-carapace/init.zsh` and `_ms_bash_init_cached -k` in `core/bash/backends.bash`.
   - Align Bash completion loading in `core/bash/backends.bash` and `core/bash/interactive.bash` so active Carapace owns commands with active managed specs (unless listed in `CARAPACE_EXCLUDES`), while native Bash completions take over when Carapace is inactive or excluded.

4. **Documentation and contract inventory**
   - Add `docs/completions.md` covering user behavior (native shells, Carapace managed specs, precedence, `doctor`, `uninstall`) and module `.comp` authoring.
   - Update `README.md`, `docs/launch.md`, `docs/fish.md`, `CHANGELOG.md`, and `tests/README.md` contract inventory.

## Verification

- Add `tests/spec/contract/carapace_completions_spec.sh`:
  - End-to-end `carapace <cmd> export ...` for `marksharc`, `launch-session`, `launch-repo`, and `cwf-new` in temporary `HOME` (skipped cleanly when `carapace` is absent), covering live hosts, repos, worktrees, modules, installers, update steps, and git branches.
  - Platform specs directory resolution (`XDG_CONFIG_HOME`, macOS default, Linux default).
  - Managed symlink lifecycle: creation, non-MarkSharc regular-file and foreign-symlink conflict preservation, stale pruning on module disable and `completion-carapace` disable, `--env-only` non-interference, `marksharc uninstall` (with and without `--purge`), `marksharc doctor` diagnostics (healthy, missing, broken, conflict), and zsh/Bash `_ms_init_cached` / `_ms_bash_init_cached` invalidation.
  - Zsh and Bash Carapace-active vs native-fallback and `CARAPACE_EXCLUDES` precedence specs.
- Run `tests/check` (lint, zsh, contract, install, repo, and fish suites) and `tests/e2e/install-e2e.sh`.
