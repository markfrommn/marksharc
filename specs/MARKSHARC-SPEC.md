# MarkSharc Specification

| | |
|---|---|
| Status | Design approved 2026-11-20; implementation in progress |
| Source issue | DEV-33 "Mark Sharc - Planning Kickoff" (Linear, project MarkSharc) |
| Target repo | `markfrommn/marksharc` (local checkout `/data/work/mark/marksharc`) |
| Home | `marksharc/specs/` is the authoritative home; `mark-desktop-files/specs/` retains a historical copy |
| Companion | [MARKSHARC-PLAN.md](MARKSHARC-PLAN.md) |
| Interactive Bash | [BASH-SPEC.md](BASH-SPEC.md) covers the runtime, caller-state wrappers, tool integrations and version managers. Native module parity and final acceptance are tracked in DEV-82 and DEV-83. |
| Related | [LAUNCH-SPEC.md](LAUNCH-SPEC.md) specifies the launch commands and extends sections 6.11, 6.13, and 7.1 |

MarkSharc is a public, modular shell configuration framework for zsh and fish, with environment parity for bash. It replaces the shell support in `mark-desktop-files`. This document records what exists today, what the history says is used, what is in and out of scope, and the design of the replacement as if built in a fresh repo.

## 1. Goals

Primary goals, from DEV-33:

1. Move the shell configuration out of `mark-desktop-files` into a repo that can be public and shared.
2. Support zsh and fish with real parity, and leave room for bash.
3. Be modular ("plugin light") around functional areas. A functional area can contribute path composition, functions and aliases, completions, and tool initialization.
4. Split portable configuration cleanly from per-user configuration, so that goal 1 stays sustainable for the author and usable by others.

Secondary goals:

- Light but growing unit test support.
- Write the complex commands once and run them from every shell.
- Lean on cross-shell tools (atuin, starship, fzf, zoxide; Carapace as an option).
- Clean Day 0 bootstrap and Day 2 maintenance on macOS and Linux.
- A modern, colourful, interactive experience.
- Stronger integration between the shell and AI agents, in both directions.

Requirements added during the scope interview:

- **macOS and Linux are both first class.** Native Windows is not a target.
- **Cross-host sync is critical.** The author works on 3–4 hosts regularly and about six more in a given month. Pull must be easy; push (even as a poll-pull) is wanted.
- **Multiplexer integration** must be a designed seam. Use has moved from tmux to the herdr TUI to the herdr app in six months, and Rex or Orca may follow.
- **Installers and updaters leave the core.** Explicit Day 0 and Day 2 commands replace install hints, startup-time pulls, and `bin/do_updates.sh`.

Ground rules:

- Day-to-day use requires only native shell. Tooling commands (`marksharc …`) require zsh.
- Developer infrastructure (tests, CI) may use Python as a helper, kept to one common solution.
- Nothing about AI agent configuration is committed to the public repo.

## 2. Current environment

### 2.1 Structure

| Area | Today |
|---|---|
| Entry chain (zsh) | `~/.zshenv` sets `ZDOTDIR` to `config/zsh` → `.zshrc` / `.zlogin` → `zsh.zshrc` / `zsh.login` → `zsh.common` (host facts) → `zsh.functions` (helpers, loads `functions/*.zsh`) → `build_path` → `zsh.zshrc.interactive` (925 lines) → `zsh.zshrc.ohmyzsh` → `etc/zsh.zshrc.user` |
| Idempotency | PID sentinels (`zshrc_done`, `_mdf_*_done`), force flags (`zdo_zshrc`, `zdo_login`, `zdo_functions`), reload aliases `cs` and `li` |
| Host facts | `ostype`, `hwtype`, `osrel`, `shorthost`, `hostbase`, `distro`, `dname` (site: iserver, plesk-phorn, manifest, google, or DNS domain), all computed with forks |
| PATH | `build_path` (306 lines): opt dirs × bin subdirs, X and Solaris quirk dirs, Go/GVM/Cargo, CUDA, LM Studio, `.` for non-root, Homebrew first, inherited entries preserved, managed entries tracked |
| Tool init | brew, nvm + `.nvmrc` hook, gvm + `go.mod` hook, uv or pyenv, rbenv, pnpm, bun, envman, gcloud SDK, kubectl, cwf, herdr, zoxide, starship, atuin, p10k (loaded, then replaced by starship) |
| Oh-My-Zsh | About 25 plugins chosen at startup from installed commands; fzf-tab as a custom plugin; `git pull` of custom plugins and p10k on every interactive start; three custom themes |
| Completion | `compinit -D`, a block of zstyles, fzf-tab, OMZ plugin completions, generated completions evaluated at startup (herdr, kubectl, cwf) |
| History | Native zsh history with `sharehistory`; a per-directory history plugin until 2026-11-07; atuin since then |
| Functions | 27 files in `config/zsh/functions/` (see 3.2) |
| Fish | `config.fish`, `common.fish`, `functions.fish`, `interactive.fish`, 20 function files; fisher plugins fzf.fish, nvm.fish, bass, fish-gvm |
| bash, csh | `.bashrc` echoes "In .bashrc..." and initialises atuin; `.profile`, `.cshrc`, `.login` are legacy |
| Tests | ShellSpec 0.28.1 zsh suite (9 specs) under `tests/shell`; `config/fish/tests/test_parity.py` |
| Day 0 / Day 2 | `bin/bootstrap-mac.sh`, `bin/bootstrap-mac-2.sh`, `scripts/basepkgs.sh`, `bin/do_updates.sh`, `bin/go_installs.sh`, `bin/uv_setup.sh`, `mdflinks*.tar` link bundles, `mdf-sync` + `link-cleanup` |

### 2.2 Problems the redesign must fix

- **Startup does network and install work.** OMZ plugin and p10k pulls, theme link repair, and install hints run on every interactive start.
- **Startup is chatty.** Path, Go, uv, OMZ plugin lists, and "Clearing sharehistory" print unconditionally.
- **Unread dotfiles collect installer edits.** `~/.zshrc` and `~/.zprofile` hold PATH lines from pnpm, Docker Desktop, JetBrains Toolbox, Codex, and VoiceStudio. Neither file is read, because `ZDOTDIR` points elsewhere.
- **State lives in the repo.** `.zcompdump*`, `.zsh_history`, and `.zsh_sessions` are written into `config/zsh` and hidden by `.gitignore`.
- **Personal and portable content are mixed.** Hard-coded `/Users/mark`, `/data/work/convoy`, GitHub org lists, site aliases, and provider files sit beside general code.
- **Agents get a leaky environment.** In this session every command printed `setValueForKeyFakeAssocArray:27: command not found: _encode`, and `GOROOT` pointed at a gvm Go while Homebrew's `go` was first on PATH.
- **The ps helpers are wrong.** `pss foo` greps for `foo|PID`, so it matches unrelated processes; the macOS and Linux variants have drifted.
- **Tool updates are scattered** across shell startup, `do_updates.sh`, and tool-specific commands.

## 3. Usage evidence

### 3.1 Corpus

