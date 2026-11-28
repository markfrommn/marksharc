# MarkSharc Specification

|  |  |
| --- | --- |
| Status | Current-state contract. Describes what the repository contains and how it behaves today. |
| Scope | The framework core, the module contract, configuration, startup, and the `marksharc` command. |
| Companion specs | [BASH-SPEC.md](BASH-SPEC.md) (interactive Bash), [LAUNCH-SPEC.md](LAUNCH-SPEC.md) (launch commands), [COMPLETION-SPEC.md](COMPLETION-SPEC.md) (declarative completions). Each extends the sections it names and wins inside its own subject. |
| Plan | [MARKSHARC-PLAN.md](MARKSHARC-PLAN.md) records delivery order and status. |
| History | [archive/MARKSHARC-SPEC-2026-11-design.md](archive/MARKSHARC-SPEC-2026-11-design.md) is the original design specification. |

MarkSharc is a public, modular shell configuration framework for zsh, fish and Bash on macOS and
Linux. A read-only framework checkout holds the core and the public modules. A user-owned overlay
holds configuration. Rendered and cached state is per host and safe to delete.

## How to use this document

This file is the normative contract. When it disagrees with a page under `docs/`, this file wins
and the page needs a fix.

Section numbers are stable. Code comments and other documents cite them as "spec 6.8". Sections
2, 3, 5, 9, 11 and 12 held design-time history; each is now a pointer to the archive, so the
remaining numbers did not move.

Read one page for the task in hand. Do not load `docs/` as a set, and do not read
`specs/archive/` or the per-unit `specs/DEV-*-PLAN.md` files unless the task is about history.

| Task | Read |
| --- | --- |
| Install, configure or operate a host | [docs/USERGUIDE.md](../docs/USERGUIDE.md) |
| Look up a `marksharc` subcommand or flag | [docs/COMMANDS.md](../docs/COMMANDS.md) |
| Look up a config file, directive or core setting | [docs/CONFIGURATION.md](../docs/CONFIGURATION.md) |
| Look up a module, its options or its commands | [docs/MODULES.md](../docs/MODULES.md) (generated) |
| Shell-specific behaviour | [docs/SHELLS.md](../docs/SHELLS.md); Fish parity in [docs/fish.md](../docs/fish.md) |
| Change the core or trace startup, render or reload | [docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md) |
| Write or change a module | [docs/MODULE-AUTHORING.md](../docs/MODULE-AUTHORING.md) |
| Add a command that changes the caller's shell | [docs/write-once.md](../docs/write-once.md) |
| Add or change a completion | [docs/completions.md](../docs/completions.md), then [COMPLETION-SPEC.md](COMPLETION-SPEC.md) |
| Add a multiplexer or change titles and forwarding | [docs/MUX-ADAPTERS.md](../docs/MUX-ADAPTERS.md) |
| Launch commands | [docs/launch.md](../docs/launch.md), then [LAUNCH-SPEC.md](LAUNCH-SPEC.md) |
| Version managers and mise | [docs/mise.md](../docs/mise.md) |
| Write or run tests | [tests/README.md](../tests/README.md) |
| Tools, checks and pull requests | [docs/DEVELOPING.md](../docs/DEVELOPING.md) |
| Why a rule exists | [docs/DESIGN-RULES.md](../docs/DESIGN-RULES.md) |

## 1. Purpose and ground rules

MarkSharc gives one person the same shell on every host, in every shell they use, and gives AI
agents a complete and quiet environment.

- macOS and Linux are both first class. Native Windows is not a target.
- zsh 5.9+, fish 4.x and Bash 4.4+ are interactive targets. Bash 3.2 gets the environment only.
- Day-to-day shell use needs only the native shell. The `marksharc` command and the write-once
  executables need zsh.
- Functional areas are modules. A module can contribute PATH entries, variables, aliases,
  functions, executables, completions and tool setup.
- Portable code and personal configuration are separate. Nothing personal is in the framework.
- No agent configuration is committed (`AGENTS.md`, `CLAUDE.md`, `.claude/`, `.agents/`, `.omp/`,
  `.codex/`, `.cursor/`, `.vscode/`, `.cwf*`, `docs/COMMON-WORKFLOW.md`).

