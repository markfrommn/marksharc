# DEV-56 — Push sync, update enhancements, poll-pull timer and ssh fan-out

> **For agentic workers:** Implement task by task with specs covering every behaviour change. Keep tests hermetic with temporary HOME, XDG dirs, and command stubs only.

**Goal:** Let a change reach other hosts without logging in to each one, and add `-y` / `--system` / `--update` options across `update`, `sync`, and `push`.

**Authority:** `specs/MARKSHARC-SPEC.md` §§ 4.2, 6.1, 6.3, 6.5, 6.14, 6.15, 8, 10; `specs/MARKSHARC-PLAN.md` P3.8.

## Global constraints

- macOS and Linux are both first-class; unit file generation and `--system` support both platforms (and tests verify both via `MARKSHARC_OS` seams).
- Every CLI command requires only zsh and standard POSIX tools; no TOML/YAML/JSON parser dependency is required on a host.
- Portable code (`core/`, `modules/`, `templates/`) contains no personal values.
- Data stays data: no `eval` of host names, paths, SSH config values, or `hc` JSON output; reject SSH targets beginning with `-` to prevent option injection.
- Unattended sync (`sync --auto` and `sync timer`) never runs package upgrades or `sudo`: `--update`, `--system`, and `-y` are explicitly rejected for `--auto` and `timer`.
- Tests use temporary HOME, XDG dirs, disposable bare repositories, and command stubs only.

## Decisions

1. **`marksharc update` `-y` / `--yes` and `--system`:**
   - Accept `-y` / `--yes` and `--system`.
   - `brew update` and `brew upgrade` in `modules/brew/module.conf` never receive `-y` (`brew upgrade` has no `-y` flag; confirm no default `-y` exists).
   - Commands known to support `-y` receive `-y` when `-y`/`--yes` is set (and not already present in args): `mise upgrade`, `apt`/`apt-get` (`upgrade`, `dist-upgrade`, `full-upgrade`, `install`, `autoremove`), `dnf`/`yum` (`upgrade`, `update`, `install`, `autoremove`). Export `MARKSHARC_YES=1` (else `0`) so custom `./` overlay scripts can also opt in.
   - `--system` (or `--only system`) adds a `system` step that runs via `sudo`:
     - macOS (`MARKSHARC_OS=darwin`): no-op (`system: ok (no-op on macOS)` / dry-run reports no-op).
     - Linux (`MARKSHARC_OS=linux`): probe `apt`, then `dnf`, then `yum` (checking `dnf` before `yum` because RHEL/Fedora symlink `yum` to `dnf`):
       - `apt`: `sudo apt update` followed by `sudo apt upgrade` (`-y` appended to `upgrade` when `-y` is set); do not run `upgrade` if `update` fails.
       - `dnf`: `sudo dnf upgrade --refresh` (`-y` appended when `-y` is set). Note: corrected from `dnf refresh --upgrade` in the issue text because DNF's real subcommand is `upgrade` with the `--refresh` flag (design rule 14).
       - `yum`: `sudo yum update` followed by `sudo yum upgrade` (`-y` appended to both when `-y` is set); do not run `upgrade` if `update` fails.
       - None available: `system: skipped (no supported system package manager)`.
2. **`marksharc sync` enhancements:**
   - `--auto`: quiet (no stdout/stderr during normal execution), non-blocking `zsystem flock` lock at `${XDG_STATE_HOME:-~/.local/state}/marksharc/sync/auto.lock`, timestamped log at `${XDG_STATE_HOME:-~/.local/state}/marksharc/sync/auto.log`, non-interactive git/ssh askpass environment, skips dirty trees without marking the run failed, refreshes plugin pins and runs `render` (skips interactive PTY `doctor`). Rejects `--update`, `--system`, and `-y`.
   - `--update [--system] [-y|--yes]`: delegates to `core/cli/update` passing `--system` and `-y` through; rejects `--system` and `-y` when `--update` is absent.
   - `sync timer on|off|status`:
     - Explicitly rejects `--update`, `--system`, `-y`, `--yes`, and `--auto`.
     - Interval defaults to `sync.timer_minutes` (default `60` minutes; must be a positive integer).
     - macOS: writes `~/Library/LaunchAgents/com.marksharc.sync.plist` (XML-escaped) invoking `bin/marksharc sync --auto` and loads/unloads via `launchctl bootstrap` / `bootout` on `gui/$(id -u)`.
     - Linux: writes `${XDG_CONFIG_HOME:-~/.config}/systemd/user/marksharc-sync.service` and `marksharc-sync.timer` invoking `bin/marksharc sync --auto` and enables/disables via `systemctl --user`.