| Source | Host | Range | Human commands |
|---|---|---|---|
| atuin (`author = mark`) | Mac | 2026-11-07 → 11-20 | 4,062 |
| `~/.zsh_history`, `~/.zhistory`, `$ZDOTDIR/.zsh_history` | Mac | 2026-08-04 → 11-20 | 3,635 |
| `~/.cache/zsh-directory-history` (465 files) | Mac | 2026-08-19 → 11-07 | 7,145 |
| `.zsh_history-sol`, `.zhistory-sol`, directory history | sol (Linux) | 2020-09 → 2026-11-20, mostly 2026 | 9,715 |

After de-duplication that is about 8,200 unique commands on the Mac and 7,700 on sol. Agent-run commands in atuin (9,350 claude-code, 2,650 codex) are excluded. Keybinding-driven features (Ctrl-R, Tab menus, Alt-arrows) leave no trace in history; those were settled by interview.

### 3.2 What is used

Counts are Mac / sol.

| Feature | Count | Reading |
|---|---|---|
| OMZ aliases and functions | 568 defined, ~0 used | No `gst`, `gco`, `take`, `x`. Only the `ls` and `grep` colour wrappers fire. |
| `git` with plain subcommands | 3,867 / 1,843 | No git aliases. |
| `cwf`, `cwf-new`, `gwt-clean` | 473, 317, 106 / 240, 217, 38 | Core workflow. |
| `claudek`, `claudez`, `collie-default` | 120, 70, 63 / 79, 61, 30 | Generated wrappers are heavily used. |
| `cd`, `pushd`, `dirs`, `popd` | 504, 227, 114, 44 / 400, 121, 48, 1 | The directory stack is the navigation model. |
| `z` (zoxide) | 1 / 0 | Initialised everywhere, unused. Kept on by choice. |
| `fg` with `emacs -nw` | 436, 409 / 26, 238 | Suspend and resume editing. |
| `history` (mostly piped to `egrep`) | 151 / 47 | A list-style history command is still wanted. |
| `cs`, `li` | 38, 37 / 22, 26 | Reload in place is a real modality. |
| `more`, `less`, `glow`, `bat` | 161, 111, 70, 52 / 129, 55, 16, 29 | |
| `pss` vs the other six ps helpers | 22 vs 0 / 27 vs 0 | |
| `ll`, `la`, `dir`, `lf`, `lsf` | ≤2 each / ≤5 each | Plain `ls` is 1,003 / 767. |
| `nvm`, `uv`, `gvm`, `pyenv`, `rbenv` | 33, 65, 5, 0, 0 / 9, 42, 33, 8, 0 | |
| `docker`, `brew`, `apt`, `sudo` | 59, 235, 0, 40 / 178, 218, 76, 357 | Linuxbrew is in real use. |
| `kubectl`, `gcloud`, `aws`, `helm` | 3, 0, 0, 0 / 0, 2, 0, 0 | |
| `ssh-add`, `xauth`, `tmux` | 5, 17, 7 / 22, 13, 10 | |
| `run-fish`, `repo-sync`, `diffcp` | 5, 8, 19 / 6, 2, 2 | |
| `mdf-sync`, `fix-tmux`, `cleanup-docker` | 0, 1, 0 / 1, 2, 1 | |
| CVS, Perforce, sandcat, gam, `h`, `j`, `mroe` | 0 / 0 | |

## 4. Scope

### 4.1 Included now (pre-migration and MVP)

- zsh on macOS and Linux, lifted into the module structure.
- The private overlay, hosted in `mark-desktop-files/marksharc/`.
- Removal of Oh-My-Zsh, keeping four behaviours natively: the fzf-tab completion menu, Alt-arrow directory navigation, coloured man pages, and command-not-found suggestions.
- starship as the only prompt.
- atuin as the only history store, a `history` command over it, and a one-time import of the legacy history files.
- Version managers: nvm with the `.nvmrc` hook, gvm with the `go.mod` hook, uv preferred over pyenv, pyenv as fallback. Paths for bun, pnpm, Go, and Rust.
- An opt-in `mise` module takes over the node, Go, Python, and Ruby tools named by each host, with nvm, gvm, and pyenv preserved as the fallback.
- zoxide, enabled.
- System helpers: ssh-agent setup and cleanup, `fix-tmux`, X11 DISPLAY inference, docker helpers.
- All seven ps helpers and the `ls` alias family, fixed and identical on both platforms.
- sandcat, gam, and envman, in the overlay.
- Workflow modules. Generic ones are public and configurable (`gwt-clean`, titles, provider wrappers, herdr sessions, a `cwf` module, `repo-sync`). Convoy-specific logic and values are private.
- Quiet startup; `cs` and `li` are chatty reloads.
- `marksharc sync` (pull, plus a throttled "you are behind" notice) and `marksharc doctor`.
- `.` on PATH stays for the author through an overlay option; it is off in the public defaults.

### 4.2 Modernization (planned, after MVP)

- Declarative env rendered per shell.
- Bash env-only parity, before fish.
- Write-once commands as zsh executables, with native wrappers and generated shims.
- `marksharc bootstrap`, `update`, and `install`: declared packages, one updater, explicit installers.
- A multiplexer adapter layer (tmux, herdr, WezTerm, plain terminal), with mux-aware X11.
- zsh-autosuggestions and zsh-syntax-highlighting.
- ps and ls helpers backed by procs and eza when installed.
- A coherent colour baseline (vivid, bat as man pager, delta, fzf previews).
- Carapace as an opt-in completion module, evaluated without fzf-tab.
- Push sync: a poll-pull timer and an ssh fan-out.
- Launch commands: `launch-session`, `launch-repo`, and `cwf-new` in a launched terminal, over the multiplexer adapters ([LAUNCH-SPEC.md](LAUNCH-SPEC.md)).
- Fish, brought forward onto the same structure.
- Full interactive Bash 4.4+, with environment-only fallback on older Bash and no
  automatic shell replacement. The approved design and delivery boundaries are in
  [BASH-SPEC.md](BASH-SPEC.md); runtime delivery is pending DEV-80–DEV-83.

### 4.3 Maybe later

- A cloud and Kubernetes module (kubectl, krew, kubectx, gcloud, aws, helm).
- A coexist install mode that does not take over `ZDOTDIR`.
- A generic `AGENTS.md` / `CLAUDE.md` for the public repo.
- A Go helper binary for hot-path work.

### 4.4 Planned abandonment

- Oh-My-Zsh, Powerlevel10k, the three custom OMZ themes, `etc/zsh_plugins.txt`.
- The per-directory history plugin and native zsh history files.
- Solaris, SunOS, FreeBSD, Ascend, and iserver branches; X and OpenWindows path dirs; quirk dirs; legacy MANPATH dirs.
- Google and Manifest host logic (`gcert`, `unlock_gnubby`, `g4d`, the history forwarder).
- CVS and Perforce helpers and env.
- rbenv. xemacs fallback.
- `zsh.zshrc.reference.dont`, `mdf-switch`, `setup-terminal` (tset).
- Any network access or installation during shell startup.
- `.cshrc`, `.login`, and `usr/local/etc/csh.*` are out of scope and stay where they are until the cleanup phase decides.

## 5. Research conclusions

Full findings were gathered on 2026-11-20. The decisions they drove:

| Topic | Finding | Decision |
|---|---|---|
| Plugin managers | antidote, zim, and zinit are maintained; zsh-bench shows managers add convenience, not speed, and that deferred loading is not worth it. sheldon is not cross-shell. | No manager. A built-in loader with SHA-pinned plugins. |
| Carapace | v1.8.2, monthly releases, zsh/fish/bash. Open bugs when combined with fzf-tab. | Opt-in module; not combined with fzf-tab by default. |
| Cross-shell env | Good multi-shell repos render per-shell files from shared data; translating at startup (bass and friends) spawns bash each time. | Render at build time. bass is not used at startup. |
| Helper protocol | zoxide, direnv, mise, yazi, and broot show two shapes: static init code, and data applied by a native wrapper. No shared library exists; fish quoting differs. | Helpers emit data directives; a small native applier applies them. |
| Helper latency | Go 9 ms, bun 14 ms, python 23 ms, `brew shellenv` 31 ms. | Nothing but zsh on the startup path; cache tool init output. |
| Deployment | chezmoi, dotbot, stow, and mise bootstrap all work, but each makes the user adopt a manager. prezto and thoughtbot show the "framework + user-owned overlay" split. | The repo is a framework that is cloned and never edited; the user owns `~/.config/marksharc/`. |
| Startup order | macOS `path_helper` reorders PATH after `.zshenv`. Claude Code sources the rc file non-interactively. `BASH_ENV` is honoured by `bash -c` but not `sh -c`. | Env in `.zshenv`, re-asserted in `.zprofile`; interactive work gated on session class. |
| Testing | ShellSpec is stale but works for zsh and bash; ShellCheck cannot parse zsh; `shfmt -ln zsh` exists but is incomplete; fishtape for fish. | Keep ShellSpec, add a cross-shell contract suite, lint with `zsh -n`. |
| Version managers | Re-evaluated in DEV-62 (2026-11-24). nvm and gvm cost about 3.5 ms at startup but about 1.9 s for a `cd` into a `.nvmrc` directory and 0.7 s for the first `gvm`. mise 2026.11: `hook-env` about 30 ms, shims add about 27 ms per call, native zsh, bash, and fish, version files per tool. | An opt-in `mise` module; nvm, gvm, and pyenv stay the default and the fallback. |
| Agents | atuin tags agent commands and exposes an MCP server; agents set `CLAUDECODE`, `AI_AGENT`, and similar. | An `agent` module: full env, no output, no interactive phase. |

## 6. Architecture

### 6.1 Three layers

| Layer | Location | Owner | Contents |
|---|---|---|---|
| Framework | `$MARKSHARC_HOME`, default `~/.local/share/marksharc` | The public repo. Never edited on a host. | Core loaders, public modules, the `marksharc` CLI, templates, tests, docs. |
| Overlay | `$MARKSHARC_CONFIG`, default `~/.config/marksharc` | The user. For the author, a link to `mark-desktop-files/marksharc/`. | Module selection, options, per-host files, private modules, provider files, package bundles, host inventory, native hooks. |
| State and cache | `~/.cache/marksharc/` and `~/.local/state/marksharc/` | The machine. Safe to delete. | Rendered env, cached tool init, generated completions and shims, compdump, plugin clones, sync status, the generated `ZDOTDIR`. |

All three honour the XDG variables. Per-host cache lives under `~/.cache/marksharc/<shorthost>/`, because home directories are sometimes copied or shared between hosts. A developer points `MARKSHARC_HOME` at a working checkout.

### 6.2 Framework repository layout

```
marksharc/
  README.md  LICENSE  CHANGELOG.md  .gitignore
  install.sh                 # POSIX sh: clone, write stubs, first render
  bin/marksharc              # CLI entry point (zsh)
  core/
    zsh/    zshenv.zsh  zprofile.zsh  zshrc.zsh  zlogin.zsh  lib/*.zsh
    fish/   marksharc.fish  lib/*.fish
    bash/   env.bash  bashrc.bash
    cli/    reload  render  sync  doctor  bootstrap  update  install  module
  modules/<name>/            # public modules (6.4)
  templates/overlay/         # skeleton for a new ~/.config/marksharc
  tests/                     # ShellSpec units, contract suite, fixtures
  docs/  specs/  memories/   # common workflow conventions
```

`.gitignore` excludes agent configuration (`AGENTS.md`, `CLAUDE.md`, `.claude/`, `.agents/`, `.omp/`, `.codex/`, `.cursor/`) and `.cwf*`. A working `.cwf-settings.yaml` is created locally and rendered by hand; it is not committed. The workflow tool is `cwf`, not `cwft`.

### 6.3 Overlay layout

```
~/.config/marksharc/
  config.conf                # modules, options, user path/env/alias lines
  hosts/<shorthost>.conf     # per-host additions and overrides
  modules/<name>/            # private modules, same contract as public ones
  local/pre.zsh  local/post.zsh  local/post.fish   # native escape hatches
  providers/*.conf           # Claude provider definitions (private)
  packages/                  # personal package bundles (Brewfile fragments, apt lists)
  hosts.conf                 # host inventory for push sync
```

The author's overlay starts with three private modules: `convoy` (work roots, org list, repo-specific `cwf-new` hooks), `site-bac` (Plesk and BAC aliases, `gbac*` helpers), and `mark-tools` (sandcat, gam, envman).

Bootstrap reads `packages/*.Brewfile` as package data. Each entry is a `brew "name"` or
`cask "name"` declaration. The `.darwin.Brewfile` and `.linux.Brewfile` suffixes select
one platform, and casks apply only on macOS. On Linux, `packages/*.apt` and
`packages/*.dnf` list one package per line.

### 6.4 Module contract

A module is a directory. Every file is optional except `module.conf`.

```
modules/<name>/
  module.conf          # declarative metadata and env (6.5)
  env.<shell>          # native env code, only where directives cannot express it
  init.zsh  init.fish  # interactive-only setup: hooks, keybindings, options, cached tool init
  functions/zsh/<fn>   functions/fish/<fn>.fish   # native autoloaded functions
  bin/<command>        # write-once executables (6.11)
  completions/zsh/_<cmd>   completions/fish/<cmd>.fish
  tests/               # specs for this module
```

The approved Bash extension (6.16) uses `init.bash`, `functions/bash/<fn>.bash`
and `completions/bash/<cmd>.bash`. Bash loads function definitions explicitly;
zsh autoload files and Fish functions are not sourced into Bash.

How a module covers the four impact areas:

| Area | Mechanism |
|---|---|
| Path composition | `path` directives into named tiers (6.7) |
| Functions and aliases | `alias` directives; native autoloaded functions; executables in `bin/` |
| Completion | Static files in `completions/`; `completion` directives generate and cache the rest |
| Tool setup | `env` directives; `init.<shell>` with cached `tool init` output |

Rules:

- A module loads only if it is enabled, its `requires` lines are satisfied, and it supports the current OS. A missing optional tool never breaks startup.
- Sourcing a module twice must be safe.
- Public modules contain no user names, host names, organisation names, or absolute home paths. Such values arrive as options.
- A module declares its options with defaults; the overlay sets them.
- Module files (`env.<shell>`, `init.<shell>`) and the overlay's `local/` hooks run at top level at startup and inside the `marksharc` function on `marksharc reload`, where a bare `typeset` would be function-local. A declaration at file scope therefore says `-g` (`typeset -g`, `typeset -g +x PS1`, `integer -g`); declarations inside functions, anonymous functions included, are unrestricted. `tests/support/function-safe-check.py` enforces this for the zsh modules, the core and the overlay template. Cached third-party tool init output (starship, atuin, zoxide and similar `init zsh` text) is sourced inside that function on reload as well; it is the tools' own code, so it must not rely on its file-scope declarations being global. That is a known limitation, not something the checker can see.
- Modules load in `order` (0–99, default 50), then by name. Reserved bands: 0–9 core, 10–19 package managers (brew), 20–69 general, 70–79 completion, 80–89 prompt, history, and navigation tools, 90–99 last-running init: modules that must see every earlier module's hooks (`titles` 90, `x11` 91, `ssh-agent` 93, `greeting` 94), with line-editor plugins that must load last at 95 and above.

### 6.5 Directive vocabulary

One line-oriented format serves module metadata, user configuration, and the write-once protocol. Lines are tokenised with shell word rules (zsh `(z)` splitting and `(Q)` unquoting). `#` starts a comment. Values may use `~` and `$NAME` references only; there is no command substitution.

Module and overlay files (`module.conf`, `config.conf`, `hosts/*.conf`):

| Directive | Meaning |
|---|---|
| `describe <text>` | One-line description (modules only). |
| `requires command <name>…` | Skip the module when a command is missing. |
| `requires os darwin\|linux` | Restrict the module to an OS. |
| `order <n>` | Load order. |
| `option <key> <default> <text>` | Declare an option. Read as `$_ms_opt_<module>_<key>`. |
| `env <NAME> <value> [when …]` | Export a variable. |
| `path <tier> <dir> [when …]` | Add a directory to a PATH tier. |
| `alias <name> <value> [when …]` | Define an interactive alias. |
| `plugin <name> <git-url> <sha> [shell <s>] [kind source\|fpath]` | Pin a third-party plugin (6.8). |
| `completion <cmd> <generator…>` | Generate a completion file into the cache at render time. |
| `package <manager> <name>` | Declare a package for `bootstrap` (`brew`, `cask`, `apt`, `dnf`). |
| `update <label> <command…>` | Register an argv-based step for `marksharc update`. A command path beginning with `./` resolves relative to its module directory or the overlay root. |
| `installer <name> <script>` | Register an executable for `marksharc install`. Relative paths resolve from the module directory or the overlay root. |
| `module <name> [off]` | Enable or disable a module (overlay only). |
| `set <module>.<key> <value>` | Set an option (overlay only). |
| `tiers <tier>…` | Override PATH tier order (overlay only). |

Guards: `when command <c>`, `when dir <d>`, `when file <f>`, `when os <o>`, `when host <h>`. Several guards on one line must all hold.

`marksharc render` resolves structure (which modules, which order, which options) and writes flat native files. Guards on `command`, `dir`, and `file` are emitted as cheap runtime tests, so installing a tool takes effect in the next shell without a re-render. Guards on `os` and `host` are resolved at render time.

Example:

```
# modules/bun/module.conf
describe "Bun JavaScript runtime"
order 40
env  BUN_INSTALL ~/.bun            when dir ~/.bun
path user ~/.bun/bin               when dir ~/.bun/bin
completion bun bun completions     when command bun
package brew oven-sh/bun/bun
update bun bun upgrade
```

In the MVP, `module.conf` carries metadata only (`describe`, `requires`, `order`, `option`) and env lives in hand-written `env.zsh`. The `env`, `path`, `alias`, and `completion` directives and the renderer arrive in Modernization. The loader treats a module's `env.zsh` and its rendered directives the same way, so modules convert one at a time.

### 6.6 Session classes and startup phases

Three facts are independent: login or not, interactive or not, and agent or not. The core sets `MARKSHARC_SESSION`:

| Value | Condition | Gets |
|---|---|---|
| `interactive` | Interactive, a terminal on stdin and stdout, no agent or editor-injection marker | env phase, then init phase |
| `agent` | Any of `CLAUDECODE`, `AI_AGENT`, `CODEX_SESSION_ID`, `CODEX_SANDBOX`, `OPENCODE`, `GEMINI_CLI`, `CURSOR_AGENT`, `COPILOT_CLI`, `KILO_CLI_MODE`, `VSCODE_INJECTION`, `VSCODE_NONCE` | env phase only, no output |
| `batch` | Everything else | env phase only, no output |

The marker list is an option of the `agent` module so it can grow without a release.

Phases:

1. **env** — every shell, every mode. Host facts, exports, PATH. No forks beyond cached files, no output.
2. **init** — interactive only. Shell options, hooks, keybindings, aliases, autoload paths, completion, plugins, cached tool init, the overlay's `local/post.<shell>`.

Host facts use shell built-ins (`$OSTYPE`, `$HOST`, `$CPUTYPE`, `$EUID`) and are exposed as `MARKSHARC_OS` (`darwin` or `linux`), `MARKSHARC_ARCH`, `MARKSHARC_HOST` (short name), and `MARKSHARC_DISTRO`. The old names (`ostype`, `hwtype`, `shorthost`, `distro`, `dname`) remain as non-exported compatibility variables through the MVP and are removed in Modernization. The site concept behind `dname` becomes per-host overlay files.

Wiring per shell:

| Shell | Stub written by the installer | Then |
|---|---|---|
| zsh | `~/.zshenv`: set `MARKSHARC_HOME`, source `core/zsh/zshenv.zsh` | `zshenv.zsh` sets `ZDOTDIR` to `~/.local/state/marksharc/zdot` (four one-line stubs) and runs the env phase. `.zprofile` re-asserts PATH after macOS `path_helper`. `.zshrc` runs the init phase. |
| fish | `${XDG_CONFIG_HOME:-~/.config}/fish/conf.d/00-marksharc.fish` | Sources the rendered `env.fish`; runs init when `status is-interactive` and the session class allows. Existing Fish configuration is preserved by default. |
| bash | `~/.bashrc` and `~/.bash_profile` | Source the rendered `env.bash` in every mode and native interactive init when eligible (6.16). `BASH_ENV` loads the environment and is set only when `agent.bash_env` is on. |

The zsh env phase sets shell-local `skip_global_compinit=1`, so a distro global rc file cannot run a competing `compinit` before session classification. The `completion` module is the sole completion initializer.

The env phase exports `MARKSHARC_ENV=<render id>`. A child shell that inherits a matching value skips the export and PATH work and only recomputes shell-local facts. Login shells and explicit reloads always rebuild.

`ZDOTDIR` takeover is deliberate: it keeps installer edits to `~/.zshrc` from changing the shell silently. `marksharc doctor` lists foreign lines found in `~/.zshrc`, `~/.zprofile`, `~/.bashrc`, and `~/.config/fish/config.fish` so each can become a module or an overlay line.
An installer-managed Bash stub whose checksum matches the install manifest is
accepted. A missing, symlinked, or modified recorded Bash stub is reported.
The Fish `config.fish` is separate from the managed `conf.d` stub. When the
installer offers a clean Fish configuration, it defaults to keeping the
existing tree. If the stub path is occupied by a custom file and cleanup is
declined, the installer reports that it skipped Fish and continues with zsh
and Bash.

### 6.7 PATH composition

Modules and the overlay add directories to named tiers. The builder concatenates tiers in order, keeps inherited entries it does not manage, and removes duplicates.