## 2. Original environment

Retired. See section 2 of the [archived design](archive/MARKSHARC-SPEC-2026-11-design.md).

## 3. Usage evidence

Retired. See section 3 of the [archived design](archive/MARKSHARC-SPEC-2026-11-design.md).

## 4. Scope

In scope and delivered: the zsh, fish and Bash cores; the public modules listed in
[docs/MODULES.md](../docs/MODULES.md); the installer and uninstaller, including coexist mode;
declarative environment rendering; write-once commands and shims; bootstrap, update and explicit
installers; sync, notify, the sync timer and SSH push; multiplexer adapters; launch commands;
declarative completions; the opt-in mise and Carapace modules.

Not delivered: the `cloud` module carries only the krew installer. A Go helper binary remains an
idea only.

Out of scope by decision: any network access or installation during shell startup, other than the
notify fetch in 6.14; a plugin manager; Oh-My-Zsh and Powerlevel10k; native zsh history as the
primary store when atuin is present; csh.

## 5. Research conclusions

Retired. See section 5 of the [archived design](archive/MARKSHARC-SPEC-2026-11-design.md). The
decisions it drove are the rules in section 10.

## 6. Architecture

### 6.1 Three layers

| Layer | Location | Owner | Contents |
| --- | --- | --- | --- |
| Framework | `$MARKSHARC_HOME`, default `~/.local/share/marksharc` | The repository. Never written at run time. | Core loaders, public modules, the `marksharc` command, templates, tests, docs. |
| Overlay | `$MARKSHARC_CONFIG`, default `~/.config/marksharc` | The user. | Module selection, options, per-host files, private modules, provider files, package bundles, host inventory, native hooks. |
| Cache and state | `~/.cache/marksharc/` and `~/.local/state/marksharc/` | The machine. Safe to delete. | Rendered env, cached tool init, generated completions and shims, compdump, plugin clones, sync status, the generated `ZDOTDIR`, the install manifest and dotfile backups. |

All three honour the XDG variables. Per-host cache lives under `~/.cache/marksharc/<host>/`,
where `<host>` is the short host name, because home directories are sometimes shared between
hosts. Plugin clones are shared in `~/.cache/marksharc/plugins/`.

### 6.2 Framework repository layout

```text
install.sh               Day 0 installer (POSIX sh)
bin/marksharc            command entry point: dispatches to core/cli/<command>
core/
  zsh/                   zshenv.zsh zprofile.zsh zshrc.zsh zlogin.zsh phase.zsh finalize.zsh reload.zsh
    lib/                 session, facts, envid, modules, render*, rendered, cache, directives, shims, …
  bash/                  env.bash bashrc.bash interactive.bash and their libraries
  fish/                  marksharc.fish and lib/
  cli/                   one executable per subcommand, plus shared *-lib.zsh files
  completions/           marksharc.comp
modules/<name>/          public modules (6.4)
templates/overlay/       skeleton copied to a new overlay
tests/                   ShellSpec suites, fishtape units, lint, e2e scripts, support tools
docs/                    user and developer documentation
specs/                   this file, companion specs, the plan, per-unit plans, archive/
memory/                  shared workflow memory index
```

`core/cli/` holds `bootstrap`, `complete`, `doctor`, `hosts`, `install`, `module`, `notify`,
`push`, `reload`, `render`, `sync`, `uninstall`, `update` and `version`. `notify` and `complete`
are internal workers, not user commands.

`.gitignore` keeps agent configuration and `.cwf*` out of the repository, with that block last.
`tests/spec/repo/hygiene_spec.sh` enforces it.

### 6.3 Overlay layout

```text
~/.config/marksharc/
  config.conf                 modules, options, and env/path/alias/tiers lines
  hosts/<host>.conf           per-host additions and overrides, read after config.conf
  hosts.conf                  host inventory for push and launch
  modules/<name>/             private modules, same contract as public ones
  local/post.zsh              native code run at the end of interactive startup
  local/post.bash             the same for Bash 4.4+
  local/post.fish             the same for fish
  providers/*.conf            provider definitions for the cc-providers module
  packages/                   *.Brewfile, *.apt and *.dnf package lists for bootstrap
```