3. **Overlay `hosts.conf` inventory and picker (`marksharc hosts`):**
   - `$MARKSHARC_CONFIG/hosts.conf` uses the line-directive format (`#` comments, `host <name> [<ssh-target>]`; single-token bare host names also accepted on read). Names and targets starting with `-` or containing control characters are rejected.
   - `templates/overlay/hosts.conf` ships a commented skeleton (no active hosts, no personal values).
   - `marksharc hosts [list|populate|add|remove]`:
     - `populate [--all] [--source ssh|hc]` discovers hosts from `~/.ssh/config` (including `Include` files, skipping wildcards/negations) and `hc machine ls --json` (real `hc` subcommand; parses JSON in pure zsh with no external parser dependency, skipping `via: true` and `temporary: true` machines).
     - Interactive selection prefers `gum choose --no-limit` and falls back to `fzf --multi`; `--all` selects all discovered hosts non-interactively. Appends only newly selected hosts to `hosts.conf`, preserving existing entries and comments.
4. **`marksharc push [options] [host-or-regex...]`:**
   - Options: `--update`, `--system` (implies `--update`), `-y`/`--yes` (requires `--update`/`--system`), `--timeout <seconds>` (default `sync.push_timeout` or `60`, `300` with `--update`), `--max-parallel <n>` (default `sync.push_parallel` or `8`), `--dry-run`, `--verbose`/`-v`, `--populate`.
   - With no host arguments, targets every host in `hosts.conf` except the current host (`MARKSHARC_HOST`).
   - With host arguments, each argument matches `hosts.conf` names by exact match or POSIX ERE regex (`[[ $name =~ $pat ]]`); invalid regexes fail with exit 2. A literal argument without regex metacharacters that matches no `hosts.conf` entry is accepted as an ad-hoc SSH target; a regex matching zero hosts fails with exit 1.
   - Runs `ssh -o BatchMode=yes -o ConnectTimeout=<n> -n -- <target> marksharc sync [--update] [--system] [-y]` in parallel (shell-agnostic remote command that works whether the remote login shell is zsh, bash, or fish) with portable parent-supervised per-host timeout (`zsh/datetime` + `zsh/zselect`).
   - Prints an aligned per-host result table (`HOST`, `STATUS`, `DURATION`, `DETAIL`) in target order and exits 0 only if every host succeeded.

## Tasks

### Task 1: `marksharc update` (`-y`, `--system`) and `marksharc sync` (`--auto`, `--update`, `timer`)
- [x] Update `core/cli/day2-lib.zsh` to preserve a pre-set `MARKSHARC_OS` seam for cross-platform tests.
- [x] Update `core/cli/update` with `-y`/`--yes` and `--system` (macOS no-op, Linux `apt`/`dnf`/`yum` via `sudo`, `--list`/`--dry-run`/`--only system`).
- [x] Update `core/cli/sync` with `--auto`, `--update [--system] [-y]`, and `timer on|off|status` (launchd plist and systemd user service/timer).

### Task 2: `hosts.conf`, `marksharc hosts`, and `marksharc push`
- [x] Add `templates/overlay/hosts.conf` and document it in `templates/overlay/README.md`.
- [x] Add `core/cli/hosts-lib.zsh`, `core/cli/hosts`, and `core/cli/push`.
- [x] Update `bin/marksharc` usage and `core/fish/completions/marksharc.fish`.

### Task 3: Specs, golden fixtures, and documentation
- [x] Add golden fixtures under `tests/fixtures/sync/` for launchd plist and systemd service/timer units.
- [x] Add ShellSpec suites for `update` (`-y`, `--system`), `sync` (`--auto` lock/log/dirty-skip, `--update`, `timer` golden tests), `hosts` (`.ssh/config`, `hc machine ls --json`, `gum`/`fzf`/`--all`), and `push` (stub `ssh`, parallel fan-out, timeout, regex matching, `--update`/`--system`/`-y`, result table).
- [x] Update `tests/fish/completions_test.fish`, `tests/spec/zsh/template_overlay_spec.sh`, `tests/README.md`, `README.md`, `CHANGELOG.md`, and `specs/MARKSHARC-PLAN.md` outcome.

### Task 4: Verification and review
- [x] Run `tests/check` and `tests/e2e/install-e2e.sh`.
- [x] Run local CodeRabbit review (`local-review-coderabbit`) and self-review.
- [x] Commit and open PR.

## Outcome

Implemented all DEV-56 scope items with full local verification:
- `tests/lint`: ok (207 files).
- `spec/zsh`: 515 examples, 0 failures, 1 platform skip (Apple Terminal).
- `spec/contract`: 68 examples, 0 failures.
- `spec/install`: 65 examples, 0 failures.
- `spec/repo`: 35 examples, 0 failures.
- `tests/run-fish-units`: 625/625 assertions passed.
- `tests/e2e/install-e2e.sh .`: `e2e: ok` (checkout, clone, legacy).
- Local CodeRabbit review: `provider_result: skipped:wrong-organization` (authenticated org is `convoyai`; expected `markfrommn`). Self-review caught and fixed zsh loop-scoped `local` re-declarations in `core/cli/push` and `core/cli/hosts-lib.zsh` that could print variable values to stdout on multi-pattern invocations.
- Live Mac-to-sol timer delivery and SSH push runs remain manual acceptance steps after merge.
