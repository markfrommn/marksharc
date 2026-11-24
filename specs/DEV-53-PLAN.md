# DEV-53 multiplexer adapters

Implements [§6.13 and §10](MARKSHARC-SPEC.md) and [P3.5](MARKSHARC-PLAN.md) for [DEV-53](https://linear.app/psols/issue/DEV-53/marksharc-p35-multiplexer-adapters-and-mux-aware-x11-and-ssh-auth-sock).

## Approach

- Use one zsh dispatcher with one file per adapter. Keep the directory hook and title calculation native to each shell. Preserve the existing `set-title` bytes and dispatch to all detected multiplexers. Use terminal escapes when there is no native title destination.
- Prefer native session data. tmux copies the attaching client's `update-environment` into the target session. Import it into existing shells at their next prompt or before the next command without typing into the pane. Herdr TUI and `hc` offer launch-time environment configuration. WezTerm's CLI offers titles and pane listings. Their documented attach interfaces do not expose an equivalent client environment snapshot.
- Reuse the agent probe and caller-state directives. For explicit refresh, try an unambiguous same-user forwarding socket, then a platform agent. For X11, try local `xauth` display numbers and the OpenSSH default `localhost:10.0` only with a bounded `xdpyinfo` check. Preserve quiet, offline startup. Shared per-user snapshots could associate one connection's forwarding with another, so use scoped client data where available and refuse ambiguous guesses.
- Use `hc label` on the addressed terminal for Herdr app/core metadata and OSC 2 for the app's pane title. App workspace and tab rename commands operate on GUI state. Core labels and terminal output can travel back from a remote core without connecting the remote shell to the GUI socket.

## Implementation and verification

1. Exercise detection, titles, refresh and sessions with stubbed CLIs, including nested routing and independent failure. Preserve byte-exact OSC output.
2. Put the dispatcher and adapters in `modules/mux`. Use the Herdr adapter's session inventory when rendering the established shims.
3. Expose `refresh-env` in zsh and fish and keep `fix-tmux` for tmux forwarding. Read a single tmux snapshot and apply it only when it changes. Join X11 recovery and agent discovery to the same inputs. Keep probes and agent startup out of prompt hooks.
4. Document attach behavior, the adapter interface, and the Rex and Orca extension points. Run `tests/check` and the install E2E gate. Compare live checks with the issue's client matrix.

## Live coverage

Disposable tmux and Herdr Core sessions exercise session DISPLAY import and removal, literal titles and Core terminal labels locally and via SSH to sol. The SSH run also checks a live forwarded agent socket. Herdr TUI, the desktop app, WezTerm, and a live X11-forwarded display remain part of the manual client matrix. Shell contract tests cover those paths with stubs.
