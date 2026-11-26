# DEV-82 Bash native modules and workflow parity

Implement L2.3 from [BASH-SPEC.md](BASH-SPEC.md) on the runtime and caller-state wrappers from DEV-80. [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md) sections 6, 7 and 10 govern the public module surface. [LAUNCH-SPEC.md](LAUNCH-SPEC.md) sections 6.4, 7 and 9 govern launch and worktree integration.

## Navigation

- Port `dirhistory_back`, `dirhistory_forward`, `dirhistory_up`, `dirhistory_down` and directory stack cycling to native Bash. Observe ordinary directory changes through the registry and keep native `cd`, `pushd`, `popd` and `dirs`. Keep paths literal, including when `CDPATH` is set.
- Bind Alt-arrows in emacs, vi insertion and vi command modes. Run the regular prompt cycle after keys change directory so the visible prompt reflects the new location. Restore prior bindings when the module turns off and retain later user edits.
- Exercise history traversal, new history branches, parent/first child, directory stack, prompt redraw and binding cleanup in a Bash PTY.

## Public modules

- Port ls aliases and platform color, editor and pager defaults, man and diff helpers, theme/vivid/bat/delta/fzf environment, command-not-found, and all seven ps helpers. Reuse the existing ps executable logic in a child. Use the Bash lifecycle to track exports, aliases and functions. Test optional tools present and absent, plus reload and disable.
- Port titles, mux refresh, ssh-agent, X11, brew, git-worktree, cwf and Herdr to Bash with the same guards and shared executables used by the other shells. Load caller-state wrappers from DEV-80. Register callbacks through the core registry. Test configuration transport, caller state, and cleanup using tool stubs.

## Launch and startup

- Register a Bash one-shot prompt callback for `LAUNCH_RUN`. Decode tab-separated fields through `_ms_bash_decode_field`, clear the markers before invocation, run literal argv in the current shell, and use `exec` for `LAUNCH_RUN_EXEC=1`. Test empty and literal arguments, caller functions, a second prompt, exec status, and ineligible sessions.
- Use the shared notify executable and state for Bash interactive startup, with the established throttle and opt-out. Port the opt-in greeting, keeping startup and reload quiet in ineligible modes.

## Verification

- Run `tests/check` and `tests/e2e/install-e2e.sh` and inspect the disposable PTY output. Run focused coverage against Bash 4.4 and current Bash 5.x when available. Record platform and tool limits. DEV-83 owns completion, line-editor acquisition and full cross-platform acceptance.

The Linux shell contracts cover Bash 4.4.0, 5.2.37 and 5.3.0. Bash 3.2.57
passes the environment-only case. The installed Bash 5.2.37 smoke test opens a
disposable tmux window at a path with spaces, runs a function with literal
and empty arguments once, and leaves the prompt active. The shared Herdr
adapter contracts cover Herdr launch. Herdr's Bash completion belongs to DEV-83.

Startup measurements use a disposable installed Linux HOME, with sync
and Starship disabled. Time runs from process start to the visible prompt.
Each row records one cold start and five warm starts.

| Revision and Bash | Cold | Warm median | Warm max |
| --- | ---: | ---: | ---: |
| `d1899a3`, 5.2.37 | 1,221 ms | 465 ms | 477 ms |
| DEV-82, 4.4.0 | 3,868 ms | 880 ms | 924 ms |
| DEV-82, 5.2.37 | 1,610 ms | 666 ms | 679 ms |
| DEV-82, 5.3.0 | 1,671 ms | 673 ms | 709 ms |

Warm Linux startup remains above the 500 ms target. DEV-83 owns the full
real-tool and startup-budget acceptance on Linux and macOS.
