# MarkSharc Launch Specification

| | |
|---|---|
| Status | Design approved 2026-11-25. DEV-79 implements the launch foundation. |
| Source issues | DEV-78 (this design), DEV-79, DEV-74, DEV-75, DEV-76 (Linear, project MarkSharc) |
| Extends | [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md) sections 6.11, 6.13, and 7.1. That document wins where the two disagree. |
| Companion | [LAUNCH-PLAN.md](LAUNCH-PLAN.md) |

The launch commands open a fresh terminal session under a multiplexer, on this host or another one, in a directory, a repository, or a new `cwf` worktree. This document records how each multiplexer behaves, what the commands do, and how the pieces fit together.

## 1. Goals

1. One command opens a terminal session on a chosen host and directory under whichever multiplexer is in use, and starts one when none is running.
2. A second command does the same for a repository chosen by name or from a picker.
3. `cwf-new` can create its worktree in a new terminal on any host, and `gwt-clean` closes that terminal when the work is done.
4. The commands serve automation first: every choice has a flag, nothing prompts without a terminal, and results print as data.
5. A launched session knows who launched it, so ssh-agent and X11 setup can reuse the launcher's forwarding.

## 2. Use cases

| # | Caller | Command | Result |
|---|---|---|---|
| U1 | A shell inside a multiplexer | `launch-session ~/src` | A new terminal in the same multiplexer and instance, in `~/src`, running the login shell. |
| U2 | A script or agent with no terminal | `launch-session --host build1 --pwd ~/src --command htop` | The same on host `build1`. Selection never prompts; it exits 3 when it would have to. |
| U3 | A shell | `launch-repo` | A picker over the repositories and worktrees under the configured roots, then a terminal in the chosen one. |
| U4 | A shell | `launch-repo build1:api/fix-login` | A terminal on `build1` in the `fix-login` worktree of `api`. |
| U5 | A shell | `cwf-new --repo api --host build1 fix-login` | A terminal on `build1` in the base repository of `api`. It creates the `fix-login` session there, with its hooks, and ends in the new worktree. |
| U6 | The session from U5 | `gwt-clean` | The worktree and branch are removed after the usual checks, and the terminal closes. |

U5 and U6 are the final use case. Sections 5 to 9 are sized by what they need.

## 3. Scope

Included:

- `launch-session` and `launch-repo` as write-once executables in a new `launch` module, with zsh and fish completions.
- Herdr Core (`hc`) with the Herdr app, the Herdr TUI, and tmux as launch targets.
- Local launches in all three. Remote launches through Herdr Core machines and Herdr TUI machines.
- A shared picker, host resolution across the three machine lists, and a cached repository inventory.
- `cwf-new` launch options and a launched mode for `gwt-clean`.
- Launch metadata in the environment, used by `setup-ssh-agent` and `setup-x11-display`.

Later:

- tmux on a remote host over ssh.
- WezTerm as a launch target.
- Pane splits and multi-pane layouts.
- Creating a worktree from `launch-repo`. The form `repo/worktree:branch` is reserved for it and is a usage error today.
- A multiplexer inside a container as a named target. A Herdr Core machine added with `hc machine add --via <command>` already reaches one, so no separate design is needed yet.
- Run-after-init (6.4) in bash.

Excluded:

- Starting the Herdr TUI or opening the Herdr app.
- Installing a multiplexer, or marksharc, on a remote host.

## 4. Multiplexer behaviour

Reviewed on 2026-11-25 on Linux with `hc` 0.1.22, `herdr-app` 0.1.12, `herdr` 0.9.5, and `tmux` 3.5a, and against a Herdr app window on macOS that shows terminals from a Linux core, with `hc` 0.1.21 and 0.1.22 on three other machines and `tmux` 3.8 on macOS. "Verified" marks behaviour confirmed by a live run on a disposable terminal or instance; the rest comes from each tool's own help and manual. Section 4.6 records the live checks and the ones still open.

### 4.1 Terms

| Term | Meaning |
|---|---|
| Kind | A multiplexer product: `hc` (Herdr Core, shown by the Herdr app), `herdr` (the Herdr TUI), or `tmux`. |
| Instance | One running server of a kind for this user on a host: a Herdr Core session, a Herdr TUI session, or a tmux session. |
| Machine | Another host as one multiplexer names it. Each kind keeps its own list. |
| Placement | Where a new terminal appears: a new workspace, a new tab, or hidden. |

### 4.2 Herdr Core and the Herdr app

Herdr Core runs terminals and keeps them alive. The Herdr app shows them and arranges them in spaces and tabs. `hc` does not arrange windows.

