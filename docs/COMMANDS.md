# Command reference

`marksharc <command> [args]` runs one of the commands below. `marksharc help` prints the list.
The command needs zsh, whichever shell you call it from.

Conventions:

- A usage error prints a message on stderr and exits with status 2.
- Commands that take `-h` or `--help` print their usage and exit 0.
- Nothing here writes to the framework checkout. Output goes to your overlay only where a
  command says so, and otherwise to the cache and state directories.

| Command | Purpose |
| --- | --- |
| [`reload`](#reload) | Apply configuration changes in the current shell |
| [`render`](#render) | Rebuild the cached environment, completions and shims |
| [`module`](#module) | List, enable and disable modules |
| [`doctor`](#doctor) | Report installation and repository health |
| [`sync`](#sync) | Fast-forward the framework, the overlay and listed repositories |
| [`sync timer`](#sync-timer) | Manage the automatic sync timer |
| [`push`](#push) | Run sync on other hosts over SSH |
| [`hosts`](#hosts) | Manage the host inventory |
| [`update`](#update) | Sync, refresh plugins and run update steps |
| [`bootstrap`](#bootstrap) | Install declared packages |
| [`install`](#install) | Run one registered installer |
| [`uninstall`](#uninstall) | Restore your dotfiles and remove the stubs |
| [`version`](#version) | Print the version |

The installer has its own options; see [Install](USERGUIDE.md#install) in the user guide.

## reload

```text
marksharc reload [--verbose]
```

Applies changes to the shell you are in: it renders if any input changed, rebuilds the
environment and PATH, and re-runs the interactive setup.

- `--verbose` (`-v`) prints the module trace: what loaded, what was skipped and why, and
  per-module timings.
- `cs` is a verbose reload. `li` is the same and, in zsh, also re-runs the login-only steps.

`reload` is a shell function, because a program cannot change the shell that started it. Run
from a script or a non-marksharc shell, it explains this and exits 1. If rendering fails, the
last good environment stays active and `reload` returns 1.

Switching the completion interface or the Bash line editor needs a fresh shell
(`exec zsh -l` or `exec bash -l`), not a reload.

## render

```text
marksharc render
```

Writes the per-host cache from the enabled modules and your overlay:

- `env.zsh`, `env.bash` and `env.fish`: the rendered `path`, `env` and `alias` lines;
- generated and declarative completions;
- command shims for providers and Herdr sessions;
- when `completion-carapace` is enabled, the managed links in Carapace's specs directory.

Startup refreshes a stale environment by itself, but it never runs a completion generator.
Run `render` after adding or removing a provider file, a `.comp` spec or a Herdr session.
`install.sh`, `update` and `reload` render for you.

## module

```text
marksharc module list
marksharc module enable <name>
marksharc module disable <name>
```

`list` prints one line per module: name, state and description. The state is `enabled`,
`disabled`, or `skipped` with the reason (`requires command <c>` or `requires os <o>`). Private
modules in your overlay are included.

`enable` and `disable` edit the `module` lines of `config.conf` in your overlay, and tell you to
run `marksharc reload`. They change nothing else in the file. See
[choosing modules](USERGUIDE.md#choosing-modules) for how the two selection styles behave.

## doctor

```text
marksharc doctor
```

A read-only report. Each finding is one line starting `doctor:`; the last line is the count,
`doctor: N issue(s)`. The exit status is 0 whatever it finds.

| Area | What it reports |
| --- | --- |
| Stubs | A missing, unmanaged or modified `~/.zshenv`, Bash or Fish stub; a stale generated zsh startup directory; in coexist mode, a missing source line or stub |
| Overlay | A broken overlay link |
| Foreign dotfiles | Lines in `~/.zshrc`, `~/.zprofile`, `~/.bashrc` and Fish's `config.fish` that the shell does not read, with line numbers |
| Plugins | A pinned plugin that is missing or at the wrong commit; leftover fisher files |
| Commands | A command required by a module that your overlay enables by name |
| Repositories | A checkout that is dirty, ahead or behind, or that cannot be inspected |
| PATH | Duplicate entries |
| Environment | A stale environment ID, meaning the shell predates a change |
| Completion | A missing `carapace`; missing, broken or conflicting managed Carapace spec links |
| Providers | Legacy `.provider` files, or a configured provider directory with no `.conf` files |
| mise | `mise.tools` set without `mise` installed; a conflicting `~/.python-version` |
| Bash | The Bash version and whether it is environment-only; the active line editor, completion and history backends |
| Startup time | An interactive startup slower than `doctor.startup_ms`; one that blocks on a prompt (the prompt is quoted) or exceeds `doctor.startup_timeout_ms` |

A module that is enabled by default and skips itself for a missing command is not a finding.

## sync

```text
marksharc sync [--auto] [--update [--system] [-y]]
```

Brings each checkout up to date when its upstream is a safe fast-forward. The checkouts are the
framework, the git repository that contains your overlay, and any paths in `sync.repos`.

For each checkout it prints one line: `updated`, `current`, `dirty`, `ahead`, `diverged`,
`detached`, `no upstream`, `fetch failed` and similar. Nothing is merged, and a checkout that is
not a clean fast-forward is left as it is. Sync then refreshes the pinned plugins and prints a
`doctor` summary. It exits non-zero when any checkout could not be brought current.

| Option | Effect |
| --- | --- |
| `--auto` | For timers: quiet, locked against a concurrent run, skips dirty checkouts, renders, and logs to the state directory. |
| `--update` | Run the full [`update`](#update) instead of a plain sync. |
| `--system` | With `--update`, also run the operating system's package updates. |
| `-y`, `--yes` | With `--update`, pass `-y` to commands that accept it. |

### sync timer

```text
marksharc sync timer on|off|status
```

Installs, removes or reports a per-user timer that runs `marksharc sync --auto`. It is a
launchd agent on macOS and a systemd user timer on Linux. The interval is `sync.timer_minutes`
(60 by default). The timer only ever runs `sync --auto`; `--update` is not accepted here.

## push

```text
marksharc push [options] [host-or-regex...]
```

Runs `marksharc sync` over SSH on the hosts in your overlay's `hosts.conf`, in parallel, and
prints a table of `HOST`, `STATUS` (`ok`, `failed` or `timeout`), `DURATION` and `DETAIL`. With
no argument it targets every host. An argument is a host name or a regular expression matched
against the configured names. The exit status is non-zero when any host failed or timed out.

| Option | Effect |
| --- | --- |
| `--update` | Run `marksharc sync --update` on each host. |
| `--system` | Run `marksharc sync --update --system` on each host. |
| `-y`, `--yes` | With `--update` or `--system`, pass `-y` to commands that accept it. |
| `--timeout <seconds>` | Per-host timeout. Default: `sync.push_timeout`, else 60, or 300 with `--update`. |
| `--max-parallel <n>` | Maximum concurrent SSH jobs. Default: `sync.push_parallel`, else 8. |
| `--dry-run` | Show the matched hosts and the SSH commands without running them. |
| `-v`, `--verbose` | Print each host's full output below the table. |
| `--populate` | Run `hosts populate` first. |

## hosts

```text
marksharc hosts [list]
marksharc hosts populate [--all] [--source ssh|hc]
marksharc hosts add <name> [<ssh-target>]
marksharc hosts remove <name>
```

Manages `hosts.conf` in your overlay, the inventory used by `push` and the launch commands.

- `list` prints each host, with its SSH target when that differs from the name.
- `populate` discovers hosts from `~/.ssh/config` and from `hc machine ls`, and lets you pick
  which to add, using `gum` or `fzf`. `--all` adds every discovered host. `--source` limits
  discovery to one source.
- `add` appends a host. Without an SSH target, the name itself is passed to `ssh`.
- `remove` deletes a host.

## update

```text
marksharc update [--list] [--dry-run] [--only <label>] [--system] [-y]
```

Runs the Day 2 steps in order: `sync`, `pins` (the pinned plugins), each update step that
enabled modules and your overlay register, optionally `system`, then `render`. A failed step
does not stop the rest; each step's result is reported and the exit status is non-zero if any
failed. A step whose command is not installed is skipped.

| Option | Effect |
| --- | --- |
| `--list` | Print the step labels and exit. |
| `--dry-run` | Print each step's command without running it. |
| `--only <label>` | Run one step. An unknown label is an error. |
| `--system` | Add the native package manager update, through `sudo`. It does nothing on macOS. |
| `-y`, `--yes` | Pass `-y` to commands known to accept it. |

Modules register steps with `update` lines; the [module reference](MODULES.md) shows them
under "Update steps".

## bootstrap

```text
marksharc bootstrap
```

Installs the packages declared by `package` lines in enabled modules and your overlay, plus the
package lists in your overlay's `packages/` directory.

- **Homebrew** packages and casks are written to a temporary Brewfile and installed with
  `brew bundle`. Homebrew must already be installed. Casks apply on macOS only.
- **apt** and **dnf** packages, on Linux, are printed as one `sudo <manager> install …` command
  each. Bootstrap asks before running it. A manager that is not installed is skipped.

Bundle files are read as data. A line that is not a plain `brew "name"` or `cask "name"`
declaration is an error, so arbitrary Ruby and package-manager flags are rejected.

## install

```text
marksharc install <name>
```

Runs one installer script that a module or your overlay registered with an `installer` line.
Installers cover tools that need more than a package, such as `nvm`, `gvm`, `pyenv`, `mise`,
`krew`, `ble.sh` and `wezterm-terminfo`. An unknown name is an error. The
[module reference](MODULES.md) lists each module's installers.

Nothing is ever installed at shell startup; this command and `bootstrap` are the only ways.

## uninstall

```text
marksharc uninstall [--purge] [--yes]
```

Restores the startup files that `install.sh` backed up, and removes the stubs and the generated
zsh startup directory. In coexist mode it removes the two marked source lines and keeps your own
edits. If you chose the clean Fish configuration, it restores your original Fish directory and
keeps anything you created since beside it. Managed Carapace spec links are removed.

Every check runs before the first change. If anything would be lost, nothing is changed and the
problems are listed. A stub you edited by hand is saved, and the message says where.

| Option | Effect |
| --- | --- |
| `--purge` | Also delete the cache, the state directory, and a framework clone the installer made. Asks for confirmation. |
| `--yes`, `-y` | Answer the `--purge` confirmation. Required when there is no terminal. |

Your overlay is never removed. A framework checkout you passed with `--home` is never removed.

## version

```text
marksharc version
```

Prints the version from the `VERSION` file and, when the framework is a git checkout, the
`git describe` output. `marksharc -V` and `--version` do the same.

## Commands that modules add

Modules put their own commands on PATH or define them as shell functions. These are the ones
most people use. The [module reference](MODULES.md) lists every module's executables and
functions.

| Command | Module | Purpose | More |
| --- | --- | --- | --- |
| `launch-session`, `launch-repo` | `launch` | Open a terminal in a local or remote directory or repository | [launch.md](launch.md) |
| `cwf-new` | `cwf` | Create a worktree, optionally in a new terminal | [launch.md](launch.md) |
| `gwt-clean`, `repo-sync`, `repo-list` | `git-worktree` | Remove a finished worktree; update and list repositories | [write-once.md](write-once.md) |
| `import-legacy-history` | `history-atuin` | Import old zsh history into atuin | [User guide](USERGUIDE.md#importing-old-zsh-history) |
| `history`, `h` | `history-atuin` | List history from atuin | |
| `completion-ui` | `completion` | Show or switch the completion interface for a fresh shell | [SHELLS.md](SHELLS.md) |
| `zsh-plugin-update` | `completion-fzf-tab` | Fetch the pinned zsh plugins | |
| `setup-ssh-agent`, `clean-ssh-agents` | `ssh-agent` | Find or start an agent; remove stale ones | |
| `refresh-env`, `fix-tmux` | `mux` | Re-import forwarding variables into a long-lived shell | [MUX-ADAPTERS.md](MUX-ADAPTERS.md) |
| `set-title` | `titles` | Set the terminal, tab or pane title | [MUX-ADAPTERS.md](MUX-ADAPTERS.md) |
| `cleanup-docker`, `fix-docker-socket` | `docker` | Docker housekeeping | |
| `pss`, `psj`, `pssu` and related | `ps` | Process listings, identical on macOS and Linux | |
| `run-fish` | `fish-bridge` | Start a login fish with a curated environment | |