The framework never edits the overlay, with one exception: `marksharc module enable|disable`
and `marksharc hosts add|remove|populate` edit the files they name. A private module with the
same name as a public one replaces it.

Bootstrap reads `packages/*.Brewfile` as data: each line is `brew "name"` or `cask "name"`.
`.darwin.Brewfile` and `.linux.Brewfile` suffixes select one platform, and casks apply only on
macOS. On Linux, `packages/*.apt` and `packages/*.dnf` list one package per line.

### 6.4 Module contract

A module is a directory. Every file is optional except `module.conf`.

```text
modules/<name>/
  module.conf                       metadata and declarative lines (6.5)
  env.zsh  env.bash  env.fish       native env code, only where directives cannot express it
  init.zsh  init.bash  init.fish    interactive-only setup
  functions/zsh/<fn>                autoloaded zsh functions
  functions/bash/<fn>.bash          Bash functions, sourced explicitly
  functions/fish/<fn>.fish          fish functions, autoloaded
  bin/<command>                     write-once executables, on PATH in every shell (6.11)
  completions/zsh/_<cmd>            static native completions, also bash/<cmd>.bash, fish/<cmd>.fish
  completions/<cmd>.comp            declarative completion spec (6.9)
  zsh.plugins  fish.plugins         pinned third-party plugins (6.8)
  installers/<name>                 scripts registered with an `installer` line
  tests/                            ShellSpec specs and fishtape tests for this module
```

Rules:

- A module loads only if it is enabled, its `requires` lines are satisfied and it supports the
  current OS. A missing optional tool never breaks startup.
- With no `module <name>` line in the overlay, every module present is enabled except those
  marked `off`. As soon as one plain `module <name>` line exists, only named modules load.
- Sourcing a module twice is safe.
- Public modules contain no user, host, organisation or site names and no home paths. Such
  values arrive as options.
- A module declares its options with defaults. The overlay sets them. An option is read as
  `$_ms_opt_<module>_<key>`, with every non-alphanumeric character replaced by `_`.
- zsh module files and `local/post.zsh` run at top level at startup and inside the `marksharc`
  function on reload. A declaration at file scope therefore says `-g`.
  `tests/support/function-safe-check.py` enforces this. Cached third-party tool init output is
  the tool's own code and is not checked.
- Modules load in `order` (0–99, default 50), then by name. Bands: 0–9 core, 10–19 package
  managers, 20–69 general, 70–79 completion, 80–89 prompt, history and navigation, 90–99 modules
  that must see every earlier module's hooks, with line-editor plugins that must load last at 95
  and above.

### 6.5 Directive vocabulary

One line-oriented format serves module metadata, overlay configuration and the write-once
protocol. Lines are split with shell word rules. `#` starts a comment. A value may use `~` and
`$NAME` or `${NAME}` references. There is no command substitution, and nothing is evaluated.

| Directive | Where | Meaning |
| --- | --- | --- |
| `describe <text>` | module | One-line description. |
| `order <n>` | module | Load order. |
| `requires command <name>…` | module | Skip the module when a command is missing. |
| `requires os darwin\|linux` | module | Restrict the module to an OS. |
| `option <key> <default> <text>` | module | Declare an option. |
| `env <NAME> <value> [when …]` | module, overlay | Export a variable. |
| `path <tier> <dir> [when …]` | module, overlay | Add a directory to a PATH tier (6.7). |
| `alias <name> <value> [when …]` | module, overlay | Define an interactive alias. |
| `completion <cmd> <generator…> [when …]` | module | Generate a zsh completion file at render time. |
| `completion-bash <cmd> <generator…> [when …]` | module | Generate a Bash completion file on explicit renders. |
| `package <manager> <name>` | module, overlay | Declare a package for `bootstrap`. Managers: `brew`, `cask`, `apt`, `dnf`. |
| `update <label> <command…>` | module, overlay | Register an argv step for `marksharc update`. |
| `installer <name> <script>` | module, overlay | Register an executable for `marksharc install`. |
| `module <name> [off]` | overlay | Enable or disable a module. |
| `set <module>.<key> <value>` | overlay | Set an option or a core setting. |
| `tiers <tier>…` | overlay | Override the PATH tier order. |
| `plugin <name> <git-url> <sha> [shell <s>] [kind source\|fpath]` | `zsh.plugins`, `fish.plugins` | Pin a third-party plugin (6.8). |
| `host <name> [<ssh-target>]` | `hosts.conf` | One host for push and launch. |