- **Markers.** A terminal's program sees `HC_TERMINAL_ID` (an address such as `t7`), `HC_TERMINAL_SOCKET`, and `HC_SCOPE`. Verified.
- **Instances.** A user can run more than one core per host. Each is a session, named `default` unless chosen, with its own core identity, terminals, and socket. `HC_SESSION=<name>` selects one, as do `hc connect --session` and `hc machine add --session`. The socket is `$XDG_RUNTIME_DIR/herdr-core/<session>.sock` on Linux; on macOS the default session's is `~/.local/state/herdr-core/default/default.sock`. `hc server status --json` reports the core's identity, version, and live terminal count. Verified.
- **Starting.** Any `hc` command starts the session's core when it is not running, including `hc server status`. Whether a core is running is therefore read without `hc`: `~/.local/state/herdr-core/<session>/core.lock` holds that session's socket path, on Linux and macOS alike, and the socket exists only while the core runs. The lock file stays after a stop, so the test is the socket, not the file. Verified.
- **New terminal.** `hc run [--bg] [--name N] [--cwd D] [--on M] [--label K=V]… [--no-parent] [--no-notify] [--keep] [--rm] [--] [argv…]`.
  - With no argv the terminal runs that machine's own shell as a login shell (`zsh -l` observed). One argument that contains spaces or shell characters is a shell line; several arguments are an argv run as given. Verified.
  - `--cwd` defaults to the directory `hc` runs in. With `--on` it defaults to that machine's home. `--cwd` does not expand `~`: `--cwd '~'` and `--cwd '~/dir'` fail with `spawn_failed`, locally and with `--on`. Verified.
  - The terminal's environment is the core's environment, not the caller's. `hc run` has no environment option; the `terminal.run` API method has `env`, but the CLI does not expose it. An argv of `env NAME=VALUE … program` sets variables, including empty values and values with spaces and semicolons. Verified.
  - A terminal started from inside another terminal is its child. It ends when the parent's program ends, and `hc` types notes about it into the parent, unless it is started with `--no-parent` and `--no-notify`. A `--no-parent` terminal outlives the terminal it was started from; a child is killed with it. Verified.
  - `--bg` returns at once. Without it `hc` waits and streams the output.
  - Piped output is JSON: `{"address":"t21","agent":"env","cwd":"/tmp","state":"live",…}`. Verified.
  - `--name` must be 1 to 32 of `a-z 0-9 - _` and unique among live terminals.
- **Machines.** `hc machine ls --json` prints `{"machines":[{"name":…,"target":…,"host":…,"id":…,"via":…,"temporary":…,"session":…,"state":…}]}`. `host` is the hostname the other core reports and `id` is its permanent identity. `name` is local to the core that holds the entry: two cores can call the same machine by different names. `hc machine add <ssh-target> [--name N] [--via <command>] [--temp] [--session S]` adds one. A remote terminal's address is `machine/t7`, and the reply to `hc run --on` carries it in that form. Verified.
- **No terminal.** `hc exec [--on M] [--cwd D] [--env K=V] argv…` runs one program without a terminal and returns its output and exit code. Its timeout defaults to 60 seconds and cannot exceed 600.
- **Visibility.** The app shows a terminal only when it carries the label `herdr.space=<space id>`. `herdr.tab=<tab id>` picks its tab; without it the app makes a tab in that space. An unlabelled terminal stays hidden and is reached with `hc attach <address>`. `hc get <address> --json` returns a terminal's labels.
  - With the id of an existing space, the terminal appears as a new tab there. Verified.
  - With an unused id of the same shape, `sp` and 32 hexadecimal digits, the app creates a space for it, named after the directory the terminal is in. Verified.
  - Both work from a core on another host than the app, and for a terminal on a third machine started with `--on`; the app files that space under its own name for the machine. Verified.
  - The app adds a `where` label. Neither case moves the focus. The tab, and a space left empty, disappear when the terminal ends. Verified.
- **The app's own CLI.** `herdr-app do space.new --name N --folder D --machine M --argv '<json array>'` makes a space; `tab.new` takes `--name`, `--space`, `--folder`, and `--argv`; `terminal.open` takes `--argv`, `--folder`, `--place tab|right|down`, and `--name`. `--machine ''` means this computer. There is no environment argument. The commands talk to the open window on the same host through `~/.config/herdr-app/herdr-app.sock` (`HERDR_APP_HOME` picks another home). They fail when no window is open on that host, which is the usual case in a shell on a remote machine whose terminals the app shows. `herdr-app status` reports whether a window answers. Verified for the no-window failure. Placement does not need these commands; only focus does (5.4).

### 4.3 Herdr TUI

- **Markers.** A pane's shell sees `HERDR_ENV=1`, `HERDR_SESSION`, `HERDR_SOCKET_PATH`, `HERDR_WORKSPACE_ID` (`w1`), `HERDR_TAB_ID` (`w1:t1`), `HERDR_PANE_ID` (`w1:p1`), `HERDR_BIN_PATH`, and `TERM_PROGRAM=herdr`. Verified.
- **Instances.** `herdr session list [--json]` prints each session's name, status, directory, and socket. `herdr --session <name> <command>` addresses one. Inside a pane the inherited context addresses the pane's own session.
- **New terminal.** `herdr workspace create [--cwd D] [--label T] [--env K=V]… [--focus|--no-focus]` returns JSON with `.result.workspace.workspace_id`, `.result.tab.tab_id`, and `.result.root_pane.pane_id`. `herdr tab create --workspace <id>` takes the same options and returns `.result.tab` and `.result.root_pane`. Verified.
- **Program.** Creation takes no program. A new pane runs the configured shell (`terminal.default_shell`, else `$SHELL`) in the mode set by `terminal.shell_mode` (`auto`, `login`, or `non_login`). `herdr pane run <pane> <command>` types the command into that shell; it does not replace the shell. Verified.
- **Environment.** A new pane gets the server's environment plus each `--env`. A server started inside another multiplexer passes that multiplexer's markers to every pane: a Herdr pane under a server started in an `hc` terminal sees `HC_TERMINAL_ID` too. Verified.
- **Machines.** `herdr machine list --json` prints `[{"id":…,"label":…,"target":…,"session":…,"enabled":…}]`. `herdr --machine <label-or-id> <command>` forwards an API command to that machine's server, which must already be running. It does not combine with `--session`. Use an absolute path for a remote workspace. In V7, a `~/work` request opened in the remote home instead of the existing `work` subdirectory.
- **Starting.** `herdr server` runs a headless server and bare `herdr` opens the TUI. Automation starts neither.

