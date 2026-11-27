# marksharc

Mark's shell RC files, rebuilt for the modern, agentic era.

marksharc is a modular shell framework for **zsh**, **fish**, and **Bash 4.4+**.
Older Bash can load the environment for scripts and agents. Functional areas are modules.
Configuration lives in a separate overlay that you own, so the framework
checkout stays read-only on every host.

> **Status:** early development. The zsh framework, the public modules, the
> installer, Bash startup, and `marksharc` bootstrap, update, and install commands
> are in place. Fish runs every module natively; see [docs/fish.md](docs/fish.md)
> for the parity table and how to retire an old fish configuration and fisher.

## Requirements

- macOS or Linux
- zsh 5.9 or later
- fish 4.x (optional)
- Bash 4.4 or later for interactive features, optional. The macOS Bash 3.2
  system shell supports the environment.
- git

The `marksharc` command uses zsh. Fish also uses it to refresh the environment
cache after changes to the framework or overlay.

## Install

The installer is POSIX `sh` and needs only `zsh` (5.9 or later) and `git`.
Either run it straight from GitHub:

```sh
curl -fsSL https://raw.githubusercontent.com/markfrommn/marksharc/main/install.sh | sh
```

or clone first, which keeps the checkout where you choose:

```sh
git clone https://github.com/markfrommn/marksharc.git
sh marksharc/install.sh
```

Then open a new terminal, or run `exec zsh -l`, `exec bash -l`, or `exec fish -l`.

What it does:

- **Framework.** Uses the checkout the script sits in, or `--home <checkout>`. Piped
  from `curl`, it clones the repository into `${XDG_DATA_HOME:-~/.local/share}/marksharc`
  (an existing clone is reused, never pulled; `MARKSHARC_REPO` names another repository).
- **Overlay.** Copies the skeleton from `templates/overlay/` to
  `${XDG_CONFIG_HOME:-~/.config}/marksharc` when nothing is there. `--overlay <path>`
  links an existing directory instead; `--overlay <url>` clones one. An overlay that
  already exists is never modified, and a different one requested with `--overlay` is an error.
- **Dotfiles.** Backs up `~/.zshenv`, `~/.zshrc`, `~/.zprofile`, `~/.zlogin`,
  `~/.zlogout`, `~/.bashrc`, `~/.bash_profile`, `~/.bash_login`, `~/.profile`
  and `~/.login` in
  `${XDG_STATE_HOME:-~/.local/state}/marksharc/backup/<timestamp>/`
  (symlinks are recorded by target), and writes zsh and Bash startup stubs. If the zsh core
  cannot load, the stub sets a minimal PATH and prints one line on stderr.
- **Fish.** Offers to back up the whole Fish configuration directory
  (`${XDG_CONFIG_HOME:-~/.config}/fish`), including plugins and universal
  variables, and replace it with only `conf.d/00-marksharc.fish`. The prompt
  defaults to no. If you decline, the installer keeps your configuration and
  adds the MarkSharc stub when its slot is available. If a custom file occupies
  that slot, the installer warns and continues with zsh and Bash.
- **Plugins.** Clones pinned plugins (fzf-tab, nvm.fish and fzf.fish) into
  `${XDG_CACHE_HOME:-~/.cache}/marksharc/plugins/`. Shell startup never fetches them. A
  failed fetch, when offline for example, leaves the install in place with a warning;
  `marksharc update` fetches them later. `--no-plugins` skips this step.
- **Login shell.** It never runs `chsh`; it prints the command when your login shell is not zsh.

`sh install.sh --coexist` installs alongside your existing zsh startup files
instead of backing them up or redirecting `ZDOTDIR`: it writes managed coexist
stubs under `${XDG_STATE_HOME:-~/.local/state}/marksharc/coexist/` and adds one
marked source line to `~/.zshenv` and `~/.zshrc` while leaving your existing
zsh, Bash, and Fish startup files in place. `marksharc uninstall` removes those
source lines and the coexist stubs while keeping your own edits.

`sh install.sh --clobber` answers yes to optional cleanup. For the piped install,
pass the flag as `| sh -s -- --clobber`. Without a terminal, optional cleanup
defaults to no unless you pass `--clobber`. Add `--dry-run` to preview the
actions without prompting or changing files. Reruns keep the original backups
and the existing overlay.