Default order, chosen to reproduce today's result except that version managers come first (operator decision, DEV-38: correct gvm and nvm behaviour wins over historical order, so Homebrew's `go` or `node` never shadows the manager-selected one) and, on Linux, `local` follows `app`. A `tiers` override lists the order; any tier it omits follows in the default order:

| Tier | Typical contents |
|---|---|
| `first` | Explicit user overrides |
| *(inherited, unmanaged, before any managed entry)* | Virtualenv and tool activations, including an explicit `nvm use` or `gvm use` |
| `manager` | Version-manager directories (gvm Go and pkgset bin, nvm default node bin, pyenv shims, and the mise shim directory for tools the `mise` module owns), contributed without sourcing the manager; always ahead of `brew` in every session class, including after the `.zprofile` re-assert |
| `brew` | Homebrew `bin` and `sbin` |
| `local` | `/usr/local`, `/opt`, Linuxbrew (unless `brew.linuxbrew_tier` is `brew`), `/opt/dell`, `~/.opencode/bin`, and on macOS LM Studio. Before `system` on macOS; on Linux after `app`, the last tier before `last` |
| `system` | `/bin`, `/usr/bin`, `/sbin`, `/usr/sbin` |
| `user` | `~/bin`, `~/bin/bin.<OS>.<arch>`, `~/.local/bin`, Go, Cargo, bun, pnpm, krew |
| `app` | Application dirs that follow `user`: CUDA (Linux, when the NVIDIA driver is loaded) and, on Linux, LM Studio |
| *(inherited, unmanaged, after a managed entry)* | |
| `last` | `.` when `core.dot_in_path` is on and the user is not root |

The builder records the entries it manages. On reload it drops managed directories that have vanished and leaves everything else alone. `fpath`, `manpath`, and fish's function and completion paths follow the same idempotent pattern.

### 6.8 Plugins

There is no plugin manager. A `plugin` directive names a git URL and a commit. `install.sh` and `marksharc update` clone or check out pins into `~/.cache/marksharc/plugins/<name>@<sha>/`. At startup a loader of about 30 lines sources the plugin entry file or adds the directory to `fpath`; each plugin module's `init.zsh` calls the core `_ms_plugins_load <module>` for its own `zsh.plugins` registry, so a plugin module does not depend on another being enabled. A missing clone is skipped silently and reported by `doctor`. The plugin loader never touches the network; the separate notify fetch is the exception described in 6.14.

The same directive serves fish: the fish loader adds the plugin's `functions` and `completions` directories and sources its `conf.d` files. This replaces fisher for the plugins marksharc depends on.

Planned plugins: fzf-tab (MVP); zsh-autosuggestions and zsh-syntax-highlighting (Modernization); nvm.fish and fzf.fish (Fish phase).

### 6.9 Completion

- zsh runs a full `compinit -i -d` with its dump in the cache, rebuilt when `fpath` changes. The security audit remains enabled, but insecure directories are excluded silently rather than prompting; `compinit -C` skips the audit and `compinit -u` trusts insecure directories, so neither is used.
- The existing zstyles move into the `completion` module, minus the dead ones.
- Generated completions (`herdr completion zsh`, `cwf shell zsh`, `kubectl completion zsh`) are written to cache files by `render` and `update`, not evaluated at startup.
- `completion-fzf-tab` and `completion-carapace` are alternative UI modules. Enabling Carapace disables fzf-tab unless the overlay forces both.
- fish keeps native completions; modules add files to its completion path.

### 6.10 Caching, reload, and verbosity

- `_ms_init_cached [-x <NAME>] <tool> <command…>` stores the output of `starship init zsh`, `atuin init zsh`, `zoxide init zsh`, `brew shellenv`, and similar, keyed on the binary's path and mtime, and sources the file. With `-x` it caches the output as the value of the exported variable NAME instead (`vivid generate` prints an `LS_COLORS` value). It replaces `_mdf_init_once`.
- `marksharc reload` re-renders if inputs changed, then rebuilds env and re-runs init in the current shell. `cs` and `li` are aliases for `marksharc reload --verbose`.
- Startup prints nothing by default. `MARKSHARC_VERBOSE=1` or `--verbose` prints the module trace, skipped modules with reasons, PATH tiers, and per-module timings. Install hints move to `doctor`.
- The `greeting` module (fortune) is opt-in and runs only in interactive sessions.

### 6.11 Write-once commands

Complex commands are implemented once as executable zsh scripts in a module's `bin/` directory, which the env phase puts on PATH. They run in their own process, so they cannot leak options, variables, or a changed directory into the caller.

When a command must change the caller's state, a native wrapper function sets `MARKSHARC_DIRECTIVES` to a temporary file, runs the executable with the terminal still attached, then applies the file:

| Directive line | Effect in the calling shell |
|---|---|
| `cd <dir>` | Change directory |
| `pushd <dir>` | Push onto the directory stack |
| `setenv <NAME> <value>` | Export a variable |
| `unsetenv <NAME>` | Unset a variable |
| `exit [<status>]` | Exit the calling shell once the remaining directives are applied ([LAUNCH-SPEC.md](LAUNCH-SPEC.md) 9.3) |

Fields are tab-separated. Tab, newline, and `%` inside a value are percent-encoded. The applier is about 20 lines per shell and never evaluates text as code. A wrapper that needs no state change is not written at all; the executable is called directly.

Generated commands become **shims**, not shell functions. `claudek`, `modelsk`, `herdr-<session>`, and `collie-<session>` are small executables written to `~/.cache/marksharc/<host>/bin/`, which is on PATH. They work from zsh, fish, bash, and agent shells alike. A shim never embeds a secret; it reads the provider file when it runs.

First candidates: `cwf-new`, `gwt-clean`, `repo-sync`, ssh-agent discovery (emits `setenv SSH_AUTH_SOCK`), `clean-ssh-agents`, the docker helpers, provider and session wrappers, and the CLI subcommands themselves. Title updates stay native per shell, because they run on every directory change.

### 6.12 History

- The `history-atuin` module initialises atuin, binds Ctrl-R and Up, disables the native zsh history file (in-memory history stays for `!!` and recall), and defines `history` and `h` over `atuin history list` so that `history | egrep …` keeps working.
- `history-native` is the fallback for users without atuin: one history file under the state directory and a small, fixed option set.
- A one-time import loads the legacy files into atuin: `~/.zsh_history`, `~/.zhistory`, `$ZDOTDIR/.zsh_history`, the per-directory history trees (preserving the directory where the format allows), and the same from sol and other hosts.

### 6.13 Multiplexer integration

Multiplexers change faster than the rest of the environment, so they sit behind an adapter interface in the `mux` module. More than one adapter can be active (herdr inside WezTerm).