### 4.4 tmux

- **Markers.** `TMUX` holds `<socket>,<server pid>,<session index>` and `TMUX_PANE` holds `%N`. Verified.
- **Instances.** A tmux session is the instance. `tmux list-sessions -F '#{session_id} #{session_name}'` lists the sessions of one server. The default server socket is `${TMUX_TMPDIR:-/tmp}/tmux-<uid>/default`; `tmux -S <socket>` addresses the server named in `TMUX`. With no server, `list-sessions` and `has-session` fail and `new-session -d` starts one. Verified.
- **New terminal.** `tmux new-window [-d] [-t <session>:] [-c D] [-e NAME=VALUE]… [-n N] [-P -F <format>] [command [args…]]`, and `tmux new-session -d -s N` with the same `-c`, `-e`, and command. `-e` on `new-session` needs tmux 3.2.
- **Program.** With no command the window runs `default-command`, or `default-shell` as a login shell when that option is empty. Several arguments run as an argv without a shell; one argument is a shell command line. Verified.
- **Environment.** A new window gets the server and session environment plus each `-e`, not the caller's. Empty values and values with spaces and semicolons pass through `-e` unchanged. Verified.
- **Machines.** tmux has no machine list. A remote launch needs ssh and is later work.
- **Ending.** A window closes when its program exits, unless `remain-on-exit` is set.

### 4.5 Comparison

| | Herdr Core (`hc`) | Herdr TUI | tmux |
|---|---|---|---|
| Caller's environment inherited | No | No | No |
| Sets variables | `env` in front of the program | `--env` | `-e` |
| Starts in a directory | `--cwd` | `--cwd` | `-c` |
| Runs a program instead of a shell | Yes, an argv | No | Yes, an argv |
| Remote host | `--on <machine>` | `--machine <label>` | No |
| Several instances per user | Yes, sessions | Yes, sessions | Yes, sessions and sockets |
| Starts without a running server | Yes, on any command | No | Yes, `new-session -d` |
| Visible on creation | Only with a `herdr.space` label | Yes | Yes, when a client is attached |
| Focus control | None in `hc`; the app's own CLI on the app's host | `--focus`, `--no-focus` | `-d` |
| Expands `~` in the directory | No | Yes for remote paths, by its help | Local only; the caller expands it |

### 4.6 Live checks

DEV-78 ran these on 2026-11-25 with the operator at the app window. The terminals, the probe core, and the tmux server they used were removed afterwards. DEV-79 runs the open ones and records the results here. A result that contradicts section 5 amends that section in the same pull request.

| # | Check | Result |
|---|---|---|
| V1 | From a shell on a remote core, `hc run --label herdr.space=<caller's space>` shows a new tab in that space. | Pass. The tab appears, the app adds `where`, and the focus does not move. |
| V2 | An unused `herdr.space` id creates a space. | Pass, for a local terminal and for terminals started with `--on` on two other machines. The space is named after the terminal's directory and goes when the terminal ends. |
| V3 | `hc run --cwd '~/dir'` expands `~` on the target. | Fail, locally and with `--on`: `spawn_failed`. Section 5.4 changes directory inside the wrapper instead; that form is verified on a remote machine. |
| V4 | `herdr-app do space.new` with a wrapped argv. | Not run. Placement no longer needs it. |
| V5 | `hc run` with no core running starts one. | Pass. Every `hc` command does, including `hc server status`. |
| V6 | `HC_SESSION=<name>` reaches a separate core. | Pass. The probe core had its own identity and terminal list, and stopping it left the default core untouched. Socket paths are in 4.2. |
| V7 | `herdr --machine <label> workspace create --cwd --env` against a running remote server, including an empty `--env` value. | Pass through SSH to a disposable Herdr TUI 0.9.5 server on sol. An absolute cwd, an empty value, and a value containing spaces, a semicolon, a dollar sign, and quotes reached the pane. `~/work` fell back to the remote home. The adapter requires an absolute remote cwd. |
| V8 | A shell's `exit` closes its terminal's view. | Pass in the app and in Herdr TUI 0.9.5. On sol, `marksharc-mux launch herdr` created a pane in a disposable server, which returned an empty pane list after the shell exited. tmux closes the window by its manual. |
| V9 | `tmux new-session -e` on the macOS Homebrew tmux. | Pass with tmux 3.8, including an empty value. |
| V10 | A `--no-parent` terminal outlives the terminal that started it. | Pass. A child started without it was killed with its parent. |
| V11 | With an app window on the calling host, `herdr-app do agent.focus --terminal <address>` moves the focus to a terminal placed by label. | Pass with Herdr app 0.1.12 and Core 0.1.22 on macOS. The app kept the original focus on label placement and switched to the new terminal's space after `agent.focus`. The operator confirmed the switch. The original view was restored and the probe terminal removed. |

## 5. Architecture

### 5.1 Parts

