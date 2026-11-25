# DEV-79 — Launch foundation

**Goal:** Give `launch-session`, `launch-repo`, and the launched `cwf-new` flow a shared picker, host resolution, and mux launch operations.

**Authority:** MARKSHARC-SPEC §§ 6.11, 6.13, 6.14, 8, and 10. LAUNCH-SPEC §§ 4, 5.1–5.4, and 11. LAUNCH-PLAN P3.9.1.

## 1. Picker, JSON reader, and host resolution

- Extract the `hc machine ls` scanner to `core/zsh/lib/json.zsh`. `_ms_json_parse <json>` fills the caller's `json_values` and `json_types` associative arrays, keyed by JSON Pointer. Store array lengths as values so adapters can iterate rows. Decode JSON escapes, skip no structural validation, and return failure on malformed replies. Test the actual inventory, launch, and placement shapes with unrelated nested fields and escaped values.
- Add `_ms_pick` in `core/zsh/lib/pick.zsh`. Pass candidates on stdin and keep the caller's terminal open on an explicit fd when redirecting stdin to the candidates. Check that fd and stderr before prompting. Use gum first, then fzf, and return the selected values. Cover single and multi-select, cancellation, missing tools, and non-terminal execution.
- Migrate `marksharc hosts populate` to those helpers. Exercise its normal entry point with both pickers under a PTY, and cover `--all`, existing entries, and the missing-picker and non-terminal paths.
- Add host classification, SSH target lookup, mux machine matching, and picker candidate generation in `core/cli/hosts-lib.zsh`. Exercise reserved names, all match tiers, ambiguity within a tier, missing-machine guidance, and the picker union and kind filter.

## 2. Launch adapter contract

- Dispatch `supports`, `current`, `instances`, `machines`, and `launch` from `marksharc-mux`. The launch entry point accepts `--instance`, `--machine`, `--cwd`, `--name`, `--place`, `--focus`, `--no-focus`, `--dry-run`, repeated `--env`, and argv after `--`. Pass the parsed request and arrays to the sourced adapter. Print a quoted command per line in dry-run mode. Use caller context and local metadata for the plan. Where a query's result is needed to build a later command, show the query and mark its output as a placeholder.
- Add tmux session discovery and caller validation, window creation, and detached session creation when the caller leaves the instance empty for autostart. Verify exact argument boundaries and any tmux-specific parsing with a disposable server. Refuse remote requests.
- Add Herdr TUI discovery, caller validation, enabled-machine inventory, and workspace or tab creation. Keep program delivery in `launch_env` and validate the returned root pane. Treat a workspace id as belonging to the caller's local session.
- Add Herdr Core lock/socket discovery, per-instance machine inventory, and terminal creation. Test current against the marker's socket without invoking `hc`. Carry variables with `env`, and pass a remote-home directory to a fixed shell wrapper. Derive tab placement from the caller's `herdr.space` label where applicable. Apply the focus behavior supported by the V11 result.
- Extend the adapter contract specs using command stubs. Cover support flags, live and stale instance markers, inventories, placements, autostart, failure results, and exact argv with whitespace, quotes, dollar signs, and semicolons. Compare quoted dry runs against golden commands and assert that none of the stub CLIs ran. Record the adapter API in `docs/MUX-ADAPTERS.md` and its coverage in `tests/README.md`.

## 3. Live verification and handoff

- Preview the launch commands, then verify them in disposable tmux, Herdr TUI, and Herdr Core instances. Exercise local and supported remote launches on sol and macOS where the corresponding host is available.
- Run V7, the Herdr TUI half of V8, and V11. Use an isolated headless server for checks that permit one. Coordinate the visible app check with the operator. Record observed results and any unavailable prerequisites in LAUNCH-SPEC § 4.6. Update § 5.4 if results require a fallback.
- Run `tests/check`, the install end-to-end check, and the macOS and Ubuntu CI jobs for the shared commit. Review the diff for scope and correctness, open the DEV-79 pull request, and report any outstanding live checks at handoff.
