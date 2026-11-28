# Configuration reference

All configuration lives in your overlay, `~/.config/marksharc` by default. This page describes
the files, the line format they share, and the settings that belong to the core. Module options
are in the generated [module reference](MODULES.md).

The [specification](../specs/MARKSHARC-SPEC.md) (sections 6.3 and 6.5) is the normative
definition. If this page disagrees with it, the specification is right.

- [Files](#files)
- [Line format](#line-format)
- [Directives](#directives)
- [Conditions](#conditions)
- [PATH tiers](#path-tiers)
- [Core settings](#core-settings)
- [Environment variables](#environment-variables)
- [Host inventory](#host-inventory)
- [Package lists](#package-lists)
- [Provider files](#provider-files)
- [Native hooks](#native-hooks)

## Files

| File | Read by | Contents |
| --- | --- | --- |
| `config.conf` | Every shell, and every `marksharc` command | `module`, `set`, `tiers`, `path`, `env`, `alias`, `package`, `update` and `installer` lines |
| `hosts/<host>.conf` | The same, after `config.conf`, on that host only | The same kinds of line |
| `hosts.conf` | `marksharc push`, `marksharc hosts`, the launch commands | `host` lines |
| `packages/*` | `marksharc bootstrap` | Package lists |
| `providers/*.conf` | The `cc-providers` module | `env` lines for one provider |
| `local/post.zsh`, `local/post.bash`, `local/post.fish` | Interactive shells, last | Native shell code |
| `modules/<name>/` | The module loader | Private modules |

`<host>` is the short host name: `hostname` up to the first dot. A `set` line in the host file
replaces the same setting from `config.conf`.

To use a different overlay directory, export `MARKSHARC_CONFIG` before the shell starts.

## Line format

Every configuration file uses the same format.

- One directive per line. Blank lines are ignored.
- `#` starts a comment.
- Words are split like shell words. Quote a value that contains spaces with single or double
  quotes.
- `~` at the start of a word, and `$NAME` or `${NAME}`, are replaced with your home directory
  and with exported environment variables. Inside single quotes nothing is replaced.
- Nothing else is special. There is no command substitution, no globbing and no arithmetic.
  A line is data; it is never run as shell code.

```text
env EDITOR "emacs -nw"                 # one value with a space
env NOTE 'costs $5'                    # single quotes keep the dollar sign
path user "$HOME/My Tools/bin"         # a reference inside double quotes
```

A line the parser cannot read, such as one with an unclosed quote, is skipped.

## Directives

### In your overlay

| Directive | Meaning |
| --- | --- |
| `module <name>` | Enable a module. One plain `module` line makes the list explicit: only named modules load. |
| `module <name> off` | Disable a module. |
| `set <module>.<key> <value>` | Set a module option or a [core setting](#core-settings). Extra words are joined with spaces. |
| `tiers <tier>…` | Set the order of the [PATH tiers](#path-tiers). |
| `path <tier> <dir> [when …]` | Add a directory to a PATH tier. |
| `env <NAME> <value> [when …]` | Export a variable. |
| `alias <name> <value> [when …]` | Define an alias in interactive shells. |
| `package <manager> <name>` | Declare a package for `marksharc bootstrap`. Managers: `brew`, `cask`, `apt`, `dnf`. |
| `update <label> <command> [args…]` | Add a step to `marksharc update`. |
| `installer <name> <script>` | Register a script for `marksharc install <name>`. |

`update` arguments are data, not shell code. An `update` command that starts with `./`, and a
relative `installer` path, resolve from the overlay directory.

### In a module's `module.conf`

Modules use `path`, `env`, `alias`, `package`, `update` and `installer` as above, plus:

| Directive | Meaning |
| --- | --- |
| `describe <text>` | One-line description, shown by `marksharc module list`. |
| `order <n>` | Load position, 0–99. The default is 50. |
| `requires command <name>…` | Skip the module when any named command is missing. |
| `requires os darwin\|linux` | Limit the module to one operating system. |
| `option <key> <default> <text>` | Declare an option that `set <module>.<key>` can change. |
| `completion <cmd> <generator…> [when …]` | Run the generator at render time and cache its output as a zsh completion. |
| `completion-bash <cmd> <generator…> [when …]` | The same for Bash. |

[MODULE-AUTHORING.md](MODULE-AUTHORING.md) explains how to use them.

## Conditions

`path`, `env`, `alias` and `completion` lines can end with one or more conditions. All of them
must hold.

| Condition | True when | Decided |
| --- | --- | --- |
| `when command <name>` | The command is on PATH | When each shell starts |
| `when dir <path>` | The directory exists | When each shell starts |
| `when file <path>` | The file exists | When each shell starts |
| `when os darwin\|linux` | The operating system matches | When `marksharc render` runs |
| `when host <name>` | The short host name matches | When `marksharc render` runs |

Because `command`, `dir` and `file` are tested at startup, installing a tool takes effect in the
next shell with no further step.

```text
alias cat bat                  when command bat
path user ~/.cargo/bin         when dir ~/.cargo/bin
env BROWSER wslview            when os linux when command wslview
```

## PATH tiers

PATH is built from named tiers. A `path` line adds a directory to one tier, and the tiers are
joined in order.

| Tier | Use it for |
| --- | --- |
| `first` | A directory that must win over everything. Always at the front. |
| `manager` | Version managers: nvm, gvm, pyenv, mise shims |
| `brew` | Homebrew |
| `local` | `/usr/local`, `/opt` and similar |
| `system` | `/bin`, `/usr/bin`, `/sbin`, `/usr/sbin` |
| `user` | Your own directories, such as `~/bin` and `~/.local/bin` |
| `app` | Application directories that should follow your own |
| `last` | Always at the end. Holds `.` when `core.dot_in_path` is on. |

The default order is `manager brew local system user app` on macOS and
`manager brew system user app local` on Linux.

Directories that were already on PATH when the shell started, and that no tier manages, are
kept. Those that came before any managed directory stay near the front, after `first`; the rest
go before `last`. Duplicates are removed, and a directory that does not exist is left out.

To change the order, list the tiers you care about:

```text
tiers user manager brew
```

A tier you leave out follows in the default order, so nothing is dropped. `first` and `last`
cannot be moved.

## Core settings

These use the same `set` line as module options but belong to no module.

| Setting | Default | Meaning |
| --- | --- | --- |
| `core.dot_in_path` | `off` | Put `.` at the end of PATH. Never applied for root. |
| `sync.repos` | *(empty)* | Extra git checkouts for `marksharc sync`, beside the framework and the overlay. Quote paths that contain spaces. |
| `sync.check_hours` | `12` | Minimum hours between background "is this host behind?" checks. |
| `sync.timer_minutes` | `60` | Interval of the timer installed by `marksharc sync timer on`. |
| `sync.push_timeout` | `60`, or `300` with `--update` | Per-host timeout in seconds for `marksharc push`. |
| `sync.push_parallel` | `8` | Maximum concurrent SSH jobs for `marksharc push`. |
| `doctor.startup_ms` | `500` | Interactive startup time, in milliseconds, above which `doctor` reports a finding. |
| `doctor.startup_timeout_ms` | `5000` | How long `doctor` waits for an interactive startup before reporting a timeout. |

`sync.repos` takes several values on one line:

```text
set sync.repos "$HOME/work/one" "$HOME/work/two"
```

A `sync.repos` line in `hosts/<host>.conf` replaces the whole list from `config.conf`.

One module option is read before any module loads, because it decides the session class:
`agent.markers`. It replaces the built-in list of environment variables that mark an agent or
editor session. The built-in list is `CLAUDECODE`, `AI_AGENT`, `CODEX_SESSION_ID`,
`CODEX_SANDBOX`, `OPENCODE`, `GEMINI_CLI`, `CURSOR_AGENT`, `COPILOT_CLI`, `KILO_CLI_MODE`,
`VSCODE_INJECTION` and `VSCODE_NONCE`.

## Environment variables

Variables you can set:

| Variable | Effect |
| --- | --- |
| `MARKSHARC_CONFIG` | The overlay directory. Default `${XDG_CONFIG_HOME:-~/.config}/marksharc`. |
| `MARKSHARC_VERBOSE` | Set to `1` to print the startup trace and per-module timings on stderr. |
| `MARKSHARC_NOTIFY` | Set to `0` to turn off the background behind-check and its notice for this session. |
| `MARKSHARC_COMPLETION_UI` | A session override for the zsh completion interface: `carapace`, `fzf-tab`, `both` or `native`. The `completion-ui` command sets it for you. |
| `MARKSHARC_REPO` | The repository `install.sh` clones when it is piped from `curl`. |
| `XDG_CONFIG_HOME`, `XDG_CACHE_HOME`, `XDG_STATE_HOME`, `XDG_DATA_HOME` | Honoured for every default location. They must be set in the environment a shell starts with; the stubs do not save them. |

Variables marksharc sets for you to read:

| Variable | Value |
| --- | --- |
| `MARKSHARC_HOME` | The framework checkout. Exported. |
| `MARKSHARC_SESSION` | `interactive`, `agent` or `batch`. Local to each shell, not exported. |
| `MARKSHARC_OS` | `darwin` or `linux` |
| `MARKSHARC_ARCH` | The CPU type, such as `arm64` or `x86_64` |
| `MARKSHARC_HOST` | The short host name |
| `MARKSHARC_DISTRO` | `macos`, or the Linux distribution ID such as `ubuntu` |
| `MARKSHARC_ENV` | A fingerprint of the framework and overlay files. A child shell that inherits a matching value skips rebuilding the environment. |

## Host inventory

`hosts.conf` lists the hosts that `marksharc push` and the launch commands can reach:

```text
host workstation
host build admin@build.example.com
```

The first word after `host` is the name you use. The optional second word is the SSH target;
without it, the name is passed to `ssh` as it is. Manage the file with
[`marksharc hosts`](COMMANDS.md#hosts) or edit it by hand.

## Package lists

`marksharc bootstrap` installs the packages that enabled modules declare. Add your own in the
overlay's `packages/` directory:

| File | Format | Applies on |
| --- | --- | --- |
| `*.Brewfile` | `brew "name"` or `cask "name"`, one per line | macOS, and Linux with Homebrew. Casks on macOS only. |
| `*.darwin.Brewfile` | The same | macOS only |
| `*.linux.Brewfile` | The same | Linux only |
| `*.apt` | One package name per line | Linux with apt |
| `*.dnf` | One package name per line | Linux with dnf |

Comments and blank lines are allowed. A Brewfile here is read as data, not run by Ruby, so
`tap` lines, options and any other Ruby are rejected.

A single package can also be declared in `config.conf`:

```text
package brew ripgrep
package apt ripgrep
```

## Provider files

The `cc-providers` module turns each `providers/<name>.conf` into two commands, `claude<name>`
and `models<name>`. A provider file holds `env` lines:

```text
env ANTHROPIC_AUTH_TOKEN "$MY_PROVIDER_TOKEN"
env MODELS_URL https://example.invalid/v1/models
```

The file is read each time the command runs, so the generated command never contains a secret.
Run `marksharc render` after adding, removing or renaming a provider file.
[write-once.md](write-once.md) has the details.

## Native hooks

When a line of configuration is not enough, write shell code:

| File | Runs |
| --- | --- |
| `local/post.zsh` | At the end of interactive zsh startup, after every module |
| `local/post.bash` | The same, in interactive Bash 4.4 or later |
| `local/post.fish` | The same, in interactive fish |

These files run in interactive shells only. Keep them quiet: startup prints nothing.

In `local/post.zsh`, declare variables at the top level with `typeset -g`. The file also runs
inside a function when you `marksharc reload`, where a plain `typeset` would vanish when the
function returns. In `local/post.bash`, use `declare -g` for the same reason.

For anything larger than a few lines, write a
[private module](MODULE-AUTHORING.md#private-modules).
