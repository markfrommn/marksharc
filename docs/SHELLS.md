# Shell notes

marksharc supports zsh, Bash and fish. The environment (PATH, variables, aliases) is the same in
all three, because it is declared once and rendered for each. Interactive behaviour is written
natively for each shell, so each one feels like itself.

- [At a glance](#at-a-glance)
- [zsh](#zsh)
- [Bash](#bash)
- [fish](#fish)

## At a glance

| | zsh | Bash | fish |
| --- | --- | --- | --- |
| Version for interactive use | 5.9+ | 4.4+ | 4.x |
| Environment only | Any non-interactive shell | Bash 3.2 and later, and any non-interactive shell | Any non-interactive shell |
| How it is wired in | Stub in `~/.zshenv`; zsh then reads startup files from a generated directory | Stubs in `~/.bashrc` and `~/.bash_profile` | `conf.d/00-marksharc.fish` |
| Keeps your existing startup files | With `install.sh --coexist` | No; they are backed up | Yes, unless you accept the clean configuration |
| Prompt | starship | starship | starship |
| History | atuin, else a native history file | atuin, else a native history file | atuin, else fish's own |
| Completion | Native, with an fzf-tab menu or Carapace | Readline and bash-completion, optionally Carapace | fish's own, optionally Carapace |
| Suggestions and highlighting | Pinned plugins | With ble.sh | Built into fish |
| Your own code | `local/post.zsh` | `local/post.bash` | `local/post.fish` |
| `marksharc reload`, `cs`, `li` | Yes | Yes | Yes |
| "Updates available" notice | Yes | Yes | No |

Two things hold in every shell:

- The `marksharc` command and the commands modules ship in `bin/` are zsh programs. zsh must be
  installed even if you never open it.
- A session started by an agent or a script gets the environment and nothing else.

## zsh

zsh is the reference shell: every module supports it.

### Standard install

The installer writes a small stub to `~/.zshenv`. The stub loads the environment and points
`ZDOTDIR` at `~/.local/state/marksharc/zdot`, a generated directory of one-line startup files.
From then on zsh does not read `~/.zshrc`, `~/.zprofile` or `~/.zlogin`.

This is deliberate. Many installers append lines to `~/.zshrc`; with this arrangement such an
edit cannot change your shell behind your back. `marksharc doctor` lists any lines that land in
those files, so you can turn each into a `path` or `env` line in your overlay.

### Coexist install

`sh install.sh --coexist` leaves your startup files and `ZDOTDIR` alone. It adds one marked line
to `~/.zshenv` and one to `~/.zshrc` that load marksharc beside what you already have.

Use it to try marksharc on a working setup. Expect overlap: if your own files and a marksharc
module both configure the prompt or completion, the one that runs last wins. Disable the modules
you do not want with `marksharc module disable <name>`.

To move from coexist to a standard install, run `marksharc uninstall`, then the installer again
without `--coexist`.

### Plugins

zsh uses three pinned third-party plugins: fzf-tab, zsh-autosuggestions and
zsh-syntax-highlighting. Each is a module you can disable. They are cloned at a fixed commit into
`~/.cache/marksharc/plugins/` by the installer and by `marksharc update`, never at startup. A
missing clone is skipped silently, and `marksharc doctor` reports it.

### Completion interface

zsh has two completion interfaces. They are alternatives:

- **fzf-tab** (the default): a fuzzy menu over zsh's own completions.
- **Carapace** (opt in): completions from the `carapace` tool.

Choose persistently in your overlay:

```text
set completion-carapace.enable on
```

or for one session:

```sh
completion-ui carapace     # also: fzf-tab, both, native, reset
exec zsh -l
```

`completion-ui` with no argument shows the current choice. The change takes effect in a fresh
shell, which is why `exec zsh -l` follows. Running both together is possible
(`set completion-carapace.allow_fzf_tab on`) but not recommended. [completions.md](completions.md)
covers Carapace in detail.

### Reloading

`marksharc reload` applies changes in place. `cs` is a verbose reload, and `li` is a verbose
reload that also repeats the login-only steps.

## Bash

### Versions

| Bash | What you get |
| --- | --- |
| 4.4 or later, at a terminal | The environment and the full interactive setup |
| 3.2 to 4.3, including the macOS system Bash | The environment only |
| Any version, non-interactive | The environment only |

marksharc never replaces an old Bash with a newer one behind your back. To get the interactive
features on macOS, install a current Bash (`brew install bash`) and open that executable.
`marksharc doctor` tells you when the running Bash is environment-only.

Login and non-login terminals load the same interactive features.

### Line editor

Plain Bash uses Readline, which provides completion and listing. The optional
`line-editor-ble` module adds [ble.sh](https://github.com/akinomyoga/ble.sh), which brings
suggestions, syntax highlighting and a selectable completion menu.

```sh
marksharc install ble.sh           # needs git, GNU make and GNU awk
exec bash -l
```

`marksharc update --only ble-sh` refreshes it when the pinned version changes. To stay on
Readline, add `module line-editor-ble off` to your overlay.

### Completion

Bash loads bash-completion when it is installed. Set `completion-carapace.enable` to `on` to add
Carapace. When Carapace is active it completes `marksharc`, `launch-session`, `launch-repo` and
`cwf-new`; zoxide, `cwf` and Herdr keep their own completions.

```sh
completion-ui status               # the active and pending editor and completion provider
completion-ui carapace             # also: readline, ble, native, reset
exec bash -l
```

A change of editor or completion provider needs a fresh shell. `marksharc reload` applies
ordinary module changes in place.

### History and key bindings

When atuin initialises, it owns Ctrl-R and the Up key. Otherwise Bash keeps a native history
file at `~/.local/state/marksharc/history.bash`. With fzf 0.48 or later, Ctrl-T inserts selected
files and Alt-C changes to a selected directory.

### One difference to know

Bash runs directory-change hooks before the *next prompt*, not at the moment of `cd`. On one
line, `cd project; node …` can therefore run `node` before the automatic version switch for
`project`. Put the command on the next line, or switch explicitly.

### Bash for agents

Bash login and interactive shells get the environment from the installed stubs. A plain
`bash -c 'command'`, which is how some agents run commands, reads no startup file. To cover it:

```text
set agent.bash_env on
```

Then `marksharc reload`, and start the agent with Bash as its shell:

```sh
SHELL=/bin/bash claude
```

The option exports `BASH_ENV`, so every non-interactive Bash loads the environment. It is off by
default and replaces any existing `BASH_ENV` for child processes. The environment file works on
Bash 3.2.

[The Bash specification](../specs/BASH-SPEC.md) is the full contract.

## fish

The installer adds `~/.config/fish/conf.d/00-marksharc.fish`, which loads the rendered
environment in every session and the interactive setup at a terminal. Your existing Fish
configuration stays unless you accept the installer's offer of a clean one.

What to know:

- **zsh is still needed.** Fish uses it to refresh the rendered environment after a change to
  the framework or overlay, and to run the `marksharc` command.
- **Fish features stay fish's own.** Suggestions, highlighting and completion are native. Where
  a zsh module has no meaning in fish, fish's equivalent is used.
- **fisher is not used.** marksharc pins the two fish plugins it depends on (nvm.fish and
  fzf.fish) itself. `marksharc doctor` reports leftover fisher files.
- **No "updates available" notice.** Run `marksharc sync` when you want to check, or turn on
  the [sync timer](USERGUIDE.md#updating-automatically).

[fish.md](fish.md) has the module-by-module parity table, the rules for writing fish module
code, and how to retire an older fish configuration.