Relative `update` commands beginning `./` and relative `installer` paths resolve from the
declaring module directory or the overlay root.

Guards: `when command <c>`, `when dir <d>`, `when file <f>`, `when os <o>`, `when host <h>`.
Several guards on one line must all hold. `os` and `host` guards are settled at render time.
`command`, `dir` and `file` guards are emitted as cheap runtime tests, so installing a tool takes
effect in the next shell without a render.

Core settings that belong to no module use the same `set` line: `core.dot_in_path`,
`sync.repos`, `sync.check_hours`, `sync.timer_minutes`, `sync.push_timeout`, `sync.push_parallel`,
`doctor.startup_ms` and `doctor.startup_timeout_ms`.

The vocabulary is closed. Anything it cannot express is native code in `env.<shell>` or
`init.<shell>`.

### 6.6 Session classes and startup phases

Login, interactive and agent are independent facts. The core sets `MARKSHARC_SESSION`, a
shell-local value that is never exported:

| Value | Condition | Gets |
| --- | --- | --- |
| `agent` | An agent or editor-injection marker is set, non-empty and not `0` | env phase only, no output |
| `interactive` | No marker, the shell is interactive, and stdin and stdout are terminals | env phase, then init phase |
| `batch` | Everything else | env phase only, no output |

The default markers are `CLAUDECODE`, `AI_AGENT`, `CODEX_SESSION_ID`, `CODEX_SANDBOX`, `OPENCODE`,
`GEMINI_CLI`, `CURSOR_AGENT`, `COPILOT_CLI`, `KILO_CLI_MODE`, `VSCODE_INJECTION` and
`VSCODE_NONCE`. `set agent.markers` replaces the list.

Phases:

1. **env** runs in every shell and every mode: host facts, exports, PATH. No output, and no
   forks beyond cached files.
2. **init** runs in interactive sessions only: options, hooks, key bindings, aliases, autoload
   paths, completion, plugins, cached tool init, then the overlay's `local/post.<shell>`.

Host facts come from shell built-ins and are exposed as `MARKSHARC_OS` (`darwin` or `linux`),
`MARKSHARC_ARCH`, `MARKSHARC_HOST` (short name) and `MARKSHARC_DISTRO`.

Wiring per shell:

| Shell | Installed stub | Then |
| --- | --- | --- |
| zsh | `~/.zshenv` sets `MARKSHARC_HOME` and sources `core/zsh/zshenv.zsh` | The env phase sets `ZDOTDIR` to `~/.local/state/marksharc/zdot`, which holds four one-line stubs. `.zprofile` re-asserts PATH after macOS `path_helper`. `.zshrc` runs the init phase. |
| zsh, coexist | One marked source line in `~/.zshenv` and one in `~/.zshrc` | The same phases run from stubs under `~/.local/state/marksharc/coexist/`. `ZDOTDIR` is not changed. |
| Bash | `~/.bashrc` and `~/.bash_profile` source `core/bash/bashrc.bash` | The rendered `env.bash` in every mode, and native init when eligible (6.16). |
| fish | `~/.config/fish/conf.d/00-marksharc.fish` sources `core/fish/marksharc.fish` | The rendered `env.fish`, and init when the session is interactive. |

The zsh env phase sets shell-local `skip_global_compinit=1`, so a distribution's global rc file
cannot run a competing `compinit`. The `completion` module is the only completion initializer.

The env phase exports `MARKSHARC_ENV=<id>`, a fingerprint of every core, module and overlay
file. A non-login child shell that inherits a matching value skips the export and PATH work.
Login shells and reloads always rebuild.

