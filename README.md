# marksharc

Mark's shell RC files, rebuilt for the modern, agentic era.

marksharc is a modular shell framework for **zsh**, **fish** and **Bash** on macOS and Linux.
It gives you the same shell on every host, and it gives AI agents a complete, quiet environment.

- **Modules.** Each functional area (history, prompt, completion, version managers, git
  worktrees, and more) is a module you can switch off. See the [module reference](docs/MODULES.md).
- **Your configuration is yours.** Settings live in an *overlay* directory that you own. The
  framework checkout is never edited, so updating it is a fast-forward.
- **Quiet, offline startup.** Opening a shell installs nothing and fetches nothing. Updates are
  explicit commands.
- **One environment in every shell.** PATH, variables and aliases are declared once and rendered
  for zsh, fish and Bash. Scripts and agents get the same environment as your terminal.

## Requirements

- macOS or Linux
- zsh 5.9 or later, and git
- Optional: fish 4.x, and Bash 4.4 or later for interactive Bash. Older Bash, including the
  macOS system Bash 3.2, gets the environment only.

zsh is required even if you work in fish or Bash, because the `marksharc` command is written in it.

## Install

Clone the repository and run the installer:

```sh
git clone https://github.com/markfrommn/marksharc.git
sh marksharc/install.sh
```

Or run it straight from GitHub, which clones into `~/.local/share/marksharc`:

```sh
curl -fsSL https://raw.githubusercontent.com/markfrommn/marksharc/main/install.sh | sh
```

Then open a new terminal, or run `exec zsh -l`.

The installer:

- backs up your existing zsh and Bash startup files under `~/.local/state/marksharc/backup/`
  and writes small stubs in their place;
- creates your overlay in `~/.config/marksharc` from a template, unless one already exists;
- fetches the pinned plugins into `~/.cache/marksharc/plugins/`;
- never runs `chsh` and never touches an existing overlay.

`marksharc uninstall` puts your original files back.

Useful options: `--dry-run` previews every action, and `--coexist` adds marksharc beside your
current zsh setup instead of replacing it. The [user guide](docs/USERGUIDE.md#install) covers
every option, Fish, and what each step changes.

## Day 1: make it yours

```sh
marksharc module list              # every module and whether it is enabled
marksharc module disable <name>    # switch one off (edits config.conf in your overlay)
marksharc reload                   # apply changes in the current shell
marksharc doctor                   # report anything that needs attention
```

Your overlay is `~/.config/marksharc`. Edit `config.conf` there to set options and add your own
PATH entries, variables and aliases:

```text
set editor.command "emacs -nw"
set theme.ls_colors nord

path user ~/bin
env PAGER less
alias ll "ls -lA"
```

Put anything that needs real shell code in `local/post.zsh` (or `post.bash`, `post.fish`). Keep
the overlay in your own git repository to share it between hosts.

marksharc uses the tools you have and skips the rest. To install the ones its modules declare
(starship, fzf, eza, bat, fd, procs, vivid and others) through Homebrew:

```sh
marksharc bootstrap
```

Install anything else you want, such as atuin and zoxide, with your package manager; the
matching modules pick them up in the next shell.

## Day 2: keep it current

```sh
marksharc sync                     # fast-forward the framework and your overlay
marksharc update                   # sync, refresh plugins, run tool updates, re-render
marksharc doctor                   # check stubs, plugins, repositories and startup time
```

A shell tells you when the host is behind (`marksharc: updates available`). To keep several
hosts in step, see [sync, timers and push](docs/USERGUIDE.md#keeping-hosts-in-sync).

## Uninstall

```sh
marksharc uninstall                # restore your dotfiles, remove the stubs
marksharc uninstall --purge        # also remove the cache and state
```

Your overlay is never removed.

## Documentation

| If you want to | Read |
| --- | --- |
| Install, configure and operate marksharc | [User guide](docs/USERGUIDE.md) |
| Look up a `marksharc` command | [Command reference](docs/COMMANDS.md) |
| Look up a config file, directive or setting | [Configuration reference](docs/CONFIGURATION.md) |
| See what a module does and which options it has | [Module reference](docs/MODULES.md) |
| Know how zsh, Bash and fish differ | [Shell notes](docs/SHELLS.md) |
| Contribute, or write your own module | [Developing](docs/DEVELOPING.md) |

Topic guides: [completions](docs/completions.md), [launch commands](docs/launch.md),
[mise](docs/mise.md), [fish](docs/fish.md),
[multiplexers](docs/MUX-ADAPTERS.md) and [write-once commands](docs/write-once.md).

The [specification](specs/MARKSHARC-SPEC.md) is the normative contract.

## Layout

| Path | Contents |
| --- | --- |
| `install.sh` | Installer (POSIX sh) |
| `bin/marksharc` | The `marksharc` command |
| `core/` | Per-shell loaders (`zsh/`, `bash/`, `fish/`) and the command implementations (`cli/`) |
| `modules/` | Public modules, one directory each |
| `templates/overlay/` | Skeleton for a new overlay |
| `tests/` | Test suites, lint and fixtures |
| `docs/` | User and developer documentation |
| `specs/` | Specification and plan |

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