| Part | Location | Role |
|---|---|---|
| Picker | `core/zsh/lib/pick.zsh` | One interactive selection helper for hosts, repositories, and instances (5.3). |
| JSON helpers | `core/zsh/lib/json.zsh` | The pure-zsh reader extracted from the `hc machine ls` scanner, extended to the other replies the adapters read. No parser dependency on a host. |
| Host resolution | `core/cli/hosts-lib.zsh` | Reserved names, ssh targets, and host-to-machine matching (5.2). |
| Launch adapters | `modules/mux/adapters/<kind>.zsh` | New operations beside `detect`, `set_titles`, `refresh_env`, and `sessions` (5.4). |
| `launch` module | `modules/launch/` | `bin/launch-session`, `bin/launch-repo`, the run-after-init hook in `init.zsh` and `init.fish`, completions, and options (section 10). It needs the `mux` module. |
| Repository inventory | `modules/git-worktree/bin/repo-list` | Scan, worktree chain, and cache (8.2). `launch-repo` needs the `git-worktree` module. |
| `cwf-new`, `gwt-clean` | their existing modules | Launch options and launched mode (section 9). |

The commands are write-once executables (MARKSHARC-SPEC 6.11). Neither launch command changes the caller's shell, so neither has a wrapper function.

### 5.2 Hosts and machines

A host is named as in `hosts.conf` (MARKSHARC-SPEC 6.14). Names follow the existing `hosts.conf` name rule.

| Name | Meaning |
|---|---|
| absent, `local`, `localhost`, or the value of `MARKSHARC_HOST` | This host. |
| `remote` | Ask with the picker. Without a terminal this exits 3. |
| anything else | A remote host. |

`local`, `localhost`, and `remote` are reserved. A `hosts.conf` entry with one of those names cannot be addressed by a launch command.

The host picker lists the union of `hosts.conf` and the machines of the candidate multiplexers, without this host. Each line shows the name, the target, and which kinds can reach it. Once a kind is fixed, only hosts that kind can reach are listed.

A remote launch needs the host as the chosen multiplexer names it. The adapter's `machines` operation lists that instance's machines, and resolution takes the first rule that matches:

1. A machine whose name equals the host name.
2. A machine whose own hostname equals the host name, where the multiplexer reports one (the `host` field of `hc machine ls`).
3. A machine whose target equals the host's ssh target in `hosts.conf`, or equals the host name.
4. No match is an error that names the command to add the machine, such as `hc machine add <target> --name <host>`.

More than one machine matching at rule 2 or 3 is an error that lists them. Machine names are local to each core, so a name is resolved against the instance that runs the launch and is never copied from another host's list.

`marksharc hosts populate` already copies `hc` machine names into `hosts.conf`, so rule 1 is the common case. `hosts.conf` keeps its format.

### 5.3 Picker

`_ms_pick` reads candidates on standard input, one per line as `<value><TAB><label>`, shows the labels, and prints the chosen values. It prefers `gum` and falls back to `fzf`. `--multi` allows several choices and `--header` sets a prompt line. It returns 3 without printing a menu when standard input or standard error is not a terminal, or when neither tool is installed; the message names the flag that would have avoided the prompt. A cancelled picker returns 1. `marksharc hosts populate` uses it with no change in behaviour.

### 5.4 Launch adapters

Each adapter gains these operations. An adapter that cannot launch (`wezterm`, `plain`) answers `supports` with failure and omits the rest.

| Operation | Contract |
|---|---|
| `supports <feature>` | Succeed when the kind has the feature: `launch`, `remote`, `autostart`, `argv`, `place-workspace`, `place-tab`, `place-hidden`. |
| `current` | When the caller is inside a live instance of this kind, print its instance id. A marker whose server does not answer does not count. |
| `instances` | Print the running local instances, one per line as `<id><TAB><description>`. Neither this nor `current` may start a server. |
| `machines [<instance>]` | Print that instance's machines as `<name><TAB><target><TAB><hostname>`, with an empty hostname when the kind reports none. |
| `launch` | Open one terminal from the request and print `<instance><TAB><address>`. |

The request is data in the caller's scope, like `client_env` for `refresh_env`: the associative array `launch_req` with the keys `instance`, `machine`, `cwd`, `name`, `place`, `focus`, and `dry_run`, the array `launch_env` of `NAME=VALUE` words, and the array `launch_argv`. With `dry_run` set the adapter prints each command it would run, one per line with every word quoted, and runs none of them. An adapter passes every value as one argument and never builds a shell line from request data.

How each kind carries the request:

| | Herdr Core (`hc`) | Herdr TUI | tmux |
|---|---|---|---|
| Instance | `HC_SOCKET` from `HC_TERMINAL_SOCKET` inside a terminal; `HC_SESSION=<id>` otherwise | The inherited context inside a pane; `--session <id>` otherwise | `-S <socket>` from `TMUX` inside a pane, else the default socket; `-t <id>:` |
| Machine | `--on <machine>` | `--machine <label>` | Not supported |
| Directory | `--cwd` for an absolute path. A path under the remote home gets no `--cwd`; the wrapper changes into it. | `--cwd`, with an absolute path when a machine is selected. | `-c` |
| Variables | `env NAME=VALUE …` in front of the program | `--env NAME=VALUE` | `-e NAME=VALUE` |
| Program | The argv. With environment and no argv: `sh -c 'exec "${SHELL:-/bin/sh}" -l'`. For a path under the remote home: `sh -c 'CDPATH= cd -- "$HOME/$1" && shift && exec "$@"' sh <home-relative-dir> <argv…>`. | None; a command travels in `LAUNCH_RUN` (6.4) | The argv. With none: the default shell |
| Name | The label `marksharc.name`. The app names a space after its first terminal's directory | `--label` | `-n` |
| Always | `--bg --no-parent --no-notify` | | `-P -F` to read the address |
| Address | `address` in the JSON reply, as `machine/address` when remote | `pane_id` | `<session>:<window id>.<pane id>` |