Day 1:

```sh
marksharc module list              # enabled, disabled and skipped modules
marksharc module disable <name>    # edits config.conf in your overlay
marksharc reload                   # apply it in this shell (--verbose to trace)
marksharc render                   # refresh cached env, completions and command shims
marksharc bootstrap                # install declared packages
marksharc sync                     # fast-forward safe checkouts and refresh pins
marksharc sync --auto              # quiet, locked sync for timers (skips dirty trees)
marksharc sync --update [--system] # run full marksharc update (with optional OS updates)
marksharc sync timer on|off|status # manage launchd (macOS) or systemd user (Linux) timer
marksharc hosts populate           # pick push hosts from ~/.ssh/config and `hc machine ls`
launch-session [host:]directory    # open a terminal in a local or remote directory
launch-repo [host:]repo[/worktree]  # open an existing repository or worktree
cwf-new --repo REPO --host HOST BRANCH # create a worktree in a new terminal
marksharc push [options] [regex…]  # run sync (or --update/--system) over SSH in parallel
marksharc doctor                   # report local health
marksharc update                   # sync, plugin pins and module update steps
marksharc update --system [-y]     # include native OS updates via sudo (no-op on macOS)
marksharc update --list            # list available step labels
marksharc update --only <label>    # run one step; --dry-run previews commands
marksharc install <name>           # run a registered explicit installer
marksharc version
marksharc uninstall                # restore backed-up dotfiles and remove managed stubs
```

`marksharc uninstall --purge` also deletes the cache, the state and a clone made by the
installer (it asks first; `--yes` answers). It never removes your overlay or a checkout you
passed with `--home`. If you chose Fish cleanup, uninstall puts the original
Fish directory back. It saves files created in the replacement directory beside
the restored configuration.

Sync uses each checkout's configured Git upstream. It reports dirty, ahead, diverged,
detached or unavailable repositories without merging them. It finds the owning Git
checkout of the overlay, including a linked overlay subdirectory. Add extra checkout
paths in `config.conf`, quoting paths that contain spaces:

```text
set sync.repos "$HOME/work/one" "$HOME/work/two"
set sync.check_hours 12
set sync.timer_minutes 60
set sync.push_timeout 60
set sync.push_parallel 8
set doctor.startup_ms 500
set doctor.startup_timeout_ms 5000
```

`doctor` times an interactive startup against `doctor.startup_ms` and gives up after
`doctor.startup_timeout_ms`, reporting the startup as timed out. It reports a missing
`requires command` only for a module that the overlay names with a `module <name>` line (in `config.conf`
or `hosts/<host>.conf`);
a module enabled by default skips itself when its command is absent.

An assignment in `hosts/<hostname>.conf` replaces the global `sync.repos` list.

Bootstrap consumes `package brew|cask|apt|dnf <name>` directives from enabled modules
and overlay configuration. Homebrew must already be installed to process brew packages;
the command writes a temporary Brewfile and runs `brew bundle`. On Linux it prints each
apt or dnf command and asks before invoking sudo. An empty selection needs no manager.
Overlay `packages/*.Brewfile` files accept data-only `brew "name"` and `cask "name"`
lines; `*.darwin.Brewfile` and `*.linux.Brewfile` apply only on the named platform.
Files ending `.apt` or `.dnf` contain one package name per line. Comments and blank
lines are allowed. Bootstrap rejects arbitrary Ruby and package-manager flags.

Modules and overlay configuration register `update <label> <command> [args...]` and
`installer <name> <script>`. Arguments are parsed as data, not shell code. Relative
installer paths and update executable paths beginning `./` resolve from the declaring
module or overlay root. Missing update commands are skipped; other failures are reported
after remaining steps run. `marksharc install` runs only an executable registered script.
The included installer names are `krew`, `gvm`, `wezterm-terminfo`, `pyenv`, `nvm`, `mise` and `ble.sh`.

For per-host Node, Go, Python, and Ruby ownership through mise, including startup behavior,
fallback, compatibility commands, and migration, see [the mise guide](docs/mise.md).

