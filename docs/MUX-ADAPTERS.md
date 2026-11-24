# Multiplexer titles and forwarding

In zsh and fish, `chdir-set-title` computes the workspace, tab, and pane titles from the repository, branch, `cwf` session, and path. Each detected multiplexer receives the same titles. A plain terminal receives the existing terminal escapes when there is no native title adapter. `set-title TAB [WINDOW [COMBINED]]` is available for writing those escapes directly.

| Terminal | Title destination | Reattach behavior |
| --- | --- | --- |
| tmux | Window and pane addressed by `TMUX_PANE` | Imports the session's client environment before the next prompt or command. Keep `DISPLAY`, `XAUTHORITY`, and `SSH_AUTH_SOCK` in tmux's `update-environment` option. `fix-tmux` refreshes these variables explicitly. |
| Herdr TUI | Workspace, tab, pane and existing workspace metadata | `refresh-env` checks inherited values and can recover SSH forwarding when it finds one usable candidate. The generated `herdr-<session>` and `collie-<session>` shims use the TUI session inventory. |
| Herdr app and core | OSC 2 pane title in the app and `marksharc.workspace`, `marksharc.tab`, and `marksharc.pane` labels on the addressed core terminal | Run `refresh-env` inside the terminal. App workspace and tab names are UI settings. Core labels are available to clients that render them. |
| WezTerm | Tab addressed by `WEZTERM_PANE`. An ordinary SSH shell can use terminal escapes. | Run `refresh-env` inside a persistent shell. The WezTerm CLI lists panes and sets titles. |
| Plain terminal | OSC title escapes or the terminal's terminfo title controls | A fresh SSH shell inherits its forwarding environment. `refresh-env` can find a platform agent if the inherited socket is unusable. |

tmux's attach operation updates session data shared by the attached clients. A shell already running in a pane applies changed client data when it next runs its shell hook. An application already running in the pane keeps the environment it started with. With several clients in one session, tmux's last session update determines the values. [tmux manual](https://github.com/tmux/tmux/blob/master/tmux.1)

Herdr and WezTerm expose environment options for newly created terminals. Their public attach interfaces do not supply the attaching client's environment to an existing shell. An ordinary `ssh -A` or `ssh -X` connection starts with the corresponding forwarding when the server and client support it. `refresh-env` repairs the shell environment using forwarding that already exists on that host. [Herdr TUI CLI](https://herdr.dev/tui/docs/cli-reference/) · [Herdr Core CLI](https://github.com/herdrdev/herdr-core/blob/master/docs/commands.md) · [Herdr app terminal title handler](https://github.com/herdrdev/herdr-app/blob/2d1464e02ddad5484eaaf9a5b59b594e3930aeba/src/terminal.rs#L600) · [WezTerm CLI](https://wezterm.org/cli/cli/index.html)

For X11, `setup-x11-display` or `refresh-env` reads client `DISPLAY` first. When a persistent SSH terminal has no client value, the command can check local forwarding candidates from `xauth` and the SSH default `localhost:10.0` with `xdpyinfo`. Probes require `timeout` or `gtimeout` and run only on demand. With ambiguous results or too many candidates to check, use an explicit `DISPLAY`. Startup uses local mux data and the inherited environment. [X.Org xauth manual](https://xorg.freedesktop.org/archive/X11R6.7.0/doc/xauth.1.html) · [OpenSSH server configuration](https://man.openbsd.org/sshd_config#X11DisplayOffset)

SSH agent recovery accepts an owned Unix socket. The automatic tmux update checks socket ownership and type. `refresh-env` also tests whether an agent responds. Without tmux client data, it checks the inherited agent, then same-user SSH sockets in the temp directory when in a persistent SSH session, then the macOS launchd agent or Linux `$XDG_RUNTIME_DIR/openssh_agent`. Forwarded socket scans require `timeout` or `gtimeout`. Multiple usable sockets trigger the platform fallback. `setup-ssh-agent` can also reuse its cached local agent or start a new one.

## Writing a mux adapter

Add a `.zsh` file to `modules/mux/adapters/`. The dispatcher discovers filenames and sources them with the operation as `$1`.

| Operation | Contract |
| --- | --- |
| `detect` | Return success when the calling shell belongs to this provider. Use provider markers and any required CLI. Keep detection quiet and cheap. |
| `set_titles WORKSPACE TAB PANE [SUBNAME SOURCE]` | Use a stable target from the calling shell. Pass titles as data and escape any format syntax the provider interprets. Optional metadata uses the directory subtitle and hook source. |
| `refresh_env NAME...` | Write known values into the caller's `client_env` associative array. An empty value records an explicit removal. Leave a key absent when the provider has no client value. The dispatcher handles probes, environment directives and shell state. |
| `sessions` | Print the provider's session inventory as data. The Herdr TUI adapter returns `name<TAB>socket` for the shim generator. |

Extend the contract spec in `modules/mux/tests/adapters_spec.sh` with stubbed CLIs. Exercise nesting, missing tools, stable targeting, literal title text, and client fields the provider can actually retrieve.

- **Rex** injects `REX_BLOCK` and `REX_SERVER`. An adapter can use the block context for its title targets and `rex ls --json` for stable session IDs. An environment adapter would need a client-side source of forwarding values and a way to associate them with the selected session. [Rex CLI](https://www.superlogical.com/rex/docs/automate/cli)
- **Orca** uses xterm.js and has its own tab naming rules. An adapter would need a stable shell-visible workspace, tab, or pane ID and a supported route to Orca's title and session APIs. It would need a scoped attach API to import forwarding values automatically. [Orca terminal docs](https://orca.dev/docs/terminal)