Placement:

| `--place` | Herdr Core (`hc`) | Herdr TUI | tmux |
|---|---|---|---|
| `workspace` | `hc run --label herdr.space=<new id>`, the id being `sp` and 32 random hexadecimal digits. | `workspace create` | As `tab`: a session is the instance, so a window is the top level. |
| `tab` | When the caller's terminal carries `herdr.space` and the launch is on the caller's machine: `hc run --label herdr.space=<that id>`. Otherwise as `workspace`. | `tab create --workspace <caller's>`; with no caller workspace, as `workspace`. | `new-window` |
| `hidden` | `hc run` with no `herdr.*` label | `workspace create --no-focus` | `new-window -d` |

Running Herdr Core instances are found without waking one: the adapter lists the sessions that have a `core.lock` and counts a session as running when the socket named in it exists (4.2).

When a placement falls back, the command prints one line on standard error naming the placement used. For a hidden terminal the line includes how to reach it, such as `hc attach t21`. A labelled Herdr Core terminal is shown by whichever app windows watch that core. With none watching it stays reachable by its address, which the result line carries.

`--no-focus` maps to `--no-focus` on the Herdr TUI and `-d` on tmux. A terminal placed by label on Herdr Core appears without taking the focus. When focus is wanted, the adapter looks for the new terminal in its labelled space in the calling host's app window, then runs `herdr-app do agent.focus --terminal <address>` with the app's address. The focus stays where it was when the app has no window on the calling host or cannot resolve the terminal.

Starting a kind with no running instance: tmux creates a detached session with `new-session -d -s <name>` and prints `tmux attach -t <name>` on standard error. Herdr Core starts its core on the first `hc` command. The Herdr TUI is never started.

### 5.5 Choosing the multiplexer

1. **Kind.** `--mux` names it: `hc`, `herdr`, or `tmux` (`herdr-core` is accepted for `hc`). Otherwise, when the caller is inside one or more live instances, the innermost wins, taken as the first of `tmux`, `herdr`, `hc` whose `current` answers. For tmux the pane named by `TMUX_PANE` must also own the caller's terminal when the caller has one, so a stale inherited `TMUX` does not count. Otherwise the kind is the first in `launch.prefer` with a running local instance. With none running, it is the first in `launch.prefer` that is installed and supports `autostart`.
2. **Remote.** During automatic selection a kind that does not support `remote`, or whose instance has no machine for the host, is skipped. With `--mux` the same condition is an error.
3. **Instance.** `--mux-id` names it. Otherwise it is the caller's own instance when the caller is inside that kind, else the only running instance. Several running instances ask with the picker, or exit 3 without a terminal.
4. **Machine.** Section 5.2.

No usable multiplexer exits 1 with a line that says what was tried.

## 6. launch-session

### 6.1 Syntax

```
launch-session [options] [[host:]dir [command [args…]]]
launch-session [options] -- command [args…]
launch-session [options] [--host H] [--pwd D] [--command C] [-- args…]
```

The first two lines are the positional form. The first positional word is the target. It has a host part only when the text before its first `:` is a valid host name and the rest is empty or starts with `~` or `/`; a local path that looks like that is written with a leading `./`. Option parsing stops at the command word or at `--`, so the command's own options pass through.

The third line is the flag form, selected by any of `--host`, `--pwd`, or `--command`. It takes no positional target. Words after `--` are the arguments of `--command`, or the whole command when `--command` is absent.

| Option | Meaning |
|---|---|
| `--host <name>` | The host (5.2). Default: this host. |
| `--pwd <dir>` | The starting directory. Default: the home directory. For a remote host it must be `~`, start with `~/`, or be absolute. A local path, relative or under `~`, is made absolute before the launch. |
| `--command <program>` | The program to run. Default: the login shell. |
| `--mux hc\|herdr\|tmux` | The kind (5.5). |
| `--mux-id <instance>` | The instance: a Herdr Core session, a Herdr TUI session, or a tmux session name or id. |
| `--place workspace\|tab\|hidden` | The placement (5.4). Default: `launch.place`. |
| `--name <text>` | A display name. Default: the last component of the directory. |
| `--env NAME=VALUE` | Set a variable in the new session. Repeatable. The name must be a shell identifier that does not start with `LAUNCH_`. |
| `--in-shell` | Run the command inside the session's interactive login shell and stay at its prompt (6.4). |
| `--no-focus` | Leave the caller's view where it is. Default: `launch.focus`. |
| `--dry-run` | Print the multiplexer commands, one per line with every word quoted, and run nothing. |
| `--quiet` | Print no result line. |
| `-h`, `--help` | Usage. |

### 6.2 Result

On success the command prints one line, `<kind><TAB><instance><TAB><machine><TAB><address>`, with an empty machine field for this host. Notices go to standard error.