| Adapter function | Purpose |
|---|---|
| `detect` | Is this multiplexer present in the current session? |
| `set_titles <workspace> <tab> <pane>` | Push titles to the multiplexer |
| `refresh_env` | Re-import `SSH_AUTH_SOCK`, `DISPLAY`, and similar from the client (today's `fix-tmux`) |
| `sessions` | List sessions, for generated attach shims |

Adapters: `tmux`, `herdr` (TUI and app/core), `wezterm`, and `plain` (OSC 0/1/2). A new multiplexer is one adapter file. The `titles` module computes the workspace, tab, and pane strings once (repository, branch, cwf session, path tail) and hands them to every active adapter. The `x11` module asks the active adapter for the client DISPLAY first and falls back to the SSH-derived guess; the ping and the one-second sleep go away.

In the MVP the existing `chdir-set-title`, `setup-herdr-sessions`, and `fix-tmux` are lifted as they are. The adapter refactor is a Modernization issue.

Opening a new terminal is a further set of adapter operations (`supports`, `current`, `instances`, `machines`, `launch`), specified in [LAUNCH-SPEC.md](LAUNCH-SPEC.md) section 5.4.

### 6.14 Sync across hosts

A host has two checkouts: the framework and the overlay (plus any private module repos listed in the overlay). Everything is fast-forward only.

- `marksharc sync` fetches and fast-forwards each checkout, reports dirty, ahead, or diverged trees without touching them, refreshes existing caches (re-rendering once the P3.1 renderer exists), fetches newly pinned plugins, and prints a `doctor` summary.
- **Notify**: an interactive shell starts a detached fetch when the last check is older than `sync.check_hours` (default 12). The result is written to a status file; the next eligible shell prints one line when the host is behind. This detached fetch is the explicit exception to the offline startup rule in 10.4.
- **Poll-pull** (Modernization): a launchd agent or systemd user timer runs `marksharc sync --auto`.
- **Push** (Modernization): `marksharc push [host…]` runs `marksharc sync` over ssh on each host in `hosts.conf` and reports per-host results.

### 6.15 Day 0 and Day 2

| Command | Purpose |
|---|---|
| `install.sh` | Check for zsh and git, clone the framework (or accept `--home <checkout>`), create or link the overlay (`--overlay <path\|url>`), back up startup files and write the stubs, fetch the plugin pins (`--no-plugins` skips and a failed fetch warns), then render. `--clobber` answers yes to optional cleanup and `--dry-run` previews changes without prompting. |
| `marksharc bootstrap` | Install packages declared by enabled modules for the current OS and by overlay bundles. Generate a temporary Brewfile for Homebrew on macOS and Linux. Print apt or dnf commands and require confirmation before invoking sudo. |
| `marksharc update` | Sync repositories, refresh plugin pins, run module and overlay steps, and render. Continue after individual failures and report each step's result. `--list` lists the steps, `--only <label>` selects one, and `--dry-run` prints commands without running them. Replaces `bin/do_updates.sh` and all startup-time pulls. |
| `marksharc install <name>` | Run an explicit installer declared by a module (krew, gvm, WezTerm terminfo, pyenv, nvm). |
| `marksharc doctor` | Verify stubs and links, cache and environment ID freshness (render freshness once the renderer exists), missing commands for modules the overlay enables by name (a module enabled by default skips itself when its required command is absent), plugin clones, repo state, foreign lines in dotfiles, duplicate PATH entries, and startup time against a budget. |
| `marksharc module list\|enable\|disable` | Inspect and edit module selection in the overlay. |
| `marksharc uninstall` | Restore the backed-up dotfiles and remove stubs. |

The Bash backup includes `.bashrc`, `.bash_profile`, `.bash_login`,
`.profile` and `.login`. Confirmed Fish cleanup moves the entire Fish
directory into a private backup beside it and writes a clean configuration
with only the managed stub. Uninstall restores the Fish backup and preserves
files added to the replacement directory.

Doctor reports legacy `.provider` files for an enabled `cc-providers` module
and reports an empty provider directory when the module or directory is
explicitly configured. An unused default provider directory stays optional.

The update runner validates its step labels and arguments once before execution. Configuration
changes fetched by sync apply to the next invocation.

### 6.16 Interactive Bash

The approved target is substantially equivalent public interactive behavior in Bash
4.4+ on macOS and Linux, delivered by DEV-80–DEV-83. Bash 3.2 retains environment
support. Older versions never automatically exec a newer shell, and startup stays
quiet; `doctor` reports the interactive version requirement as part of DEV-83.
DEV-80 provides native interactive startup, reload, hooks and caller-state wrappers.
DEV-81 provides the Starship, Atuin, native history, zoxide, direnv and version-manager
adapters.

The complete behavior contract, module coverage, accepted gaps and acceptance matrix
are in [BASH-SPEC.md](BASH-SPEC.md). Its requirements include:

- Init requires an interactive Bash with stdin/stdout TTYs and no active agent marker.
  `BASH_ENV`, batch, agent and no-TTY invocations remain env-only. Render shared data
  into native Bash init, aliases and options; use `init.bash`, Bash function files and
  `local/post.bash` for native interactive behavior. Keep the env artifact 3.2-compatible.
- Reuse write-once executables and shims. Native wrappers apply the existing literal
  caller-state protocol, including deferred `exit`. Reload tracks owned state and
  preserves foreign hooks and later user replacements; render failure retains live init.
- Compose prompt/directory callbacks with existing scalar or array `PROMPT_COMMAND`
  and preexec backends, preserving status and pipeline results. Directory callbacks
  observe `$PWD` changes before the next prompt; same-line `cd; command` can precede
  automatic manager selection. Keep native Bash directory-stack semantics.
- Use starship, Atuin, zoxide, fzf and optional Carapace/bash-completion. Optional,
  recommended ble.sh >= 0.4 supplies suggestions, highlighting and menu selection;
  Readline is the fallback. Acquire/build immutable pins only through explicit
  install/update tooling. Missing or failed Atuin integration retains native Bash
  history persistence; working Atuin integration disables that persistent native store.
- Port public functional modules, manager ownership/fallback and launch handoff; do
  not load zsh/Fish plugins in Bash. Private shell-specific hooks require an adoption
  inventory. Backend switches require an explicit fresh shell; ordinary reload stays
  in place. Missing optional tools never break startup.
- Verify actual Bash 4.4 and current 5.x, macOS 3.2 env compatibility, real-tool PTY
  behavior on macOS/Linux and warm startup against 500 ms. Intermediate issues do
  not certify the full feature; final acceptance belongs to DEV-83.

## 7. Module catalog

"Phase" is when the module first exists in the new structure. MVP modules are native zsh; fish support for each arrives in the Fish phase.

### 7.1 Public modules

| Module | Phase | Contents | Replaces |
|---|---|---|---|
| `core` | MVP | Session class, host facts, guards, cache helpers, reload, verbose trace, directive applier | `zsh.common`, `zsh.functions` helpers, sentinels |
| `path` | MVP | Tiered PATH builder, `bin.<OS>.<arch>` support, `dot_in_path` option | `build_path` |
| `agent` | MVP | Agent markers, quiet env; later `bash_env` option and atuin agent hooks | `interactive_shell` |
| `brew` | MVP | Cached `brew shellenv` for macOS and Linuxbrew | `setup-homebrew` |
| `zsh-options` | MVP | The kept `setopt` set, locale, umask rule | Interactive option block |
| `editor` | MVP | `EDITOR` from an option (default `emacs -nw` when present, else `vi`) | emacs/xemacs detection |
| `pager` | MVP | `PAGER`, `LESS`, coloured man pages, coloured `diff`, `diffcp` | OMZ colored-man-pages, diff overrides |
| `ls` | MVP | `ll`, `la`, `dir`, `lf`, `lsf`, eza-backed when installed; bare `ls` stays native | eza alias block |
| `ps` | MVP | The seven ps helpers, fixed; ps selects and procs draws the selection when installed (`ps.procs`); bare `ps` untouched | ps function block |
| `nav` | MVP | Directory stack options, Alt-arrow directory widgets | OMZ dirhistory and dircycle |
| `zoxide` | MVP | Cached init | |
| `completion` | MVP | `compinit`, zstyles, completion cache | Completion block, OMZ lib |
| `completion-fzf-tab` | MVP | fzf-tab plugin | OMZ custom plugin |
| `command-not-found` | MVP | Homebrew and apt handlers | OMZ command-not-found |
| `history-atuin` | MVP | atuin init, `history` and `h` | History option block, per-directory plugin |
| `history-native` | MVP | Fallback file-based history | |
| `prompt-starship` | MVP | Cached init; `config` option selects a file or a bundled preset (`rich`) as `STARSHIP_CONFIG` | OMZ themes, p10k |
| `node-nvm` | MVP | nvm load, `.nvmrc` hook | nvm block, `load-nvmrc` |
| `go-gvm` | MVP | gvm activation, `go.mod` hook, consistent `GOROOT` | gvm blocks |
| `python` | MVP | uv preferred, pyenv fallback | pyenv/uv block |
| `bun`, `pnpm`, `rust`, `go` | MVP | Paths and env | Assorted lines |
| `mise` | Later | Opt-in owner of the tools named in `mise.tools` (node, go, python, ruby): shim directory in the `manager` tier in every session class, cached `mise activate` in interactive shells (run on directory change by default, not at every prompt), `MISE_*` settings from options, optional `nvm` and `gvm` translation functions. The owned tools' legacy modules stand aside; without mise they run as before | `node-nvm`, `go-gvm`, and pyenv, per tool, when enabled |
| `ssh-agent` | MVP | Agent discovery and cache under the state dir, `clean-ssh-agents` | `setup-ssh-agent`, `clean-ssh-agents` |
| `x11` | MVP | DISPLAY inference; mux-aware in Modernization | `setup-x11-display` |
| `docker` | MVP | `cleanup-docker`, `fix-docker-socket`, container detection | Same names |
| `mux` | MVP | `fix-tmux`; adapters in Modernization | `fix-ssh.zsh` |
| `titles` | MVP | Title computation and the chdir hook | `chdir-set-title`, `set-title` |
| `herdr` | MVP | Session and collie wrappers, completion | `setup-herdr-sessions` |
| `wezterm` | MVP | Terminfo installer | `install-wezterm-terminfo` |
| `cc-providers` | MVP | Claude provider wrappers from overlay provider files | `setup-cc-providers` |
| `git-worktree` | MVP | `gwt-clean` with pre-remove hooks, `git-managed`, `git-unmanaged`, `repo-sync` with `roots` and `orgs` options | Same names |
| `cwf` | MVP | `cwf shell` init, generic `cwf-new` with post-create hooks | cwf block, `cwf-new` |
| `fish-bridge` | MVP | `run-fish` | `runfish.zsh` |
| `greeting` | MVP | fortune, opt-in | fortune line |
| `direnv` | MVP | Cached hook, opt-in | fish-only today |
| `lmstudio`, `cuda` | MVP | App-tier paths and env | `build_path` fragments |
| `zsh-autosuggestions`, `zsh-syntax-highlighting` | Modernization | Pinned plugins at 95 and 99, after fzf-tab and atuin; an atuin suggestion strategy when atuin is installed; syntax highlighting loads last of all | |
| `theme` | Modernization | Cached vivid `LS_COLORS`, bat man pager, opt-in delta include through `GIT_CONFIG_COUNT`, fzf defaults and previews (fzf-tab included); order 21, before completion reads `LS_COLORS` | |
| `completion-carapace` | Modernization | Opt-in zsh completion via cached `carapace _carapace zsh` at order 72 with `enable`, `bridges`, `excludes`, and `allow_fzf_tab` options; disables `completion-fzf-tab` unless forced; `completion-ui` / `MARKSHARC_COMPLETION_UI` switches between UIs for a fresh shell (`exec zsh -l`) | |
| `launch` | Modernization | `launch-session` and `launch-repo`: a new terminal session on a chosen host, directory, or repository under tmux, the Herdr TUI, or Herdr Core; launch metadata and run-after-init ([LAUNCH-SPEC.md](LAUNCH-SPEC.md)) | |
| `cloud` | Later | kubectl, krew, kubectx, gcloud, aws, helm | k8s and gcloud blocks |

### 7.2 Private modules (author's overlay)

| Module | Contents |
|---|---|
| `convoy` | `COMMON_DEV_TOOLS` discovery, `repo-sync` roots and orgs, the `core-platform` post-create hook for `cwf-new` (port offset, PostgreSQL data dir, `.env` rewrite) |
| `site-bac` | Plesk and BAC aliases and functions, `glogin`, `gbacstart`, `gbacstat`, the site umask |
| `mark-tools` | sandcat, gam, envman |
| *(not modules)* | `providers/*.conf`, `packages/` bundles from `bootstrap-mac*.sh` and `basepkgs.sh`, `hosts.conf`, `set core.dot_in_path on` |

## 8. Testing and quality

| Layer | Tool | What it proves |
|---|---|---|
| zsh and bash units | ShellSpec 0.28.1, pinned | Function behaviour in a temporary HOME with stubbed commands (the existing approach) |
| Cross-shell contract | ShellSpec under `sh`, launching `zsh`, `fish`, and `bash` | Same PATH and env in every shell; silent batch and agent startup; idempotent re-source; no writes outside cache and state |
| fish units | fishtape (Fish phase) | Native fish functions; replaces `test_parity.py` |
| PTY cases | The existing Python PTY helper | Interactive classification, reload, one-time init |
| Lint | `zsh -n`; `shfmt -ln zsh -d` (advisory); shellcheck for `sh` and `bash` files; `fish --no-execute` and `fish_indent --check` | Syntax and formatting |
| Startup budget | hyperfine, advisory | Regression check on interactive and batch startup |
| CI | GitHub Actions, `macos-latest` and `ubuntu-latest` | All of the above on every PR |

Rules, carried from the existing suite:

- Tests never install their runner, touch the real HOME, or call real services.
- Every example gets its own HOME, XDG dirs, and command stubs.
- "90% coverage" means 90% of the contract inventory: a table in `tests/README.md` that lists each module's behaviours and the spec that exercises it. Line coverage is not claimed.

## 9. Migration map

| Today (`mark-desktop-files`) | Destination |
|---|---|
| `config/zsh/.zshenv.*`, `.zshrc`, `.zlogin`, `zsh.zshrc`, `zsh.login` | Installer stubs and `core/zsh/` |
| `zsh.common`, `zsh.functions` | `core` module and `core/zsh/lib` |
| `functions/build_path.zsh` | `path` module plus per-module `path` lines |
| `zsh.zshrc.interactive` | Split across the modules in 7.1 |
| `zsh.zshrc.ohmyzsh`, `zsh.zshrc.reference.dont`, `etc/oh-my-zsh/`, `etc/links/*.zsh-theme`, `etc/zsh_plugins.txt` | Deleted |
| `functions/*.zsh` | The owning module's `functions/zsh/`, later `bin/` |
| `functions/mdf-sync.zsh`, `link-cleanup.zsh` | `marksharc sync`, `install.sh`, `doctor` |
| `functions/mdf-switch.zsh`, `setup-terminal.zsh` | Deleted |
| `etc/zsh.zshrc.user`, `etc/zsh.gcp-mcp`, `etc/zsh.manifest-cloud` | Overlay `site-bac` module; Google and Manifest parts deleted |
| `ai/providers/*.provider` | Overlay `providers/` |
| `config/fish/` | `core/fish/` and module `init.fish` and `functions/fish/` (Fish phase) |
| `tests/shell/`, `config/fish/tests/` | `marksharc/tests/` |
| `docs/fish-zsh-*.md`, `docs/zsh-*.md`, `specs/MARKSHARC-*.md` | `marksharc/docs/` and `marksharc/specs/` (design rules extended, bug lists closed out) |
| `bin/do_updates.sh`, `bin/bootstrap-mac*.sh`, `scripts/basepkgs.sh`, `bin/go_installs.sh`, `bin/uv_setup.sh` | `update` and `package` directives; personal lists to overlay `packages/` |
| `.bashrc`, `.bash_profile`, `.bash_login`, `.profile` | Installer stubs and `core/bash/` |
| `config/starship.toml` | Stays in `mark-desktop-files` (user configuration) |
| ssh keys, `ai/`, non-shell `config/*`, `etc/gitconfig`, emacs | Stay in `mark-desktop-files` |

## 10. Design rules

These extend `docs/fish-zsh-design-rules.md` and move to the new repo's docs in the MVP.

1. **Match capabilities, not file trees.** A working command, a discoverable binary, and the right exported variable matter more than identical structure across shells.
2. **Let each shell be itself.** Share data and executables; write interactive behaviour natively.
3. **Login, interactive, and agent are separate questions.** Env belongs to every mode. Prompting, history tools, titles, and greetings need an eligible interactive session.
4. **Startup is quiet, fast, and offline**, except for the detached, throttled interactive notify fetch and its subsequent behind notice in 6.14. Installs and pulls are explicit commands.
5. **Reload is safe.** Keep inherited paths, deduplicate, replace named hooks, track what you generated.
6. **Data stays data.** Preserve spaces and metacharacters. Apply directives; never evaluate generated text, except a tool's own documented shell integration.
7. **Scope mutable state.** Per-host cache, per-shell cache files, connectivity checks on cached sockets.
8. **Fail before destructive work.** Validate, confirm, and let the owning tool delete.
9. **Optional means optional.** A missing tool or directory never breaks startup.
10. **Portable code holds no personal values.** Names, hosts, orgs, and paths arrive from the overlay.
11. **The framework is read-only on a host.** Configuration goes in the overlay; state goes in cache and state dirs.
12. **Generated commands are shims on PATH,** so every shell and every agent can run them.
13. **Prove behaviour without touching real services.** Temporary HOME, stubs, disposable repositories.
14. **Do not canonise old bugs.** Use the old setup to find intent, then implement the useful contract.

## 11. Risks and open questions

| Risk or question | Handling |
|---|---|
| Removing OMZ changes keybindings and completion feel in ways history cannot show. | Its own pre-migration PR, lived in on the Mac before sol; rollback is one revert. |
| How agent harnesses find rc files when `ZDOTDIR` is redirected is not fully verified (Claude Code is documented to source `~/.zshrc` or `~/.bashrc`; Codex is undocumented). | Contract tests for `zsh -c`, `zsh -ic`, and `bash -c` under agent markers; a manual check per harness in the core-loader issue. |
| Per-directory history may not import into atuin with its directory. | A short spike inside the history issue; fall back to importing without directory. Resolved in DEV-36: a temporary zsh-histdb database imported with `atuin import zsh-hist-db` preserves the directory. |
| ShellSpec has had no release since 2021. | Pin the version; the contract suite is plain enough to port to bats if needed. |
| The directive format could grow into a language. | The vocabulary in 6.5 is closed; anything else is native code in `env.<shell>` or `init.<shell>`. |
| fish users need zsh for the CLI and write-once commands. | Stated as a requirement; revisit with the Go helper under "maybe later". |
| Shims add a directory of generated executables to PATH. | The directory is per-host, mode 0700, regenerated by `render`, and holds no secrets. |
| A dev checkout as `MARKSHARC_HOME` can break every new shell. | The stub falls back to a minimal safe PATH and prints one error line when the core fails to load. |
| Is `cwf` itself public? | The public `cwf` module only calls documented `cwf` commands; if `cwf` is private the module moves to the overlay with no design change. |

## 12. Decision log

| Decision | Choice | Source |
|---|---|---|
| Legacy platforms and sites | Drop dead OS and Google/Manifest logic; live site code to the overlay | Interview |
| Workflow integrations | Generic parts public, Convoy-specific parts private | Interview |
| OMZ keepers | fzf-tab menu, Alt-arrow dir nav, coloured man, command-not-found | Interview |
| Cloud and k8s | Later | Interview, history |
| Version managers | nvm, gvm, pyenv kept; rbenv dropped | Interview |
| System helpers | ssh-agent, X11, docker, explicit installers kept; installers leave the core | Interview |
| ps and ls helpers | Keep all, fix, rebuild on procs and eza; bare `ls` and `ps` untouched | Interview |
| zoxide | Enabled | Interview |
| History | atuin only, with import | Interview |
| Startup output | Quiet; chatty `cs` and `li` | Interview |
| Interactive upgrades | Autosuggestions, syntax highlighting, colour defaults; Carapace opt-in without fzf-tab | Interview |
| Sync | Pull and notify in MVP; timer and ssh push after | Interview |
| Notify exception | Detached interactive fetch, throttled to 12 hours by default; cached behind notice on a subsequent eligible shell | Operator, DEV-45 |
| Overlay location | `mark-desktop-files/marksharc/` linked to `~/.config/marksharc` | Interview |
| Write-once language | zsh executables | Interview |
| Bash | Env-only in Modernization; approved full interaction on 4.4+, older versions env-only, no automatic exec; optional recommended ble.sh; delivery pending DEV-80–DEV-83 | Interview; operator, DEV-61 |
| Config format | Line directives, no parser dependency | Interview |
| `.` on PATH | Off by default; on in the author's overlay | Interview |
| Pre-migration depth | Full mirror of the target layout, in place | Interview |
| Plugin manager | None; built-in pinned loader | Research |
| Deployment tool | None imposed; own installer and stubs | Research |
| Test runner | ShellSpec plus a cross-shell contract suite | Research, existing suite |
| Version managers (revisited) | mise as an opt-in module that owns tools per host; shims for agent and batch shells, activation for interactive ones; nvm, gvm, and pyenv remain the default and the fallback | Operator, DEV-62 |
| Version-manager PATH order | gvm, nvm and pyenv paths in a `manager` tier ahead of Homebrew in every session class; correct manager behaviour wins over today's order | Operator, DEV-38 |
| Launch commands | `launch-session` and `launch-repo`; `cwf-new` runs inside the launched terminal; a foundation issue precedes the command. Full log in [LAUNCH-SPEC.md](LAUNCH-SPEC.md) section 13 | Operator, DEV-78 |