The interactive layer is on by default and degrades to native behaviour for each missing tool:

| Module | What it adds | Options |
| --- | --- | --- |
| `zsh-autosuggestions` | Suggestions from atuin, then the session history and completion | `strategy`, `async` |
| `zsh-syntax-highlighting` | Command-line highlighting, loaded after every other module | `highlighters` |
| `theme` | vivid `LS_COLORS`, bat as man pager, fzf defaults and bat/eza previews; delta for git when enabled | `ls_colors`, `man_pager`, `bat_theme`, `delta`, `fzf` |
| `ps` | The ps helpers drawn by procs | `procs` |
| `launch` | Open a local or remote terminal through Herdr Core, Herdr TUI or tmux | `prefer`, `place`, `focus` |
| `prompt-starship` | A starship config file or the bundled `rich` preset | `config` |
| `completion-carapace` | Opt-in Carapace completion for zsh and Bash | `enable`, `bridges`, `excludes`, `allow_fzf_tab` (zsh) |
| `line-editor-ble` | Optional Bash editor with suggestions, highlighting, and menu completion | |

In zsh, switch between `fzf-tab` and `carapace` persistently via `set completion-carapace.enable on|off`
or for a single session with `completion-ui carapace|fzf-tab|both|native|reset` (followed by
`exec zsh -l`).

The two plugins are pinned clones: `marksharc update` (or `zsh-plugin-update`) fetches them,
and startup only loads clones that exist. `marksharc bootstrap` installs the tools the modules
declare (eza, procs, vivid, bat, git-delta, fzf, fd, starship, carapace).

```text
set theme.delta on
set theme.ls_colors nord
set prompt-starship.config rich
```

The same module and host conf files accept declarative environment lines. Values use shell-word
quoting; `~` and `$NAME` are references, never command substitution. `when command`, `dir` and
`file` guards run in the next shell, while `os` and `host` guards are settled by `render`.

```text
path user ~/bin
env EDITOR "emacs -nw"
alias ll "ls -lA" when command ls
tiers "manager brew system user app local"
```

`marksharc render` writes per-host `env.zsh`, `env.bash` and `env.fish` in the cache,
along with rendered declarative completions (zsh, Bash 4.4+, Fish, and Carapace YAML),
generated completions, and command shims. When `completion-carapace` is enabled, render
also reconciles manifest-tracked symlinks in Carapace's specs directory without touching
user-authored specs.
Startup refreshes stale env without running generators or changing Carapace symlinks;
install, update and explicit reload refresh the generated artifacts. Render again after
adding or removing a provider, Herdr session, or `.comp` file. See
[docs/completions.md](docs/completions.md) for declarative completion authoring and
Carapace lifecycle details.
The `cwf shell zsh` contract is shell integration rather than a completion definition: render caches
its exports, aliases and helpers at the same artifact path, and only interactive cwf init sources it.

Module commands and generated provider and session shims are on PATH in zsh, Fish, and Bash
and are inherited by child processes. Native wrappers apply caller-state changes
for commands such as `cwf-new` in all three shells. See the
[write-once command and provider migration guide](docs/write-once.md) for configuration and hooks.

## Interactive Bash

Open the Bash 4.4+ executable you want to use. Login and non-login terminals
load the same interactive features. Older Bash, no-TTY sessions, and configured
agents use the environment layer.

Run `marksharc install ble.sh` with Git, GNU make, and GNU awk available to build
the pinned editor in the plugin cache. `marksharc update --only ble-sh` refreshes
an existing installation when the pin changes. Open a fresh Bash session after
installing it. `module line-editor-ble off` in the overlay selects Readline.
Readline supplies completion and listing, and ble.sh adds a selectable menu,
suggestions, and highlighting.

Bash loads bash-completion when installed. Set `completion-carapace.enable` to
`on` to add Carapace, with `completion-carapace.bridges` and
`completion-carapace.excludes` for its command sources. When Carapace is active,
it owns commands with managed specs (`marksharc`, `launch-session`, `launch-repo`,
`cwf-new`) unless excluded via `CARAPACE_EXCLUDES` (falling back to native Bash
completions when inactive or excluded); zoxide, CWF (`cwf`), and Herdr retain their
own registrations. Run
`completion-ui status` to see the active and pending editor and completion
provider. `completion-ui readline|ble|native|carapace|reset` sets or clears a
session override. Apply backend and Carapace setting changes with an explicit
`exec bash -l`. `marksharc reload` applies ordinary module changes in place.

