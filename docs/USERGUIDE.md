# User guide

This guide takes you from a first install to running marksharc on several hosts. For exact
syntax, follow the links to the [command](COMMANDS.md), [configuration](CONFIGURATION.md) and
[module](MODULES.md) references.

- [How it fits together](#how-it-fits-together)
- [Install](#install)
- [Your overlay](#your-overlay)
- [Choosing modules](#choosing-modules)
- [Settings](#settings)
- [PATH, variables and aliases](#path-variables-and-aliases)
- [Applying changes](#applying-changes)
- [Installing tools](#installing-tools)
- [Keeping hosts in sync](#keeping-hosts-in-sync)
- [Checking health](#checking-health)
- [Agents and scripts](#agents-and-scripts)
- [Importing old zsh history](#importing-old-zsh-history)
- [Troubleshooting](#troubleshooting)
- [Uninstall](#uninstall)

## How it fits together

marksharc keeps three things apart:

| What | Where | Who changes it |
| --- | --- | --- |
| **Framework**: the core and the public modules | `~/.local/share/marksharc`, or wherever you cloned it | Nobody on the host. You update it with `marksharc sync`. |
| **Overlay**: your configuration | `~/.config/marksharc` | You. |
| **Cache and state**: rendered files, plugin clones, backups | `~/.cache/marksharc` and `~/.local/state/marksharc` | marksharc. Safe to delete; it is rebuilt. |

Three ideas explain most of the behaviour.

**Modules.** A module is one functional area, such as `history-atuin` or `prompt-starship`. Every
module is on by default and skips itself quietly when the tool it wraps is not installed. You
switch modules off in your overlay.

**Session classes.** Each shell decides once what kind of session it is:

| Class | When | What runs |
| --- | --- | --- |
| `interactive` | A person at a terminal | The environment, then the interactive setup: prompt, completion, key bindings, history |
| `agent` | An AI agent or an editor started the shell | The environment only, with no output |
| `batch` | Scripts, `ssh host command`, cron | The environment only, with no output |

So a script or an agent sees the same PATH and variables as your terminal, and never a prompt, a
greeting or a stray message.

**Render, then start.** Your `path`, `env` and `alias` lines are turned into plain shell files
in the cache by `marksharc render`. Startup reads those files. That is why startup is fast, and
why some changes need a `render` or a `reload` before you see them.

## Install

You need zsh 5.9 or later and git. The installer is POSIX `sh`.

```sh
git clone https://github.com/markfrommn/marksharc.git
sh marksharc/install.sh
```

A clone keeps the framework where you put it. Piped from `curl`, the installer clones into
`${XDG_DATA_HOME:-~/.local/share}/marksharc` instead:

```sh
curl -fsSL https://raw.githubusercontent.com/markfrommn/marksharc/main/install.sh | sh
```

Then open a new terminal, or run `exec zsh -l`, `exec bash -l` or `exec fish -l`.

### What the installer changes

| Step | What happens |
| --- | --- |
| Framework | Uses the checkout the script sits in, or the one named by `--home`. An existing clone is reused and never pulled. |
| Overlay | Copies `templates/overlay/` to `~/.config/marksharc` when nothing is there. An existing overlay is never modified. |
| zsh and Bash files | Moves `~/.zshenv`, `~/.zshrc`, `~/.zprofile`, `~/.zlogin`, `~/.zlogout`, `~/.bashrc`, `~/.bash_profile`, `~/.bash_login`, `~/.profile` and `~/.login` into `~/.local/state/marksharc/backup/<timestamp>/`, then writes small stubs. |
| Fish | Adds `~/.config/fish/conf.d/00-marksharc.fish`. It also offers to back up your whole Fish configuration and start clean; the answer defaults to no. |
| Plugins | Clones the pinned plugins into `~/.cache/marksharc/plugins/`. If the fetch fails, the install still succeeds and `marksharc update` fetches them later. |
| Login shell | Nothing. It prints the `chsh` command when your login shell is not zsh. |

If the zsh core ever fails to load, the stub sets a minimal PATH and prints one line, so a
broken checkout cannot lock you out.

### Options

| Option | Effect |
| --- | --- |
| `--home <dir>` | Use this checkout as the framework. |
| `--overlay <path>` | Link an existing directory as your overlay. |
| `--overlay <url>` | Clone a git repository as your overlay. |
| `--coexist` | Keep your existing zsh, Bash and Fish startup files. Adds one marked line to `~/.zshenv` and one to `~/.zshrc`. |
| `--dry-run` | Print every action and change nothing. |
| `--clobber` | Answer yes to optional cleanup, such as the clean Fish configuration. Cannot be combined with `--coexist`. |
| `--no-plugins` | Skip the plugin fetch. |

For the piped install, pass options after `sh -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/markfrommn/marksharc/main/install.sh | sh -s -- --dry-run
```

Running the installer again is safe. It keeps the original backup and the existing overlay.

### Trying it without committing

`--coexist` is the low-risk way to try marksharc on a host that already has a zsh setup you
like. Your startup files stay in place and marksharc loads beside them. `marksharc uninstall`
removes the two added lines and keeps your own edits. [SHELLS.md](SHELLS.md#zsh) explains the
difference between the two modes.

## Your overlay

Your overlay is the only place you edit. The installer creates this skeleton:

| Path | Purpose |
| --- | --- |
| `config.conf` | Module selection, settings, and your `path`, `env` and `alias` lines |
| `hosts/<host>.conf` | The same kinds of line for one host, read after `config.conf` |
| `hosts.conf` | The list of hosts for `marksharc push` and the launch commands |
| `local/post.zsh` | Your own zsh code, run at the end of interactive startup |
| `local/post.bash`, `local/post.fish` | The same for Bash 4.4+ and fish |
| `modules/<name>/` | Your own private modules |
| `packages/` | Package lists for `marksharc bootstrap` |
| `providers/` | Provider files for the `cc-providers` module |

`<host>` is the short host name, the part of `hostname` before the first dot.

Keep the overlay in a git repository of your own. That is how your configuration reaches your
other hosts: `marksharc sync` fast-forwards the overlay along with the framework. On a new host,
`sh install.sh --overlay <url>` clones it for you.

Nothing personal belongs in the framework. If you find yourself wanting to edit a file under
`modules/`, set an option, add a line to `local/post.zsh`, or write a
[private module](MODULE-AUTHORING.md#private-modules) instead.

## Choosing modules

```sh
marksharc module list
```

Each line shows a module, its state and its description. The state is `enabled`, `disabled`, or
`skipped` with the reason, such as a missing command.

```sh
marksharc module disable greeting
marksharc module enable greeting
```

These edit the `module` lines in `config.conf`. You can edit them by hand too:

```text
module zoxide off
```

There are two ways to select modules, and they behave differently:

- **Everything except what you switch off.** This is the default. With no plain `module <name>`
  line, every module loads unless a `module <name> off` line names it. New modules arrive
  enabled when you update.
- **Only what you name.** As soon as `config.conf` has one plain `module <name>` line, only the
  modules you name load. Use this when you want a fixed, minimal set.

Most people want the first. Do not add a plain `module <name>` line just to "turn on" one
module: it switches every unnamed module off.

A few modules are present but do nothing until you opt in with a setting: `greeting`, `direnv`,
`mise` and `completion-carapace`. The [module reference](MODULES.md) lists every module and its
options.

## Settings

A setting is one line in `config.conf`:

```text
set <module>.<key> <value>
```

For example:

```text
set editor.command "emacs -nw"
set theme.delta on
set prompt-starship.config rich
set git-worktree.roots "$HOME/src $HOME/work"
```

Quote a value that contains spaces. `~` and `$NAME` are expanded; nothing else is, and no
command is ever run. A line in `hosts/<host>.conf` overrides the same setting in `config.conf`
on that host.

The [module reference](MODULES.md) lists each module's options with their defaults. A handful
of settings belong to the core, such as `sync.check_hours`; they are in the
[configuration reference](CONFIGURATION.md#core-settings).

## PATH, variables and aliases

Declare these once and they work in zsh, Bash and fish:

```text
path user ~/bin
env EDITOR "emacs -nw"
alias ll "ls -lA"
```

A line can carry a condition:

```text
path user ~/go/bin          when dir ~/go/bin
alias cat bat               when command bat
env BROWSER open            when os darwin
```

`path` takes a *tier* as its first word. Tiers decide the order of PATH: for example, `first`
puts a directory ahead of everything, and `user` is where `~/bin` belongs. The
[configuration reference](CONFIGURATION.md#path-tiers) lists the tiers and how to reorder them.

Anything these lines cannot express goes in `local/post.zsh` as ordinary shell code.

## Applying changes

| You changed | Run |
| --- | --- |
| A `module`, `set`, `path`, `env` or `alias` line | `marksharc reload` |
| `local/post.zsh` | `marksharc reload` |
| A provider file, a `.comp` completion spec, or the set of Herdr sessions | `marksharc render`, then `marksharc reload` |
| The completion interface (fzf-tab or Carapace), or the Bash line editor | A fresh shell: `exec zsh -l` or `exec bash -l` |

`marksharc reload` applies changes to the shell you are in. It renders first if anything
changed. Add `--verbose` to see which modules loaded, which were skipped and why, and how long
each took. The aliases `cs` and `li` are verbose reloads.

A new terminal always picks up changes: startup notices stale rendered files and refreshes them.

## Installing tools

marksharc works with whatever is installed and degrades gracefully without the rest. To install
the tools the modules are built around:

```sh
marksharc bootstrap
```

On macOS, and on Linux with Homebrew, this runs `brew bundle` over the packages that enabled
modules declare. On Linux it also prints each `apt` or `dnf` command and asks before using
`sudo`. Homebrew itself must already be installed.

The modules declare the tools they draw with: starship, fzf, fd, eza, bat, procs, vivid,
git-delta, carapace and mise. Other tools that modules wrap, such as atuin, zoxide, direnv and
nvm, are yours to install. Each module notices its tool in the next shell.

Add your own packages as files in the overlay's `packages/` directory; see
[package lists](CONFIGURATION.md#package-lists).

Some tools need more than a package. Those have explicit installers:

```sh
marksharc install nvm
```

The available names are listed per module in the [module reference](MODULES.md), under
"Installers".

## Keeping hosts in sync

Each host has two git checkouts: the framework and your overlay.

```sh
marksharc sync
```

This fetches both and fast-forwards each one when that is safe. A checkout that is dirty, ahead,
diverged or detached is reported and left alone; marksharc never merges for you. To include
other repositories:

```text
set sync.repos "$HOME/work/one" "$HOME/work/two"
```

`marksharc update` does everything `sync` does, then refreshes the pinned plugins, runs each
module's update step (for example `brew upgrade`), and renders. Use `--list` to see the steps,
`--only <label>` to run one, and `--dry-run` to preview.

### Being told when a host is behind

An interactive zsh or Bash shell starts a background fetch when the last check is older than
`sync.check_hours` (12 by default). The next shell you open prints one line if the host is
behind:

```text
marksharc: updates available (run marksharc sync)
```

The fetch never merges and never updates plugins. Set `MARKSHARC_NOTIFY=0` to turn it off for a
session.

### Updating automatically

```sh
marksharc sync timer on            # launchd on macOS, a systemd user timer on Linux
marksharc sync timer status
marksharc sync timer off
```

The timer runs `marksharc sync --auto` every `sync.timer_minutes` (60 by default). `--auto` is
quiet, takes a lock, skips dirty checkouts and logs to the state directory.

### Updating other hosts from here

List your hosts once, then push:

```sh
marksharc hosts populate           # pick hosts from ~/.ssh/config
marksharc hosts add build admin@build.example.com
marksharc push                     # run sync on every host, in parallel
marksharc push --update 'web.*'    # run a full update on hosts matching a regex
```

`push` connects over SSH, runs `marksharc sync` on each host and prints a result table. Add
`--dry-run` to see which hosts and commands it would use.

## Checking health

```sh
marksharc doctor
```

Doctor changes nothing. It reports one line per finding and ends with a count. It checks:

- the startup stubs and the generated zsh startup directory;
- lines that other installers added to dotfiles the shell no longer reads;
- pinned plugins that are missing or at the wrong commit;
- commands missing for modules you enabled by name;
- repositories that are dirty, ahead or behind;
- duplicate PATH entries;
- how long an interactive shell takes to start, against `doctor.startup_ms` (500 by default).

Run it after an install, after an update, and whenever the shell behaves oddly.

## Agents and scripts

Shells started by AI agents and scripts load the full environment and print nothing. marksharc
recognises an agent by environment variables such as `CLAUDECODE`. To add your own:

```text
set agent.markers "CLAUDECODE AI_AGENT MY_TOOL_SESSION"
```

This replaces the default list, so include the defaults you still want. They are listed in the
[configuration reference](CONFIGURATION.md#core-settings).

Some agents run commands with `bash -c`, which reads no startup file. To give those the
environment as well:

```text
set agent.bash_env on
```

Run `marksharc reload`, then start the agent. The option exports `BASH_ENV`, which replaces any
existing `BASH_ENV` value for child processes. It is off by default.

## Importing old zsh history

With atuin installed, the `history-atuin` module provides a one-shot importer for the history
files of a previous zsh setup:

```sh
import-legacy-history --dry-run
import-legacy-history
```

By default it reads `~/.zsh_history`, `~/.zhistory`, `$ZDOTDIR/.zsh_history` and
`~/.cache/zsh-directory-history`, removes duplicates, and imports into atuin. With `sqlite3`
available it keeps each command's directory and host. To import files copied from another host:

```sh
import-legacy-history --source ~/.zsh_history-otherhost --tree ~/.cache/zsh-directory-history-otherhost
```

Passing any `--source` or `--tree` replaces the defaults. Running the same import twice adds no
duplicates. Switching between `--route histdb` and `--route plain` can, and imported rows are
not checked against what atuin has already recorded.

## Troubleshooting

Start with `marksharc doctor`, then `marksharc reload --verbose`.

| Symptom | Likely cause | What to do |
| --- | --- | --- |
| A change to `config.conf` has no effect | The shell is still using what it loaded | `marksharc reload`, or open a new terminal |
| A module's feature is missing | The module skipped itself | `marksharc module list` shows `skipped` with the reason. Install the tool, or `marksharc bootstrap`. |
| A whole group of modules stopped loading | A plain `module <name>` line made the list explicit | Remove it, or name every module you want. See [choosing modules](#choosing-modules). |
| No completion menu, suggestions or highlighting | The pinned plugins were not fetched | Doctor reports `missing plugin or incorrect pin`. Run `marksharc update`. |
| A tool's installer "added itself to PATH" but nothing changed | It edited `~/.zshrc`, which zsh no longer reads | Doctor lists the foreign lines. Move each into `config.conf` as a `path` or `env` line. |
| `doctor: stale environment ID` | The shell predates a change to the framework or overlay | `marksharc reload`, or open a new terminal |
| `doctor: interactive startup blocked waiting for input` | Something in startup is prompting, often zsh's completion security check | Doctor quotes the prompt. Fix the directory permissions it names, or remove the code that prompts. |
| `doctor: interactive startup timed out` | Startup is slower than `doctor.startup_timeout_ms` | `MARKSHARC_VERBOSE=1 zsh -i -c exit` prints each module's time. Disable or fix the slow one. |
| `marksharc: reload acts on the current shell…` | `marksharc reload` ran as a program, not as the shell function | Run it in an interactive marksharc shell, or open a new terminal |
| `sync: dirty`, `ahead` or `diverged` | Local changes in a checkout | Commit, stash or push them yourself. Sync only fast-forwards. |
| Commands from a module are missing in an agent's shell | The agent uses `bash -c` | `set agent.bash_env on`. See [agents and scripts](#agents-and-scripts). |
| The shell is badly broken | A bad edit in the overlay or a private module | `zsh -f` starts a shell with no startup files. Fix the file, or `marksharc uninstall` to restore your originals. |

The cache is always safe to remove. If rendered files look wrong, delete
`~/.cache/marksharc/<host>` and open a new terminal.

## Uninstall

```sh
marksharc uninstall
```

This restores the startup files the installer backed up and removes the stubs. If you accepted
the clean Fish configuration, it puts your original Fish directory back and saves anything you
created since beside it.

```sh
marksharc uninstall --purge
```

`--purge` also deletes the cache, the state directory and a framework clone that the installer
made. It asks first; `--yes` answers for scripts. It never removes your overlay, and it never
removes a checkout you passed with `--home`.
