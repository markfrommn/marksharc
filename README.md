# marksharc

Mark's shell RC files, rebuilt for the modern, agentic era.

marksharc is a modular shell framework for **zsh** and **fish**, with the same
environment in **bash** for scripts and agents. Functional areas are modules.
Configuration lives in a separate overlay that you own, so the framework
checkout stays read-only on every host.

> **Status:** early development. The zsh framework, the public modules, the
> installer and the `marksharc` command are in place. fish and bash wiring
> and the full module updater come in later releases.

## Requirements

- macOS or Linux
- zsh 5.9 or later
- fish 4.x (optional)
- bash 5.x (environment only)
- git

Day-to-day shell use needs only the native shell. The `marksharc` command needs zsh.

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

Then open a new terminal, or run `exec zsh -l`.

What it does:

- **Framework.** Uses the checkout the script sits in, or `--home <checkout>`. Piped
  from `curl`, it clones the repository into `${XDG_DATA_HOME:-~/.local/share}/marksharc`
  (an existing clone is reused, never pulled; `MARKSHARC_REPO` names another repository).
- **Overlay.** Copies the skeleton from `templates/overlay/` to
  `${XDG_CONFIG_HOME:-~/.config}/marksharc` when nothing is there. `--overlay <path>`
  links an existing directory instead; `--overlay <url>` clones one. An overlay that
  already exists is never modified, and a different one requested with `--overlay` is an error.
- **Dotfiles.** Moves `~/.zshenv`, `~/.zshrc`, `~/.zprofile`, `~/.zlogin` and
  `~/.zlogout` into `${XDG_STATE_HOME:-~/.local/state}/marksharc/backup/<timestamp>/`
  (symlinks are recorded by target), and writes a small `~/.zshenv` stub. If the core
  cannot load, the stub sets a minimal PATH and prints one line on stderr.
- **Plugins.** Clones the pinned plugins (fzf-tab) into
  `${XDG_CACHE_HOME:-~/.cache}/marksharc/plugins/`. Shell startup never fetches them. A
  failed fetch, when offline for example, leaves the install in place with a warning;
  `marksharc update` fetches them later. `--no-plugins` skips this step.
- **Login shell.** It never runs `chsh`; it prints the command when your login shell is not zsh.

`sh install.sh --dry-run` prints every action and changes nothing. Running the installer
again is safe: it makes no new backup and does not touch the overlay.

Day 1:

```sh
marksharc module list              # enabled, disabled and skipped modules
marksharc module disable <name>    # edits config.conf in your overlay
marksharc reload                   # apply it in this shell (--verbose to trace)
marksharc render                   # refresh cached env and generated completions
marksharc sync                     # fast-forward safe checkouts and refresh pins
marksharc doctor                   # report local health
marksharc update                   # sync, plugin pins and declarative render
marksharc version
marksharc uninstall                # restore the backed-up dotfiles, remove the stub
```

`marksharc uninstall --purge` also deletes the cache, the state and a clone made by the
installer (it asks first; `--yes` answers). It never removes your overlay or a checkout you
passed with `--home`.

Sync uses each checkout's configured Git upstream. It reports dirty, ahead, diverged,
detached or unavailable repositories without merging them. It finds the owning Git
checkout of the overlay, including a linked overlay subdirectory. Add extra checkout
paths in `config.conf`, quoting paths that contain spaces:

```text
set sync.repos "$HOME/work/one" "$HOME/work/two"
set sync.check_hours 12
set doctor.startup_ms 500
set doctor.startup_timeout_ms 5000
```

`doctor` times an interactive startup against `doctor.startup_ms` and gives up after
`doctor.startup_timeout_ms`, reporting the startup as timed out. It reports a missing
`requires command` only for a module that the overlay names with a `module <name>` line (in `config.conf`
or `hosts/<host>.conf`);
a module enabled by default skips itself when its command is absent.

An assignment in `hosts/<hostname>.conf` replaces the global `sync.repos` list.

The same module and host conf files accept declarative environment lines. Values use shell-word
quoting; `~` and `$NAME` are references, never command substitution. `when command`, `dir` and
`file` guards run in the next shell, while `os` and `host` guards are settled by `render`.

```text
path user ~/bin
env EDITOR "emacs -nw"
alias ll "ls -lA" when command ls
tiers "manager brew system user app local"
```

`marksharc render` writes the per-host cached `env.zsh` and generated completions. Startup refreshes
stale env without running generators; install, update and explicit reload also refresh completions.

An eligible interactive shell starts a detached fetch when the last check is older
than `sync.check_hours` (12 hours by default). A later interactive shell prints a
notice when the cached result is behind. The fetch does not merge or update plugins;
set `MARKSHARC_NOTIFY=0` to suppress the notice and background check for a session.

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
- [Tests](tests/README.md)
- [Specification](specs/MARKSHARC-SPEC.md) and [plan](specs/MARKSHARC-PLAN.md)

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