| Status | Meaning |
|---|---|
| 0 | The terminal was created. |
| 1 | The launch failed: no usable multiplexer, an unreachable host, or a multiplexer error. |
| 2 | A usage or validation error. Nothing was started. |
| 3 | A choice was needed (host, instance, or repository) and there was no terminal to ask in, or no picker tool. Nothing was started. |

A zero status means the multiplexer accepted the terminal. It does not mean the program started correctly.

### 6.3 Command modes

| Request | The terminal runs | It ends when |
|---|---|---|
| No command | The login shell | The shell exits |
| A command | The command, as an argv with no shell in between | The command exits |
| A command with `--in-shell` | The login shell, which runs the command after its init and then prompts | The shell exits |

On the Herdr TUI a pane always starts its shell, so a plain command also travels through 6.4, with the shell replacing itself by the command.

### 6.4 Run after init

`LAUNCH_RUN` carries an argv to the new session's shell: the words tab-separated, with tab, newline, and `%` percent-encoded as in the directive protocol (MARKSHARC-SPEC 6.11). `LAUNCH_RUN_EXEC=1` asks the shell to replace itself with the command.

The `launch` module's init registers a one-shot hook when `LAUNCH_RUN` is not empty and the session class is `interactive`. The hook fires before the first prompt, after every module's init. It decodes the argv, unsets both variables, and then runs the argv as one simple command, so shell functions such as the `cwf-new` wrapper apply. With `LAUNCH_RUN_EXEC` it uses `exec`. zsh uses a self-removing `precmd` hook and fish a self-erasing `fish_prompt` handler. The text is never evaluated as shell code.

The target shell must be a marksharc zsh or fish with the `launch` module enabled. Any other shell ignores the variable and opens at its prompt; the launcher cannot detect that.

## 7. Launch metadata

### 7.1 Variables

`launch-session` sets these in every session it creates. An empty value means absent. Every variable is always passed, so a value inherited from the multiplexer server's own environment never applies.

| Variable | Value |
|---|---|
| `LAUNCH_PARENT_PID` | The process that ran the launch command: the caller's shell. `launch-repo` and `cwf-new` replace themselves with `launch-session`, so the value is the same through them. |
| `LAUNCH_PARENT_HOST` | The caller's `MARKSHARC_HOST`. |
| `LAUNCH_PARENT_SSH_AUTH_SOCK` | The caller's `SSH_AUTH_SOCK`, or empty. |
| `LAUNCH_PARENT_DISPLAY` | The caller's `DISPLAY`, or empty. |
| `LAUNCH_RUN`, `LAUNCH_RUN_EXEC` | Section 6.4, or empty. |
| `LAUNCH_WORKTREE` | Empty. `cwf-new --launched` sets it inside the session (9.1). |

For a launch on this host the session also receives the caller's `DISPLAY`, `XAUTHORITY`, and `SSH_AUTH_SOCK` when the caller has them. A remote session receives none of the three; it relies on its own startup. The session class markers of the caller (MARKSHARC-SPEC 6.6) are never passed, so a terminal launched by an agent is an ordinary interactive session.

### 7.2 Startup

The values are hints. They can outlive the caller, so each consumer checks them as it checks a cached socket (MARKSHARC-SPEC design rule 7).

- `setup-ssh-agent` tries the inherited `SSH_AUTH_SOCK` first, as today. When that fails and `LAUNCH_PARENT_HOST` is this host, it probes `LAUNCH_PARENT_SSH_AUTH_SOCK` before the cache, discovery, and a new agent.
- `setup-x11-display --startup` asks the multiplexer for the client `DISPLAY` first, as today. When there is none and `LAUNCH_PARENT_HOST` is this host, a non-empty `LAUNCH_PARENT_DISPLAY` comes before the inherited value and the SSH-derived guess. An empty value changes nothing.

Neither consumer acts on a value from another host.

## 8. launch-repo

### 8.1 Syntax

```
launch-repo [options] [[host:]repo[/worktree] [command [args…]]]
launch-repo [options] [--host H] [--repo R] [--worktree W] [--command C] [-- args…]
```

`launch-repo` resolves a repository to a directory and replaces itself with `launch-session --host <host> --pwd <path> --name <name>`. It accepts every `launch-session` option except `--pwd` and passes them through. `--rescan` rebuilds the inventory first. The flag form is selected by any of `--host`, `--repo`, `--worktree`, or `--command`.

In the positional form the text before the first `:` is the host when it is a valid host name. The text after it splits at the first `/` into the repository and the worktree. In either form a repository that is `~`, or starts with `~/` or `/`, is a path to a Git work tree and is used as it is, with no worktree part.

With no repository the picker lists every repository and worktree as `repo` and `repo/worktree` with the branch and path. Without a terminal that exits 3. There is no default repository. `.` names the repository that contains the current directory.

### 8.2 Inventory

`repo-list` prints the inventory of one host, one record per line: `<name><TAB><path><TAB><kind><TAB><base><TAB><branch>`. `kind` is `base` or `worktree`, and `base` is the path of the base repository.

