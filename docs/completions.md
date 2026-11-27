# Completions

MarkSharc renders interactive completions for `marksharc`, `launch-session`, `launch-repo`,
and `cwf-new` from a single declarative `.comp` specification into four targets during
`marksharc render`:

```text
${XDG_CACHE_HOME:-~/.cache}/marksharc/<host>/completions/
  zsh/_<cmd>
  bash/<cmd>.bash
  fish/<cmd>.fish
  carapace/<cmd>.yaml
```

All dynamic candidates are produced by one strictly offline, read-only helper
(`core/cli/complete`). Pressing Tab never runs `ssh`, `hc`, `herdr`, `repo-list`, or
`git fetch` — it reads local overlay configuration, module metadata, local git refs, and
cached repository inventories (`${XDG_CACHE_HOME:-~/.cache}/marksharc/<host>/repos/*.tsv`).

## Shell loading and Carapace precedence

- **Zsh:** `_ms_modules_setup_paths` prepends `$cache/completions/zsh` to `$fpath` before
  `completion` runs `compinit`. When `completion-carapace` is enabled (and `carapace` is
  installed), Carapace registers `_carapace_completer` over commands with managed specs
  unless they appear in `CARAPACE_EXCLUDES`, in which case native `_<cmd>` handles them.
- **Bash 4.4+:** `core/bash/interactive.bash` loads rendered `$cache/completions/bash/*.bash`
  alongside module completions (`cwf`, `herdr`). When Carapace is the active completion
  provider and a command has an active managed Carapace spec (and is not in
  `CARAPACE_EXCLUDES`), MarkSharc leaves Carapace's registration in place; otherwise native
  Bash completions take over. Bash 3.2 stays env-only.
- **Fish:** `core/fish/marksharc.fish` prepends `$cache/completions/fish` to
  `fish_complete_path` (with clean reload removal). Users who invoke `carapace _carapace fish`
  automatically pick up the same managed Carapace symlinks.

## Managed Carapace specs lifecycle

When `completion-carapace` is enabled (via `set completion-carapace.enable on` or explicit
`module completion-carapace`), `marksharc render` reconciles symlinks from Carapace's
platform specs directory to `$cache/completions/carapace/<cmd>.yaml`:

- **Specs directory resolution:**
  1. `$XDG_CONFIG_HOME/carapace/specs` when `XDG_CONFIG_HOME` is set.
  2. `~/Library/Application Support/carapace/specs` on macOS when `XDG_CONFIG_HOME` is unset.
  3. `~/.config/carapace/specs` on Linux when `XDG_CONFIG_HOME` is unset.
- **Manifest tracking:** Managed symlinks are recorded in `$cache/carapace-specs-manifest`
  as `<cmd><TAB><link-path><TAB><target-path>`.
- **Conflict preservation:** Existing regular files and symlinks pointing outside
  MarkSharc's cache are never overwritten or deleted. `marksharc render` prints a warning
  to stderr and skips that command; `marksharc doctor` reports the conflicting path so you
  can move or rename it.
- **Pruning:** Disabling a module or disabling `completion-carapace` followed by
  `marksharc render` prunes stale MarkSharc-owned symlinks while leaving user specs intact.
- **Cache invalidation:** Zsh (`_ms_init_cached -k`) and Bash (`_ms_bash_init_cached -k`)
  fold a fingerprint of `$cache/carapace-specs-manifest` and `render-id` into Carapace's
  init cache key so newly added or removed specs take effect on the next fresh shell.
- **Startup recovery (`--env-only`):** `marksharc render --env-only` never modifies
  completions or Carapace symlinks.
- **Diagnostics:** When `completion-carapace` is enabled and `carapace` is installed,
  `marksharc doctor` reports missing, broken, or conflicting managed Carapace spec symlinks.
- **Uninstall:** `marksharc uninstall` (before any `--purge` cache removal) removes every
  still-owned symlink recorded in `carapace-specs-manifest`, leaving user-authored Carapace
  specs untouched.

## Authoring `.comp` specs in modules and overlays

`marksharc render` discovers `.comp` files in precedence order (later entries override
earlier ones for the same command name):

1. Core: `$MARKSHARC_HOME/core/completions/*.comp`
2. Enabled public modules: `modules/<name>/completions/*.comp`
3. Enabled overlay modules: `$MARKSHARC_CONFIG/modules/<name>/completions/*.comp`

Any `.comp` addition, edit, or removal invalidates the render ID (`envid.zsh`). External
`completion` / `completion-bash` directives and hand-written static completions (`cwf`,
`herdr`) remain supported alongside `.comp` files.

### Directive vocabulary

`.comp` files are strictly data-only (never embedded shell code) and tokenized with
`_ms_words` (blank lines and `#` comments are ignored):

| Directive | Syntax | Purpose |
| --- | --- | --- |
| `command` | `command <name> [description]` | Required once per file; declares root command name and description. |
| `subcommand` | `subcommand <path> [description]` | Declares a `/`-separated subcommand path (e.g. `hosts/remove`); parents must precede children. |
| `flag` | `flag <scope> <names> [value <kind>] [repeatable] [locks-positional] [description]` | Declares short/long flags on `_` (root) or `<path>`. Flags are not inherited by subcommands. |
| `arg` | `arg <scope> <slot> <kind> [description]` | Declares positional slots (`1`, `2`, ..., `rest`, `dash1`, `dash-rest`). |
| `mode` | `mode <scope> flag-form-locks-positional` | Suppresses positional slot `1` once a `locks-positional` flag appears; shifts `dash1` to `dash-rest` when `--command` is set. |

### Value kinds

| Kind | Source |
| --- | --- |
| `choices:<a,b,c>` | Static comma-separated choices |
| `string` | Free-text argument (no candidates) |
| `dir`, `file`, `command` | Native shell directory, file, or `PATH` executable completion |
| `ms:modules` | Discovered public and overlay modules |
| `ms:hosts` | Configured hosts in overlay `hosts.conf` |
| `ms:installers` | Registered `installer` directives |
| `ms:update-steps` | Built-in and registered `update` step labels |
| `ms:launch-hosts` | Reserved + current + `hosts.conf` launch hosts |
| `ms:repos`, `ms:base-repos`, `ms:base-repos-or-dir` | Cached local or remote repository inventories |
| `ms:worktrees` | Cached worktree and branch names (filtered by `--repo` when set) |
| `ms:git-branches` | Local git branch refs in the current working repository |
| `ms:launch-session-target` | Composite `[host:]dir` target |
| `ms:launch-repo-target` | Composite `[host:]repo[/worktree]` or local dir target |

After adding or editing a `.comp` file, run `marksharc render` (or `marksharc reload`) to
regenerate all four targets, and verify with `tests/check`. See
[specs/COMPLETION-SPEC.md](../specs/COMPLETION-SPEC.md) for the full contract.
