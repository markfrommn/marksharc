# DEV-74 implementation plan

Implement [LAUNCH-SPEC.md](LAUNCH-SPEC.md) sections 5.5, 6, 7, and 10 under [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md) sections 6.6, 6.11, 8, and 10. DEV-79 supplies the adapter, picker, and host inventory interfaces. [LAUNCH-PLAN.md](LAUNCH-PLAN.md) P3.9.2 defines the delivery boundary.

1. Add the default-enabled `launch` module and a write-once `launch-session` executable. Parse both syntaxes into one request, preserving every argument after the command. Reject conflicting forms, invalid choices and reserved environment names before discovery. Load the module options from the resolved overlay and use the shared hosts inventory and picker.
2. Resolve a launch in a live nested instance, a running instance by preference, or an installed autostart kind. Validate tmux pane ownership against the caller's terminal when available. Resolve remote machines against each candidate instance. Ask only when eligible choices remain ambiguous. Use the adapter interface for placement, dry run and creation. Exercise selection and all four statuses with CLI stubs.
3. Build the launch environment and preserve argv fields through the multiplexer boundary. Reuse the directive protocol's percent encoding for run-after-init. Add one-shot zsh and fish hooks that execute after module init in interactive sessions. Test normal and exec modes, empty and encoded words, reload, and batch and agent exclusions.
4. Probe a same-host launch parent's agent socket after the inherited socket. For X11 startup, prefer a same-host parent display after the mux client display, before the inherited display. Test usable, missing or dead, and other-host hints, preserving existing startup precedence.
5. Add zsh and fish completions, the launch guide, README and catalog entries, changelog, and contract inventory. Exercise rendered commands and run `tests/check`. Record live acceptance separately for tmux, Herdr TUI, local sol in the Herdr app, and Mac-to-sol in the Herdr app. The operator must be present for changes to a live Herdr window.

## Live acceptance

| Target                   | Evidence                                                                                                                                                                                                    |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| tmux 3.5a on sol         | A disposable detached session opened in a directory containing a space with the caller's display and SSH socket values. A launch from an agent environment started with the agent marker unset.             |
| Herdr TUI 0.9.5 on sol   | The installed command opened a pane in a disposable headless server. Its login shell ran the supplied argv after init, preserved metacharacters, and cleared the run metadata before executing the command. |
| Herdr Core 0.1.22 on sol | A disposable named core opened a terminal in the requested directory and set the workspace label that the app uses to make it visible.                                                                      |
| Herdr app on macOS       | The Mac-to-sol and sol-local visibility checks in P3.9.2 remain pending with the operator present. The multi-day hands-on gate remains pending.                                                             |