- **Roots.** The `git-worktree.roots` option lists the directories to scan. It keeps its meaning for `repo-sync`.
- **Scan.** Each immediate subdirectory of a root that holds a `.git` directory is a base repository, named by its directory name. A `.git` file marks a linked worktree and is skipped; worktrees come from their base.
- **Chain.** `git worktree list --porcelain` in each base lists its linked worktrees. A worktree is named by its directory name. Missing and prunable worktrees are left out.
- **Cache.** The result is written to `${XDG_CACHE_HOME:-~/.cache}/marksharc/<host>/repos/local.tsv` with a header line that records the format version, the scan time, and the roots. The write is atomic and the file is mode 0600.
- **Freshness.** The cache is rebuilt when it is older than `launch.repo_cache_minutes`, when the roots differ from the header, when `--rescan` is given, when a requested name is not in it, and when a path it returned no longer exists.
- **Remote.** The inventory of another host comes from `ssh -o BatchMode=yes -o ConnectTimeout=<launch.ssh_timeout> -n -- <target> repo-list --porcelain`, run as `marksharc push` runs ssh. It is cached as `repos/<host>.tsv` under the same rules. The remote host scans its own roots and needs marksharc with the `git-worktree` module. The host needs an ssh target, from `hosts.conf` or from a machine entry that is not a `--via` command.

### 8.3 Resolution

1. A repository name matches a base record by exact name. Several bases with that name ask with the picker, or exit 3 with their paths.
2. A worktree name matches a worktree of that base by directory name, then by exact branch name. Branch names may contain `/`.
3. No match after one rescan exits 1 with the nearest names.
4. A worktree part that contains `:` is the reserved creation form and exits 2.

Only existing worktrees are opened. `cwf-new` creates them (section 9).

## 9. cwf-new and gwt-clean

### 9.1 cwf-new

```
cwf-new <branch>
cwf-new [--repo R] [--host H] [--mux K] [--mux-id I] [--place P] [--launch] [--pick] <branch>
```

The first form is unchanged: it runs in a base repository root and enters the new worktree in the calling shell.

Any option selects launch mode. `cwf-new` then replaces itself with:

```
launch-repo [--host H] [--mux K] [--mux-id I] [--place P] --in-shell --repo <repo> -- cwf-new --launched <branch>
```

The repository is `--repo` when given. Otherwise it is the base repository that contains the current directory: passed as a path for this host, and by name for another host, where that host's inventory resolves it. Outside a repository, or with `--pick`, `--repo` is left out and the `launch-repo` picker asks. The target is always the base repository, never a worktree.

The new terminal opens in the base repository on the target host. Its shell finishes init and runs `cwf-new --launched <branch>` through 6.4. That is the unchanged in-place creation: `cwf session new --no-tmux`, the copy of unmanaged files, the post-create hooks, the `setenv` directives, and `pushd` into the worktree. Hooks work because the overlay registers them during interactive init. On success `--launched` also emits `setenv LAUNCH_WORKTREE <worktree path>`, which marks the terminal as belonging to that worktree. On failure the terminal stays at the base repository with the error on screen.

The caller's shell is not changed and does not learn the worktree path. `cwf-new` keeps using `cwf session new --no-tmux`; the multiplexer backends of `cwf` itself are not used.

### 9.2 gwt-clean

`gwt-clean` runs its checks, confirmation, pull, hooks, environment destruction, worktree removal, and branch deletion as today. When `LAUNCH_WORKTREE` names the worktree it just removed, compared as resolved paths, and every step succeeded, it emits `exit 0` after its `cd <base>` directive. The shell then exits and the terminal closes.

It does not exit when a step failed, when `LAUNCH_WORKTREE` is empty, or when it names another path. A terminal launched into a base repository in which the user later ran plain `cwf-new` therefore stays open.

### 9.3 The exit directive

The caller-state protocol (MARKSHARC-SPEC 6.11) gains one line:

| Directive line | Effect in the calling shell |
|---|---|
| `exit [<status>]` | After the remaining directives are applied and the directive file is removed, exit the shell with the status, 0 by default. |

The status must be a number from 0 to 255; any other value is ignored with a message. The zsh and fish appliers implement it. An applier without it reports an unknown directive and continues, and a direct call from bash ignores the file.

## 10. Configuration

| Option | Default | Meaning |
|---|---|---|
| `launch.prefer` | `hc herdr tmux` | The order of kinds when the caller is not inside a multiplexer, and the order tried when one must be started. |
| `launch.place` | `workspace` | The default placement. |
| `launch.focus` | `on` | Whether a new terminal takes focus where the multiplexer allows a choice. |
| `launch.repo_cache_minutes` | `60` | The age at which a repository inventory is rebuilt. |
| `launch.ssh_timeout` | `10` | The connect timeout in seconds for a remote inventory. |
| `git-worktree.roots` | empty | The directories whose immediate subdirectories are repositories (existing option). |

The module is enabled by default. It adds two executables to PATH and does nothing at startup unless `LAUNCH_RUN` is set.

## 11. Testing

The rules of MARKSHARC-SPEC section 8 apply: a temporary HOME, command stubs, and no real service.