With fzf 0.48 or later, Ctrl-T inserts selected files and Alt-C changes to a
selected directory. Atuin owns Ctrl-R and Up when it initializes successfully.
Otherwise Bash keeps native history at
`${XDG_STATE_HOME:-$HOME/.local/state}/marksharc/history.bash`. Directory-driven
integrations run before the next prompt, so `cd project; node …` may run before
an automatic version switch. Run `marksharc doctor` for the active editor and
history mode and any missing build prerequisites.

## Bash and agents

Bash login and interactive shells load the MarkSharc environment from the installed stubs.
For noninteractive Bash processes started by agents, opt in through the overlay:

```text
set agent.bash_env on
```

Run `marksharc reload`, or start a new zsh session, then launch the agent:

```sh
SHELL=/bin/bash claude
SHELL=/bin/bash codex
```

The option exports `BASH_ENV` so Bash loads the environment in `bash -c`. It is off by
default. Enabling it replaces an existing `BASH_ENV` value for children. A child of an
already configured shell also inherits its environment. Re-run the
installer to add the Bash stubs to an existing installation. `marksharc uninstall` restores
the original startup files from the recorded backup.

An eligible interactive zsh shell starts a detached fetch when the last check is older
than `sync.check_hours` (12 hours by default). A later interactive shell prints a
notice when the cached result is behind. The fetch does not merge or update plugins;
set `MARKSHARC_NOTIFY=0` to suppress the notice and background check for a session.

## Migrating legacy zsh history

The `history-atuin` module ships a one-shot importer at
`modules/history-atuin/bin/import-legacy-history` (available on `PATH` as
`import-legacy-history` once `atuin` is installed and `history-atuin` is active;
invoke it by full path for `--dry-run` before installing `atuin`).

```sh
import-legacy-history --dry-run
import-legacy-history
import-legacy-history --source ~/.zsh_history-otherhost --tree ~/.cache/zsh-directory-history-otherhost
```

By default it reads `~/.zsh_history`, `~/.zhistory`, `$ZDOTDIR/.zsh_history`,
and `~/.cache/zsh-directory-history`, deduplicates entries on `(timestamp,
command)` preferring copies with a directory, and imports via a temporary SQLite
`zsh-histdb` database (`--route auto` / `histdb`, preserving directories and
host labels when `sqlite3` is available, or falling back to `--route plain`
without directories). Passing any `--source FILE[=LABEL]` or `--tree
DIR[=LABEL]` replaces the defaults; conventional `-<NAME>` suffixes on copied
files set the host label automatically. Re-running on the same route adds no
duplicate rows, while switching routes can duplicate imported rows; imported
rows are not deduplicated against Atuin's own live recording. Running an import
against a real home directory and verifying with `atuin stats` and `history |
egrep <pattern>` is an operator step — automated tests never touch a real Atuin
database.

## Layout

| Path | Contents |
| --- | --- |
| `install.sh` | Day 0 installer (POSIX sh) |
| `bin/marksharc` | The `marksharc` command |
| `core/` | Per-shell loaders (`zsh/`, `fish/`, `bash/`) and CLI commands (`cli/`) |
| `modules/` | Public modules, one directory each |
| `templates/overlay/` | Skeleton for a new `~/.config/marksharc` overlay |
| `tests/` | ShellSpec suites, lint and fixtures |
| `docs/` | User and developer documentation |
| `specs/` | Design specification and programme plan |
| `memory/` | Shared workflow memory notes |

## Documentation

- [Developing marksharc](docs/DEVELOPING.md)
- [Completions and Carapace](docs/completions.md)
- [Tests](tests/README.md)
- [Multiplexer titles, forwarding, and adapters](docs/MUX-ADAPTERS.md)
- [Launch a terminal session](docs/launch.md)
- [Specification](specs/MARKSHARC-SPEC.md) and [plan](specs/MARKSHARC-PLAN.md)

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
