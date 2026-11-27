# MarkSharc Declarative Completion Specification

| | |
|---|---|
| Status | Design and three-PR decomposition approved 2026-11-27 |
| Source issue | [DEV-84](https://linear.app/psols/issue/DEV-84) (L8.0 design/docs PR) |
| Implementation issues | [DEV-85](https://linear.app/psols/issue/DEV-85) (L8.1), [DEV-86](https://linear.app/psols/issue/DEV-86) (L8.2), [DEV-87](https://linear.app/psols/issue/DEV-87) (L8.3) |
| Authority | [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md) (especially sections 6.1, 6.4, 6.5, 6.9, 6.15, 6.16, 10); [LAUNCH-SPEC.md](LAUNCH-SPEC.md) and [BASH-SPEC.md](BASH-SPEC.md) for command and Bash backend contracts |
| Delivery plan | [COMPLETION-PLAN.md](COMPLETION-PLAN.md) and [MARKSHARC-PLAN.md](MARKSHARC-PLAN.md) (L8) |
| Evidence date | 2026-11-27, checkout `6fb1a49`, Carapace `1.8.5` |

This specification defines a single declarative completion format (`*.comp`), a shared offline dynamic candidate helper (`core/cli/complete`), a multi-target renderer integrated into `marksharc render` for zsh, Bash 4.4+, Fish, and Carapace, and managed Carapace spec registration. Its initial command scope covers `marksharc`, `launch-session`, `launch-repo`, and `cwf-new`.

## 1. Problem and baseline at `6fb1a49`

Before L8, completions for MarkSharc's own commands are fragmented and incomplete:

| Command | Zsh | Bash 4.4+ | Fish | Carapace |
|---|---|---|---|---|
| `marksharc` | Missing | Missing | Hand-written (`core/fish/completions/marksharc.fish`); lacks dynamic `install <name>` and `update --only <label>` | Missing |
| `launch-session` | Hand-written (`_launch-session`) | Hand-written (`workflow.bash`) | Hand-written (`launch-session.fish`) | Missing |
| `launch-repo` | Hand-written (`_launch-repo`); missing `--host` completer, `--base-only`, positional `host:`, repo-filtered `--worktree`, branch matches | Hand-written (`workflow.bash`) | Hand-written (`launch-repo.fish`); missing `--host` completer, `--base-only`, positional `host:`, repo-filtered `--worktree` | Missing |
| `cwf-new` | Hand-written (`_cwf-new`); missing `--host` completer | Hand-written (`workflow.bash`) | Hand-written (`cwf-new.fish`); missing `--host` completer | Missing |

Maintaining 16 independent completion files across four targets causes flags, subcommands, and dynamic lookup logic to drift.

### Empirical Carapace 1.8.5 findings

Probed locally against `carapace-bin 1.8.5` in isolated temporary `HOME` directories:

1. **Spec discovery path:** Carapace does **not** honor a `CARAPACE_SPECS` environment variable. It loads user YAML specs only from its config specs directory:
   - `$XDG_CONFIG_HOME/carapace/specs/` when `XDG_CONFIG_HOME` is set (macOS and Linux).
   - `~/Library/Application Support/carapace/specs/` on macOS when `XDG_CONFIG_HOME` is unset.
   - `~/.config/carapace/specs/` on Linux when `XDG_CONFIG_HOME` is unset.
2. **Symlinks:** Carapace follows symlinks placed in its specs directory and automatically includes linked specs in `carapace --list`, `carapace <cmd> export`, and `carapace _carapace zsh|bash|fish`.
3. **Dynamic command actions:** Carapace YAML specs natively execute `"$(<command>)"` macros, pass parsed flag and current-word context via `C_FLAG_<NAME>` and `C_VALUE` environment variables, and parse `value<TAB>description` stdout lines into completions with descriptions.

## 2. Architecture and design decisions

### Selected approach: Declarative `.comp` specs + shared helper + multi-target renderer

Three alternatives were evaluated during DEV-84:

| Approach | Summary | Decision |
|---|---|---|
| **A. Common `.comp` line-directive spec rendered to zsh, Bash, Fish, and Carapace YAML + shared candidate helper** | Single declarative source parsed with `_ms_words` (zero host YAML/TOML parser), rendered atomically by `marksharc render`, backed by one offline candidate helper (`core/cli/complete`). | **Selected** |
| B. Shared candidate helper + hand-maintained zsh/Bash/Fish/Carapace files + parity tests | Avoids a renderer, but duplicates command/flag trees across four formats. | Rejected |
| C. Carapace YAML as source + dev-time Python generator producing checked-in native files | Avoids a custom spec format, but cannot render overlay/private module specs on a host and introduces generated checked-in drift. | Rejected |

### Core design principles

1. **Closed declarative vocabulary:** `.comp` files describe command hierarchies, flags, value kinds, and positional slots as data only — never embedded shell code (honoring [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md) section 11 and Design Rule 6).
2. **Zero host parser dependency:** `.comp` uses the same line-directive tokenization as `module.conf` (`_ms_words` — zsh `(z)` splitting and `(Q)` unquoting).
3. **Strictly offline and read-only on Tab:** Neither rendered completions nor `core/cli/complete` perform network calls, SSH connections, git fetches, or remote inventory scans during completion. Dynamic data is read only from local overlay config, module metadata, local git refs, and local cached repository inventories (`$XDG_CACHE_HOME/marksharc/<host>/repos/*.tsv`).
4. **Data stays data:** Values containing spaces, quotes, colons, or shell metacharacters are passed and returned literally without `eval`.
5. **Framework remains read-only:** All rendered completion artifacts live in `$XDG_CACHE_HOME/marksharc/<host>/completions/`. Carapace receives manifest-tracked symlinks pointing into that cache.
6. **Coexistence:** External and hand-written static completions (`herdr`, `cwf`, generated `completion` and `completion-bash` directives) remain supported and untouched.

## 3. Declarative `.comp` specification format

### 3.1 File discovery and precedence

`marksharc render` discovers `.comp` files from three locations, in precedence order (later entries override earlier entries for the same command name):

1. Framework core: `$MARKSHARC_HOME/core/completions/*.comp` (always active).
2. Enabled public modules: `<module_dir>/completions/*.comp` for each enabled, OS-compatible module in the render plan.
3. Enabled overlay modules: `$MARKSHARC_CONFIG/modules/<name>/completions/*.comp` for each enabled, OS-compatible private module in the render plan.

Every discovered `.comp` file is folded into the render input fingerprint (`core/zsh/lib/envid.zsh`), so adding, editing, or removing a `.comp` file invalidates the render id and triggers re-rendering.

### 3.2 Closed directive vocabulary

Blank lines and lines whose first non-whitespace character is `#` are ignored. Every line is parsed with `_ms_words`. Unknown directives, malformed arguments, or duplicate conflicting declarations cause the spec to fail validation with a diagnostic on stderr.

| Directive | Syntax | Meaning |
|---|---|---|
| `command` | `command <name> [description]` | Required once per file. Declares the root command name (must match `[A-Za-z0-9][A-Za-z0-9_.-]*`) and one-line description. |
| `subcommand` | `subcommand <path> [description]` | Declares a subcommand node using a `/`-separated path relative to the root (e.g., `sync`, `sync/timer`, `hosts/populate`, `module/enable`). Parent nodes must be declared before children. |
| `flag` | `flag <scope> <names> [value <kind>] [repeatable] [locks-positional] [description]` | Declares an option on `<scope>` (`_` for the root command, or a subcommand `<path>`). `<names>` is a comma-separated list of short/long forms (e.g. `-v,--verbose`, `--host`, `-y,--yes`). `value <kind>` marks the flag as taking a required argument of `<kind>`. `repeatable` allows the flag multiple times. `locks-positional` marks the flag as entering flag-form mode (disabling the primary positional target when the scope uses `mode flag-form-locks-positional`). |
| `arg` | `arg <scope> <slot> <kind> [description]` | Declares a positional argument on `<scope>`. `<slot>` is a positive integer (`1`, `2`, ...), `rest` (remaining positionals after numbered slots), `dash1` (first argument after `--`), or `dash-rest` (remaining arguments after `--`). |
| `mode` | `mode <scope> <mode-name>` | Sets a closed parsing/completion behavior hint on `<scope>`. Allowed values: `flag-form-locks-positional` (if any `locks-positional` flag is already present on the command line, positional slot `1` is suppressed and only flags or `--` / command args apply; if `--command` is present, `dash1` also falls back to `dash-rest` since the command executable is already supplied). |

Notes on grammar disambiguation:
- On `flag`, optional keyword tokens (`value <kind>`, `repeatable`, `locks-positional`) precede the optional final `<description>` token. Any description containing spaces is quoted per `_ms_words` rules (e.g. `"Show this help"`).
- Flags declared on `_` apply only to the root command unless also declared on a subcommand scope (no implicit inheritance across subcommands, avoiding leaked root flags like `--version` onto `marksharc doctor`).

### 3.3 Closed value `<kind>` set

| Kind | Meaning | Dynamic / native source |
|---|---|---|
| `choices:<a,b,c>` | Static comma-separated enumerated values | Rendered inline in all four targets |
| `string` | Arbitrary free-text argument | No completion candidates |
| `dir` | Local directory path | Native shell dir completion / Carapace `$directories` |
| `file` | Local file path | Native shell file completion / Carapace `$files` |
| `command` | Executable command name on `PATH` | Native command completion / Carapace `$carapace.shell.Executables` |
| `ms:modules` | Discovered public and overlay modules | `core/cli/complete modules` |
| `ms:hosts` | Configured hosts in overlay `hosts.conf` | `core/cli/complete hosts` |
| `ms:installers` | Registered `installer` directives | `core/cli/complete installers` |
| `ms:update-steps` | Built-in and registered `update` step labels | `core/cli/complete update-steps` |
| `ms:launch-hosts` | Reserved + current + `hosts.conf` launch hosts | `core/cli/complete launch-hosts` |
| `ms:repos` | Base repos and `base/worktree` entries for target host | `core/cli/complete repos` |
| `ms:base-repos` | Base repository names for target host | `core/cli/complete base-repos` |
| `ms:base-repos-or-dir` | Local directory if word starts with `/` or `~` on local host; else `ms:base-repos` | Local dir + `core/cli/complete base-repos` |
| `ms:worktrees` | Worktree names and branch names for `--repo` (or all worktrees if `--repo` unset) on target host | `core/cli/complete worktrees` |
| `ms:git-branches` | Local git branch names in current working repository | `core/cli/complete git-branches` |
| `ms:launch-session-target` | Composite `[host:]dir`: offers `host:` candidates (nospace) and local directories when host is local/unset | Native dirs + `core/cli/complete launch-hosts --colon` |
| `ms:launch-repo-target` | Composite `[host:]repo[/worktree]` or local dir; honors `--base-only` and `host:` prefix | Native dirs + `core/cli/complete launch-repo-target` |

## 4. Shared dynamic candidate helper (`core/cli/complete`)

`core/cli/complete` is a standalone, `zsh -f` executable (`MARKSHARC_HOME` resolved from its own path, matching `bin/marksharc`). It is invoked internally by generated completions and Carapace specs, and is **not** listed in `marksharc help` or `marksharc` subcommand completions.

### 4.1 Invocation contract

```text
$MARKSHARC_HOME/core/cli/complete <kind> [options]
```

Supported `<kind>` values and options:

| `<kind>` | Options | Output (`value` or `value<TAB>description` per line) |
|---|---|---|
| `modules` | — | Sorted unique module names from `$MARKSHARC_HOME/modules/*/module.conf` and `$MARKSHARC_CONFIG/modules/*/module.conf`, with `describe` text as description |
| `hosts` | — | Configured host names from `hosts.conf`, with SSH target as description when target differs from name |
| `installers` | — | Registered `installer <name>` labels collected via `core/cli/day2-lib.zsh` (`_day2_allow_missing=1`) |
| `update-steps` | — | Built-in labels (`sync`, `pins`, `system`, `render`) plus registered `update <label>` entries from enabled modules and overlay |
| `launch-hosts` | `[--colon]` | Deduplicated `local`, `localhost`, `remote`, `$MARKSHARC_HOST`, plus `hosts.conf` entries; with `--colon`, omits host names containing `:` and appends `:` |
| `repos` | `[--host H] [--prefix P] [--base-only]` | Reads local `$XDG_CACHE_HOME/marksharc/<host>/repos/<resolved-host>.tsv`; emits base names and (unless `--base-only`) `base/worktree` and `base/branch` entries prefixed with `P` |
| `base-repos` | `[--host H]` | Base repository names (`kind == base`) from the resolved host's local TSV cache |
| `worktrees` | `[--host H] [--repo R]` | Worktree names and non-duplicate branch names from the resolved host's local TSV cache; when `--repo R` is non-empty, filters to rows where `${base:t} == R` |
| `launch-repo-target` | `[--host H] [--base-only] [--current W]` | Handles `host:rest` splitting: if `W` contains `:` with a valid host prefix, completes repos for that host with `host:` prefix; otherwise completes local repos (plus `host:` candidates when no repo matches or when starting a host prefix) |
| `git-branches` | — | Output of `git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null` |

### 4.2 Safety and hygiene guarantees

- **Offline only:** Never calls `ssh`, `hc`, `herdr`, `repo-list`, or `git fetch`. Missing `hosts.conf`, missing `repos/<host>.tsv`, or non-git directories exit `0` with empty stdout.
- **Host validation:** Host names passed via `--host` or extracted from `host:...` are validated with `_ms_hosts_valid_name` and rejected if equal to `.` or `..` or containing `/`, preventing cache path traversal.
- **Host normalization:** Empty string, `local`, `localhost`, and `$MARKSHARC_HOST` resolve to `local` for TSV lookup.
- **Literal output:** Output lines strip control characters/newlines inside fields and emit plain tab-separated text (`value` or `value<TAB>description`), never shell-escaped code. Callers handle shell-specific quoting.
- **Environment variable fallback for Carapace:** When an option flag like `--host` or `--repo` is not explicitly passed, `core/cli/complete` accepts `--from-carapace` to read Carapace's `C_FLAG_HOST`, `C_FLAG_REPO`, `C_FLAG_BASE_ONLY`, and `C_VALUE` safely without requiring shell quoting inside YAML macros.

## 5. Multi-target renderer and shell integration

### 5.1 Render pipeline (`core/zsh/lib/render-completions.zsh`)

`marksharc render` invokes `_ms_render_completions` inside its atomic staging directory (`$_ms_render_stage`), producing four subdirectories under `$XDG_CACHE_HOME/marksharc/<host>/completions/`:

```text
$XDG_CACHE_HOME/marksharc/<host>/completions/
  zsh/_<cmd>
  bash/<cmd>.bash
  fish/<cmd>.fish
  carapace/<cmd>.yaml
```

Staging and promotion rules:
- Existing generated `completion-bash` directives move to their own dedicated staging directory (`$_ms_render_bash_stage`, promoted atomically to `$cache/completions-bash`), eliminating any collision with `$_ms_render_stage/bash` (promoted atomically with `$_ms_render_stage` to `$cache/completions/bash`). Existing `completion` (zsh) directives continue writing into `$_ms_render_stage/zsh` without colliding with `.comp` outputs. Each `.comp` spec is validated before writing any target.
- `marksharc render --env-only` (used by startup auto-recovery) **never modifies** `$cache/completions/`, `$cache/completions-bash/`, `$cache/bin/`, or Carapace symlinks. This keeps startup recovery fast and offline and guarantees previously generated external completions (`_herdr`, `_cwf`) are never deleted during recovery.
- Explicit `marksharc render` (as well as `marksharc reload`, `marksharc update`, and `install.sh`) renders all `.comp` specs across all four targets, runs external `completion` and `completion-bash` directives, and reconciles Carapace symlinks atomically.

### 5.2 Per-target runtime contracts

| Target | Generated artifact | Runtime behavior |
|---|---|---|
| **Zsh** | `zsh/_<cmd>` (`#compdef <cmd>`) | Standard zsh `_arguments -S` with subcommand dispatch (`_describe`), flag descriptions, value actions, `flag-form-locks-positional` state check (including `--command` shifting `dash1` to `dash-rest`), and colon-prefix handling (`compadd -r : -S :` / `compadd -P`). Loaded automatically because `_ms_modules_setup_paths` already prepends `$cache/completions/zsh` to `$fpath` before `compinit`. |
| **Bash 4.4+** | `bash/<cmd>.bash` | Defines `_ms_complete_<cmd>` and registers `complete -o filenames -F ... <cmd>`, sharing `core/bash/complete.bash` (extracted and generalized from `modules/launch/completions/bash/lib/workflow.bash`) for safe Readline unquoting, `:@=` word-break reassembly, and literal candidate quoting. Loaded by `core/bash/interactive.bash` after module loading (respecting Carapace precedence in section 6.4). Bash 3.2 remains env-only and never sources completion files. |
| **Fish** | `fish/<cmd>.fish` | Emits native `complete -c <cmd>` rules with subcommand predicates (`__fish_seen_subcommand_from` / position helpers), descriptions, and helper functions invoking `core/cli/complete`. `core/fish/marksharc.fish` prepends `$cache/completions/fish` to `fish_complete_path` (tracked in `_ms_fish_completion_paths` for clean reload removal). |
| **Carapace 1.8.5** | `carapace/<cmd>.yaml` | Schema-valid Carapace YAML with `name`, `description`, `flags`, `commands`, and `completion` blocks. Static choices emit YAML string arrays; `dir`/`file`/`command` emit `$directories` / `$files` / `$carapace.shell.Executables`. Helper invocations embed the render-time resolved `$MARKSHARC_HOME/core/cli/complete` path with POSIX single-quoting (never unquoted `$MARKSHARC_HOME`, so spaces in checkout paths or an unset env var never break completion): simple `ms:*` kinds emit `"$('<helper>' <kind> --from-carapace)"`; `ms:base-repos-or-dir` emits `["$directories", "$('<helper>' base-repos --from-carapace)"]`; `ms:launch-session-target` emits `["$directories", "$('<helper>' launch-hosts --colon --from-carapace)"]` with `$nospace(:)`; `ms:launch-repo-target` emits `["$directories", "$('<helper>' launch-repo-target --from-carapace)"]` with `$nospace(:)`. |

### 5.3 Retirement of replaced hand-written files

In L8.2 (`DEV-86`), once the four `.comp` specs are active and verified across all native shells, the replaced hand-written completion files are deleted:
- `core/fish/completions/marksharc.fish` (and empty `core/fish/completions/` registration if no other files remain)
- `modules/launch/completions/zsh/_launch-session`, `_launch-repo`
- `modules/launch/completions/fish/launch-session.fish`, `launch-repo.fish`
- `modules/launch/completions/bash/launch-session.bash`, `launch-repo.bash`, `lib/workflow.bash` (Readline helpers move to `core/bash/complete.bash`)
- `modules/cwf/completions/zsh/_cwf-new`, `modules/cwf/completions/fish/cwf-new.fish`, `modules/cwf/completions/bash/cwf-new.bash`

Unrelated static and generated completions (`modules/cwf/completions/bash/cwf.bash`, `modules/herdr/completions/bash/herdr.bash`, and `completion` / `completion-bash` directives) stay untouched.

## 6. Carapace integration and lifecycle

### 6.1 Specs directory resolution

MarkSharc resolves Carapace's specs directory identically to `carapace-bin 1.8.5`:
1. If `XDG_CONFIG_HOME` is non-empty: `$XDG_CONFIG_HOME/carapace/specs`.
2. Else on macOS (`MARKSHARC_OS == darwin`): `$HOME/Library/Application Support/carapace/specs`.
3. Else (Linux): `$HOME/.config/carapace/specs`.

### 6.2 Managed symlinks and manifest

When `completion-carapace` is enabled (per `completion-carapace.enable` or explicit `module completion-carapace`), `marksharc render` reconciles symlinks from the Carapace specs directory to `$cache/completions/carapace/<cmd>.yaml`:

- **Manifest:** `$cache/carapace-specs-manifest` records one `<cmd><TAB><link-path><TAB><target-path>` entry per symlink managed by MarkSharc.
- **Create / update:** For each rendered `<cmd>.yaml`:
  - If `<link-path>` does not exist: create parent directory and symlink `<link-path> -> $cache/completions/carapace/<cmd>.yaml`.
  - If `<link-path>` is already a symlink pointing into MarkSharc's cache (`$cache/completions/carapace/...` or recorded in the previous manifest): update/retain it.
  - If `<link-path>` is an existing regular file or a symlink pointing elsewhere: **do not overwrite or delete it**; print a concise warning to stderr and record the conflict so `marksharc doctor` reports it.
- **Prune:** Any manifest entry whose `<cmd>.yaml` is no longer rendered (module disabled, spec removed, or `completion-carapace` disabled) is removed **only if** `<link-path>` is still a symlink matching MarkSharc's recorded target.
- **Uninstall:** `marksharc uninstall` reads `$cache/carapace-specs-manifest` (before any `--purge` cache deletion) and removes every still-owned symlink, leaving any user-authored Carapace specs untouched.

### 6.3 Cache invalidation

Carapace's cached init snippet (`carapace _carapace zsh` in `modules/completion-carapace/init.zsh` and `carapace _carapace bash` in `core/bash/backends.bash`) enumerates the commands present in Carapace's specs directory at init-generation time. Zsh (`_ms_init_cached -k`) and Bash (`_ms_bash_init_cached -k`) both fold a fingerprint of `$cache/carapace-specs-manifest` (sorted managed command names + render id) into their cache keys, ensuring newly added or removed specs take effect on the next shell without manual cache clearing.

### 6.4 Precedence between Carapace and native completions

- **Zsh:** `completion` runs `compinit` at order 70 (loading `_<cmd>` from `$fpath`), and `completion-carapace` runs at order 72 (running `compdef _carapace_completer ...`). When Carapace is active and `<cmd>` is not in `CARAPACE_EXCLUDES`, Carapace owns `<cmd>`; when Carapace is inactive or `<cmd>` is excluded, native `_<cmd>` handles it.
- **Bash 4.4+:** `core/bash/backends.bash` initializes Carapace before `_ms_bash_load_completions` runs. `_ms_bash_load_completions` checks whether `_ms_bash_active_completion == carapace` and `<cmd>` has an active managed Carapace spec (and is not excluded via `CARAPACE_EXCLUDES`): if so, it skips overriding Carapace's `complete` registration for `<cmd>` so Carapace owns it; otherwise it loads `$cache/completions/bash/<cmd>.bash` natively.
- **Fish:** Native rendered Fish completions load from `$cache/completions/fish`. If a user runs `carapace _carapace fish` in Fish, Carapace automatically discovers the same managed symlinks.

### 6.5 `marksharc doctor` diagnostics

When `completion-carapace` is enabled and `carapace` is installed, `marksharc doctor` verifies:
1. Every rendered Carapace spec has its expected managed symlink in Carapace's specs directory (reports missing or broken links and suggests `marksharc render`).
2. No non-MarkSharc file conflicts at a managed spec path (reports the conflicting path cleanly so the user can move or rename it).

## 7. Command completion contracts

### 7.1 `marksharc` (`core/completions/marksharc.comp`)

- **Root flags:** `-h,--help`, `-V,--version`
- **Subcommands and arguments:**
  - `reload`: `-v,--verbose`
  - `render`: (no user flags)
  - `sync`: `--auto`, `--update`, `--system`, `-y,--yes`, `-h,--help`
    - `sync/timer`: `-h,--help`, arg `1` `choices:on,off,status`
  - `push`: `--update`, `--system`, `-y,--yes`, `--timeout <string>`, `--max-parallel <string>`, `--dry-run`, `-v,--verbose`, `--populate`, `-h,--help`, arg `rest` `ms:hosts`
  - `hosts`: `-h,--help`
    - `hosts/list`
    - `hosts/populate`: `--all`, `--source choices:ssh,hc,all`, `-h,--help`
    - `hosts/add`: arg `1` `string` (name), arg `2` `string` (ssh target)
    - `hosts/remove`: arg `1` `ms:hosts`
    - `hosts/help`
  - `bootstrap`
  - `update`: `--list`, `--dry-run`, `--only ms:update-steps`, `-y,--yes`, `--system`, `-h,--help`
  - `install`: arg `1` `ms:installers`
  - `doctor`
  - `module`:
    - `module/list`
    - `module/enable`: arg `1` `ms:modules`
    - `module/disable`: arg `1` `ms:modules`
  - `uninstall`: `--purge`, `-y,--yes`, `-h,--help`
  - `version`
  - `help`

### 7.2 `launch-session` (`modules/launch/completions/launch-session.comp`)

- **Mode:** `flag-form-locks-positional`
- **Flags:** `-h,--help`, `--host ms:launch-hosts` (`locks-positional`), `--pwd dir` (`locks-positional`), `--command command` (`locks-positional`), `--mux choices:hc,herdr,tmux,herdr-core`, `--mux-id string`, `--place choices:workspace,tab,hidden`, `--name string`, `--env string` (`repeatable`), `--in-shell`, `--no-focus`, `--dry-run`, `--quiet`
- **Positionals:** `1` `ms:launch-session-target`, `2` `command`, `rest` `file`; `dash1` `command` (falls back to `file` when `--command` is already set), `dash-rest` `file`

### 7.3 `launch-repo` (`modules/launch/completions/launch-repo.comp`)

- **Mode:** `flag-form-locks-positional`
- **Flags:** `-h,--help`, `--host ms:launch-hosts` (`locks-positional`), `--repo ms:base-repos-or-dir` (`locks-positional`), `--worktree ms:worktrees` (`locks-positional`), `--command command` (`locks-positional`), `--mux choices:hc,herdr,tmux,herdr-core`, `--mux-id string`, `--place choices:workspace,tab,hidden`, `--name string`, `--env string` (`repeatable`), `--rescan`, `--base-only`, `--in-shell`, `--no-focus`, `--dry-run`, `--quiet`
- **Positionals:** `1` `ms:launch-repo-target`, `2` `command`, `rest` `file`; `dash1` `command` (falls back to `file` when `--command` is already set), `dash-rest` `file`

### 7.4 `cwf-new` (`modules/cwf/completions/cwf-new.comp`)

- **Flags:** `--repo ms:base-repos-or-dir`, `--host ms:launch-hosts`, `--mux choices:hc,herdr,tmux,herdr-core`, `--mux-id string`, `--place choices:workspace,tab,hidden`, `--launch`, `--pick`
- **Positionals:** `1` `ms:git-branches`

## 8. Verification and test matrix

All tests run in temporary `HOME` / XDG directories with command stubs and disposable git repos — never touching real user configs, real SSH hosts, or real Carapace directories.

| Layer | Suite | Proves |
|---|---|---|
| Candidate helper | `tests/spec/zsh/complete_helper_spec.sh` | Every `ms:*` kind, spaces/apostrophes/colons, missing caches, path-traversal rejection, offline guarantee (stub `ssh`/`hc` never invoked), `--from-carapace` env handling |
| Spec parser & renderer | `tests/spec/zsh/render_completions_spec.sh` | Directive validation, malformed spec rejection, golden outputs for zsh/Bash/Fish/Carapace, `zsh -n` / `bash -n` / `fish --no-execute` syntax checks, atomic staging, `envid` invalidation |
| Zsh native & PTY | `tests/spec/zsh/launch_completions_spec.sh` + `marksharc_completions_spec.sh` | Interactive Tab completion for `marksharc`, `launch-session`, `launch-repo` (including `--host`, `--base-only`, repo-filtered `--worktree`, `host:`), and `cwf-new` (including `--host`) |
| Bash 4.4+ native & PTY | `tests/spec/contract/bash_static_completion_spec.sh` | Readline unquoting, `:@=` reassembly, `marksharc` hierarchy, all launch/cwf flags and dynamic values, Bash 3.2 env-only untouched |
| Fish native | `tests/fish/completions_test.fish` | All four commands loaded from rendered `$cache/completions/fish`, reload path cleanup, parity for `launch-repo --host`/`--base-only`, `cwf-new --host`, `marksharc install`/`update --only` |
| Carapace end-to-end & lifecycle | `tests/spec/contract/carapace_completions_spec.sh` | Real `carapace <cmd> export ...` for all four commands (skipped if `carapace` absent), managed symlink creation, non-MarkSharc conflict preservation, disable pruning, `uninstall` cleanup, `doctor` diagnostics, cache key invalidation, zsh/Bash precedence and `CARAPACE_EXCLUDES` fallback |

## 9. Decision log (DEV-84)

| Decision | Choice | Source |
|---|---|---|
| Command and shell scope | `marksharc`, `launch-session`, `launch-repo`, and `cwf-new` across zsh, Bash 4.4+, Fish, and Carapace | Operator, DEV-84 |
| Specification architecture | Common declarative `.comp` line-directive format rendered by `marksharc render` to all four targets, backed by shared offline helper `core/cli/complete` | Operator, DEV-84 |
| Carapace spec wiring | Manifest-tracked managed symlinks from Carapace's platform specs directory to `$cache/completions/carapace/*.yaml`; never overwrite user files; cleaned up on disable/uninstall; checked by `doctor` | Operator, DEV-84 |
| Delivery structure | Multi-PR: DEV-84 (L8.0 spec/plan PR) followed by DEV-85 (L8.1), DEV-86 (L8.2), and DEV-87 (L8.3) | Operator, DEV-84 |