`ZDOTDIR` takeover is deliberate: it keeps an installer's edits to `~/.zshrc` from changing the
shell silently. `marksharc doctor` lists foreign lines in the unread dotfiles.

A broken module does not take the shell down. Each module file is sourced inside an `always`
block. A non-interactive shell first proves the file survives in a subshell and skips it when it
does not.

### 6.7 PATH composition

Modules and the overlay add directories to named tiers. The builder concatenates tiers in order,
keeps inherited entries it does not manage, and removes duplicates.

| Tier | Typical contents |
| --- | --- |
| `first` | Explicit user overrides. Fixed at the front. |
| *(inherited, ahead of any managed entry)* | Virtualenv and tool activations |
| `manager` | Version-manager directories: gvm, nvm, pyenv, and mise shims |
| `brew` | Homebrew `bin` and `sbin` |
| `local` | `/usr/local`, `/opt` and similar |
| `system` | `/bin`, `/usr/bin`, `/sbin`, `/usr/sbin` |
| `user` | `~/bin`, `~/.local/bin`, Go, Cargo, bun, pnpm, module `bin/` directories and the shim directory |
| `app` | Application directories such as CUDA and LM Studio |
| *(inherited, after a managed entry)* |  |
| `last` | `.` when `core.dot_in_path` is on and the user is not root. Fixed at the end. |

The default order is `manager brew local system user app` on macOS and
`manager brew system user app local` on Linux. A `tiers` line lists an order; any tier it omits
follows in the default order. `manager` is ahead of `brew` in every session class, so Homebrew's
`go` or `node` never shadows the manager's choice.

The builder records the entries it manages. On reload it drops managed directories that have
vanished and leaves everything else alone.

### 6.8 Plugins

There is no plugin manager. A `plugin` line in a module's `zsh.plugins` or `fish.plugins` names
a git URL and a commit. `install.sh` and `marksharc update` clone pins into
`~/.cache/marksharc/plugins/<name>@<sha>/`. At startup the loader sources the plugin's entry file
or adds its directory to `fpath`. A missing clone is skipped silently and reported by `doctor`.
The plugin loader never touches the network.

Pinned today: fzf-tab, zsh-autosuggestions and zsh-syntax-highlighting for zsh; nvm.fish and
fzf.fish for fish. ble.sh for Bash is pinned in `modules/line-editor-ble/ble.pin` and built by an
explicit installer.

### 6.9 Completion

- zsh runs a full `compinit -i -d` with its dump in the cache, rebuilt when `fpath` changes.
  Insecure directories are excluded silently. Neither `-C` nor `-u` is used.
- Generated completions are written to cache files by `render` and `update`, never evaluated at
  startup.
- `completion-fzf-tab` and `completion-carapace` are alternative zsh completion interfaces.
  Enabling Carapace disables fzf-tab unless the overlay forces both.
- Declarative `.comp` specs render into native zsh, Bash 4.4+, Fish and Carapace YAML under
  `~/.cache/marksharc/<host>/completions/`, backed by the offline helper `core/cli/complete`.
  The full contract is [COMPLETION-SPEC.md](COMPLETION-SPEC.md).

### 6.10 Caching, reload and verbosity

- `_ms_init_cached [-x <NAME>] <tool> <command…>` stores a tool's init output, keyed on the
  binary's path, its mtime and the arguments, and sources the file. With `-x` it caches the
  output as the value of an exported variable. A cache hit forks nothing.
- `marksharc reload` re-renders if inputs changed, then rebuilds the env and re-runs init in the
  current shell. `cs` and `li` are verbose reloads; `li` also re-runs the login-only steps.
- Startup prints nothing. `MARKSHARC_VERBOSE=1` prints the module trace, skipped modules with
  reasons and per-module timings on stderr.
- A failed render keeps the last good rendered environment active.

### 6.11 Write-once commands

A complex command is one executable zsh script in a module's `bin/` directory. It runs in its
own process, so it cannot leak options, variables or a changed directory into the caller.

When a command must change the caller's state, a native wrapper function sets
`MARKSHARC_DIRECTIVES` to a temporary file, runs the executable with the terminal attached, then
applies the file:

| Directive line | Effect in the calling shell |
| --- | --- |
| `cd <dir>` | Change directory |
| `pushd <dir>` | Push onto the directory stack |
| `setenv <NAME> <value>` | Export a variable |
| `unsetenv <NAME>` | Unset a variable |
| `exit [<status>]` | Exit the calling shell after the remaining directives are applied |

Fields are tab-separated. Tab, newline and `%` inside a value are percent-encoded. The applier
never evaluates text as code. A command that needs no state change has no wrapper.

Generated commands are **shims**: small executables in `~/.cache/marksharc/<host>/bin/`, which
is on PATH. Provider wrappers and Herdr session commands are shims, so they work from every
shell and from agents. A shim never embeds a secret; it reads the provider file when it runs.

### 6.12 History

- `history-atuin` initialises atuin, binds Ctrl-R and Up, keeps in-memory history for `!!`, and
  defines `history` and `h` over `atuin history list`.
- `history-native` is the fallback without atuin: one history file under the state directory.
- `import-legacy-history` is a one-shot importer of legacy zsh history into atuin.

### 6.13 Multiplexer integration

Multiplexers sit behind an adapter interface in the `mux` module. More than one adapter can be
active. Adapters exist for tmux, the Herdr TUI, Herdr Core, WezTerm and a plain terminal.

| Operation | Purpose |
| --- | --- |
| `detect` | Is this multiplexer present in the current session? |
| `set_titles` | Push workspace, tab and pane titles |
| `refresh_env` | Re-import `SSH_AUTH_SOCK`, `DISPLAY` and similar from the client |
| `sessions` | List sessions, for generated attach shims |
| `supports`, `current`, `instances`, `machines`, `launch` | Open a new terminal ([LAUNCH-SPEC.md](LAUNCH-SPEC.md) 5.4) |

The `titles` module computes the strings once and hands them to every active adapter. The `x11`
module asks the active adapter for the client `DISPLAY` first.

### 6.14 Sync across hosts

A host has two checkouts, the framework and the overlay, plus any listed in `sync.repos`.
Everything is fast-forward only.

- `marksharc sync` fetches and fast-forwards each checkout, reports dirty, ahead, diverged,
  detached or unavailable trees without touching them, and refreshes plugin pins.
- **Notify:** an eligible interactive zsh or Bash shell starts a detached fetch when the last check is
  older than `sync.check_hours` (default 12). A later shell prints one line when the host is
  behind. This is the only exception to the offline startup rule. `MARKSHARC_NOTIFY=0` disables
  it for a session.
- **Timer:** `marksharc sync timer on` installs a launchd agent or a systemd user timer that
  runs `marksharc sync --auto`.
- **Push:** `marksharc push` runs `marksharc sync` over SSH on the hosts in `hosts.conf`, in
  parallel, and prints a result table.

### 6.15 Day 0 and Day 2

| Command | Purpose |
| --- | --- |
| `install.sh` | Check for zsh and git, find or clone the framework, create or link the overlay, back up startup files and write the stubs, fetch plugin pins, then render. |
| `marksharc bootstrap` | Install packages declared by enabled modules and overlay bundles. Homebrew through a temporary Brewfile; apt or dnf after confirmation. |
| `marksharc update` | Sync repositories, refresh plugin pins, run module and overlay update steps, then render. Continues after a failed step and reports each result. |
| `marksharc install <name>` | Run one registered installer script. |
| `marksharc doctor` | Read-only health report: stubs and links, stale environment, missing commands for modules the overlay names, plugin clones, repository state, foreign dotfile lines, duplicate PATH entries, and interactive startup time against a budget. |
| `marksharc module list\|enable\|disable` | Inspect and edit module selection in the overlay. |
| `marksharc uninstall` | Restore the backed-up dotfiles and remove the stubs. `--purge` also removes cache, state and an installer-made clone. The overlay is never removed. |

Every installer and uninstaller check runs before the first change. The install manifest in the
state directory records what was replaced.

### 6.16 Interactive Bash

