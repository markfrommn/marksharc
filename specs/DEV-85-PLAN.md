# DEV-85 Completion spec renderer and dynamic candidate helper

Deliver L8.1 from [COMPLETION-PLAN.md](COMPLETION-PLAN.md) under [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md)
and [COMPLETION-SPEC.md](COMPLETION-SPEC.md) (sections 2, 3, 4, 5.1, and 5.2).

## Scope

1. **Dynamic candidate helper (`core/cli/complete`)**
   - Standalone offline, read-only `zsh -f` executable resolving `MARKSHARC_HOME` from its own path.
   - Supports all ten `<kind>` modes: `modules`, `hosts`, `installers`, `update-steps`, `launch-hosts`, `repos`, `base-repos`, `worktrees`, `launch-repo-target`, and `git-branches`.
   - Supports `--host`, `--repo`, `--prefix`, `--base-only`, `--current`, `--colon`, and `--from-carapace` (`C_FLAG_HOST`, `C_FLAG_REPO`, `C_FLAG_BASE_ONLY`, `C_VALUE`).
   - Enforces host validation (`_ms_hosts_valid_name`, rejecting `.`, `..`, and `/`), host normalization (`''`, `local`, `localhost`, `$MARKSHARC_HOST` -> `local`), control-character stripping, literal `value` / `value<TAB>description` output, and zero network/remote invocations.

2. **Declarative `.comp` parser and multi-target renderer (`core/zsh/lib/render-completions.zsh`)**
   - Parses `.comp` files with `_ms_words`, enforcing the closed directive vocabulary (`command`, `subcommand`, `flag`, `arg`, `mode`) and closed value `<kind>` set (`choices:...`, `string`, `dir`, `file`, `command`, and `ms:*`), failing with stderr diagnostics on malformed or conflicting specs.
   - Discovers `.comp` files in precedence order: `core/completions/*.comp` < enabled public modules' `completions/*.comp` < enabled overlay modules' `completions/*.comp`.
   - Emits four targets per spec into the atomic staging tree:
     - `zsh/_<cmd>` (`#compdef <cmd>`, `_arguments -S`, subcommand dispatch, `flag-form-locks-positional`, colon-prefix handling)
     - `bash/<cmd>.bash` (`_ms_complete_<slug>`, Readline unquoting and `:@=` reassembly, literal quoting, `complete -o filenames -F`)
     - `fish/<cmd>.fish` (`complete -c <cmd>` with subcommand-path and positional/flag predicates)
     - `carapace/<cmd>.yaml` (Carapace 1.8.5 schema-valid YAML with POSIX single-quoted render-time helper paths and `$nospace(:)` where specified)

3. **Render pipeline and fingerprint integration (`core/zsh/lib/render.zsh`, `core/zsh/lib/envid.zsh`)**
   - Move `completion-bash` external generator staging to a dedicated `$_ms_render_bash_stage` promoted atomically to `$cache/completions-bash`, eliminating collision with `$_ms_render_stage/bash` (promoted atomically with `$_ms_render_stage` to `$cache/completions`).
   - Invoke `_ms_render_completions` inside `_ms_render` when generating completions (`_ms_render_generate == 1`), while keeping `marksharc render --env-only` completely out of completion and shim directories.
   - Ensure `core/zsh/lib/envid.zsh` folds `core/completions/*.comp`, module `completions/*.comp`, and overlay `completions/*.comp` into the render id (already covered by recursive globs; verify explicitly in tests).
   - Keep `core/zsh/lib/render-completions.zsh` compliant with `tests/support/function-safe-check.py` (no bare file-scope declarations).

## Verification

- `tests/spec/zsh/complete_helper_spec.sh`: unit coverage for every `<kind>`, spaces/apostrophes/colons, missing caches, path-traversal host rejection, `--from-carapace`, and stubbed `ssh`/`hc`/`herdr`/`repo-list` proving zero invocations.
- `tests/spec/zsh/render_completions_spec.sh`: valid/invalid `.comp` parsing, precedence overrides, golden assertions for all four targets, `zsh -n`, `bash -n`, `fish --no-execute`, and real `carapace <cmd> export` validation when `carapace` is installed, plus `envid` invalidation, `--env-only` isolation, and coexistence with existing `completion` / `completion-bash` directives.
- Full `tests/check` green (lint, zsh specs, contract specs, install specs, repo specs, fish units).
