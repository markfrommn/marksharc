# Launch a terminal session

`launch-session` opens a terminal in a directory on this host or on a machine known to Herdr. The default-enabled `launch` module makes the command available on PATH and provides completions in zsh and fish.

```sh
launch-session ~/src
launch-session 'build1:~/src'
launch-session --host build1 --pwd '/srv/team work' --command git -- status --short
launch-session --in-shell ~/src git status
```

With no directory, the session starts in the target host's home. Local relative paths are resolved from the current directory. A remote positional target uses `host:`, `host:~/dir`, or `host:/absolute/dir`. To open a local path that looks like a host target, prefix it with `./`. Quote a remote home path to keep `~` literal for the launcher.

The flag form starts when you give `--host`, `--pwd`, or `--command`. Use `--` before the command's arguments, or before the entire command when `--command` is omitted. In the positional form, arguments after the command belong to that command.

## Host and multiplexer selection

- Omit the host or pass `local`, `localhost`, or the current `MARKSHARC_HOST` to launch on this host. Pass `--host remote` to pick a remote host with `gum` or `fzf`.
- Use `--mux hc`, `--mux herdr`, or `--mux tmux` to choose a kind. `herdr-core` is an alias for `hc`. Use `--mux-id` for a Herdr Core session, a Herdr TUI session, or a tmux session name or ID.
- Automatic selection starts with the innermost live multiplexer. Outside a mux, it uses the first running kind in `launch.prefer`. With no running instance, a supported installed kind can start a Herdr Core or a detached tmux session. When several instances are eligible, pass `--mux-id` or choose from the picker.
- Remote launching uses Herdr Core or Herdr TUI. Configure the machine in that multiplexer. The launcher can match its name, its reported hostname when available, or its SSH target in `hosts.conf`. If a Herdr TUI remote directory is below the target's home, supply its absolute path. Omit the directory or use `~` to start in the remote home.

## Placement and the new shell

`--place workspace|tab|hidden` controls placement. With Herdr Core, workspace creates a new app space and tab uses the caller's space when available. In Herdr TUI, a tab uses the caller's workspace when available. If the caller has no space or workspace suitable for a tab, the mux creates one. In tmux, a workspace opens as a window in the selected session. A hidden session prints how to reach it on standard error. Pass `--name` to set the display name and `--no-focus` to keep the current view where supported.

With no command, the session opens at the shell prompt. A command normally takes the place of the shell and the terminal ends when the command exits. `--in-shell` runs the command after interactive startup and leaves the shell at its prompt. For `--in-shell` and commands on the Herdr TUI, the target shell must be MarkSharc zsh or fish with `launch` enabled.

Repeat `--env NAME=VALUE` to set variables in the new session. `NAME` must be a shell identifier. Names beginning with `LAUNCH_` are reserved. The launcher sets `LAUNCH_PARENT_HOST`, `LAUNCH_PARENT_PID`, `LAUNCH_PARENT_SSH_AUTH_SOCK`, and `LAUNCH_PARENT_DISPLAY`. A local launch carries `SSH_AUTH_SOCK`, `DISPLAY`, and `XAUTHORITY` when present. The startup helpers can reuse same-host parent values.

Set defaults in `config.conf` or in the per-host overlay file.

| Setting | Default | Purpose |
| --- | --- | --- |
| `launch.prefer` | `hc herdr tmux` | Order for choosing among running kinds or kinds that can be started |
| `launch.place` | `workspace` | Default placement |
| `launch.focus` | `on` | Focus a newly created terminal when possible |

## Automation

Specify the host and instance when selection would need a picker. A successful launch prints `kind<TAB>instance<TAB>machine<TAB>address` on standard output. The machine field is empty for local launches. `--quiet` suppresses the result line. `--dry-run` uses read-only discovery to preview the mux commands with each word quoted. It skips creation and focus.

| Status | Meaning |
| --- | --- |
| `0` | The multiplexer accepted the new terminal, or the dry run completed. |
| `1` | The launch failed, the host or mux was unavailable, or the picker was cancelled. |
| `2` | The request was invalid. |
| `3` | A choice required a terminal and a picker, so it could not be made. |

For the full option list, run `launch-session --help`.