Bash 4.4+ gets substantially the same public interactive behaviour as zsh. Bash 3.2 keeps the
environment only. An older Bash never executes a newer one automatically. Init requires an
interactive Bash with terminals on stdin and stdout and no agent marker; `BASH_ENV`, batch, agent
and no-terminal invocations stay env-only. `BASH_ENV` is exported only when `agent.bash_env` is
on. The optional `line-editor-ble` module adds suggestions, highlighting and menu completion;
Readline is the fallback. The complete contract is [BASH-SPEC.md](BASH-SPEC.md).

## 7. Module catalog

[docs/MODULES.md](../docs/MODULES.md) is the catalog. It is generated from `module.conf` and each
module's files by `tests/support/gen-module-reference`, and `tests/spec/repo/docs_spec.sh` fails
when it is out of date. Do not maintain a second list here.

Private modules live in an overlay and follow the same contract. None is described in this
repository.

## 8. Testing and quality

| Layer | Tool | What it proves |
| --- | --- | --- |
| zsh units | ShellSpec 0.28.1, pinned | Function behaviour in a temporary HOME with stubbed commands |
| Cross-shell contract | ShellSpec under `sh`, launching zsh, fish and Bash | The same PATH and env in every shell, silent batch and agent startup, idempotent re-source, no writes outside cache and state |
| fish units | fishtape 3.0.1, pinned | Native fish functions |
| Install | ShellSpec under `sh`, and `tests/e2e/install-e2e.sh` | Install, uninstall and a first shell in a fresh HOME |
| Lint | `zsh -n`, shellcheck, `fish --no-execute`, `fish_indent --check` | Syntax and formatting |
| Repository | ShellSpec under `sh` | The runner, lint routing, the contract inventory, hygiene, and the documentation checks |
| CI | GitHub Actions on `macos-latest` and `ubuntu-latest` | All of the above on every pull request |

Rules:

- Tests never install their runner, touch the real HOME or call real services.
- Every example gets its own HOME, XDG directories and command stubs.
- "90% coverage" means 90% of the contract inventory in `tests/README.md`. Line coverage is not
  claimed.
- Every behaviour change ships with a spec.

## 9. Migration map

Retired. See section 9 of the [archived design](archive/MARKSHARC-SPEC-2026-11-design.md).

## 10. Design rules

1. **Match capabilities, not file trees.** A working command, a discoverable binary and the
   right exported variable matter more than identical structure across shells.
2. **Let each shell be itself.** Share data and executables; write interactive behaviour natively.
3. **Login, interactive and agent are separate questions.** Env belongs to every mode. Prompting,
   history tools, titles and greetings need an eligible interactive session.
4. **Startup is quiet, fast and offline**, except for the detached, throttled notify fetch and
   its later notice in 6.14. Installs and pulls are explicit commands.
5. **Reload is safe.** Keep inherited paths, deduplicate, replace named hooks, track what you
   generated.
6. **Data stays data.** Preserve spaces and metacharacters. Apply directives; never evaluate
   generated text, except a tool's own documented shell integration.
7. **Scope mutable state.** Per-host cache, per-shell cache files, connectivity checks on cached
   sockets.
8. **Fail before destructive work.** Validate, confirm, and let the owning tool delete.
9. **Optional means optional.** A missing tool or directory never breaks startup.
10. **Portable code holds no personal values.** Names, hosts, organisations and paths arrive
    from the overlay.
11. **The framework is read-only on a host.** Configuration goes in the overlay; state goes in
    the cache and state directories.
12. **Generated commands are shims on PATH,** so every shell and every agent can run them.
13. **Prove behaviour without touching real services.** Temporary HOME, stubs, disposable
    repositories.
14. **Do not canonise old bugs.** Use the old setup to find intent, then implement the useful
    contract.

[docs/DESIGN-RULES.md](../docs/DESIGN-RULES.md) explains each rule and names the check that
enforces it.

## 11. Risks and open questions

Retired. See section 11 of the [archived design](archive/MARKSHARC-SPEC-2026-11-design.md).
Open work is tracked as issues, not here.

## 12. Decision log

Retired. See section 12 of the [archived design](archive/MARKSHARC-SPEC-2026-11-design.md). The
companion specs keep their own decision logs.