| Area | What the specs prove |
|---|---|
| Adapters | The contract in 5.4 for every adapter against stub `hc`, `herdr`, `herdr-app`, and `tmux` that record their argv. Each placement, local and remote, and each directory form. Values with spaces, semicolons, dollar signs, quotes, and newlines arrive as single arguments. |
| Selection | Every branch of 5.5: `--mux`, nesting, a stale marker, preference order, autostart, several instances with and without a terminal. |
| Hosts | Reserved names, both matching rules, the ambiguous and missing cases, and the picker's union. |
| Picker | `gum`, `fzf`, neither, no terminal, cancel. `marksharc hosts populate` behaves as before. |
| `launch-session` | Both syntax forms and their conflicts, every status in 6.2, `--dry-run` goldens, the metadata in 7.1, and no agent marker in the new session. |
| Run after init | zsh and fish: the command runs once after init, the variables are gone before it runs, `exec` mode, an encoded argv with tab and newline, and no action in batch and agent sessions. |
| Startup | `setup-ssh-agent` and `setup-x11-display` with a usable, a dead, and an other-host parent value. |
| Inventory | Disposable repositories: scan, worktree chain, cache header, every freshness rule, and a stub `ssh` for the remote case. |
| `launch-repo` | Each rule in 8.3, the path form, the reserved creation form, and the `launch-session` argv it produces. |
| `cwf-new`, `gwt-clean` | The unchanged in-place path, the launch-mode argv, `LAUNCH_WORKTREE`, and each case in 9.2. |
| `exit` directive | zsh and fish appliers: order, status validation, and file removal before the exit. |

Each behaviour gets a row in the contract inventory in `tests/README.md`. Live acceptance is in [LAUNCH-PLAN.md](LAUNCH-PLAN.md).

## 12. Risks and open questions

| Risk or question | Handling |
|---|---|
| Creating a space through an unused `herdr.space` id is observed behaviour, not a documented interface. | The label logic sits in one adapter. If the app stops honouring it, the terminal still exists and is reachable by the address in the result line. |
| A launch cannot tell whether any app window shows the core. | The result line always carries the address, and the documentation gives `hc attach`. |
| `hc server status` starts a core, so a careless probe leaves one running. | Adapters read `core.lock` and test the socket it names (4.2, 5.4). |
| `hc` and `herdr-app` are young and change quickly. | All tool syntax lives in the adapters. `--dry-run` shows the exact commands. Section 4 records the reviewed versions. |
| `LAUNCH_RUN` runs a command named by the environment. | Interactive sessions only, once, cleared before it runs, and never evaluated as text. Whoever controls a shell's environment already controls the shell. |
| A shell without the `launch` module ignores `LAUNCH_RUN`, so `--in-shell`, launched `cwf-new`, and any command on the Herdr TUI silently open a plain shell there. | `marksharc push` keeps hosts current. The user documentation states the requirement. |
| Three machine lists drift apart. | Resolution by name, then by target (5.2). Each error names the command that fixes it. |
| A host named `local`, `localhost`, or `remote`. | Reserved and documented. |
| A multiplexer server inherits launch variables from the shell that started it. | Every variable is passed on every launch, empty when unused (7.1). `gwt-clean` compares paths, not presence (9.2). |
| `hc`'s own `shell` setting is bypassed when variables must be set. | The session runs `$SHELL` as a login shell. Revisit if `hc run` gains an environment option. |
| tmux older than 3.2 lacks `new-session -e`. | Homebrew tmux on macOS is 3.8 (V9). The tmux adapter reports the version when a launch fails for that reason. |

## 13. Decision log

| Decision | Choice | Source |
|---|---|---|
| Command names | `launch-session` and `launch-repo`. Bare `repo` collides with the Android `repo` tool. | Operator, DEV-78 |
| `cwf-new` in a launched terminal | Launch, then create: the new terminal runs `cwf-new` in its own interactive shell, the same way locally and remotely. | Operator, DEV-78 |
| Work boundaries | A foundation issue (DEV-79) ahead of DEV-74. | Operator, DEV-78 |
| Syntax | Both forms on one parser: positional for people, flags for automation. | DEV-78 |
| Picker alias | The reserved host name `remote`; an omitted repository. No option takes an optional value. | DEV-78 |
| Variable names | `LAUNCH_PARENT_*` as proposed in DEV-74, with `LAUNCH_RUN`, `LAUNCH_RUN_EXEC`, and `LAUNCH_WORKTREE` beside them. | DEV-74, DEV-78 |
| Environment on `hc` | An `env` wrapper, because `hc run` has no environment option. | Review, DEV-78 |
| Placement on `hc` | `herdr.space` labels alone: the caller's id for a tab, a new id for a space. `herdr-app` is used only for focus. | Live checks, DEV-78 |
| Remote home paths on `hc` | The wrapper changes directory, because `--cwd` does not expand `~`. | Live checks, DEV-78 |
| Detecting a running `hc` core | The session's `core.lock` names the socket, and the socket's presence is the test. No `hc` command is used, because each one starts the core. | Operator, DEV-78 |
| Independence on `hc` | Always `--no-parent --no-notify`; `LAUNCH_PARENT_PID` carries the relationship. | Review, DEV-78 |
| Several `hc` cores per user | Supported through `--mux-id`. The DEV-74 assumption of one core per user does not hold. | Review, DEV-78 |
| Remote tmux | Later. | DEV-74 |
| Worktree creation in `launch-repo` | Not now; the `repo/worktree:branch` form is reserved. | DEV-75, DEV-78 |
| Closing a launched terminal | A new `exit` directive, emitted only when `LAUNCH_WORKTREE` names the removed worktree. | DEV-78 |
| Remote code | The remote host runs its own marksharc. Nothing is shipped to it. | DEV-78 |
| Containers | No separate design; an `hc` machine added with `--via` covers the case. | DEV-78 |
