# Tests

ShellSpec owns test cases and assertions. Every example runs in its own
temporary HOME, with XDG directories, a ZDOTDIR, executable stubs first on
PATH, and an operation log. Tests never install their runner, touch the real
HOME, or call real services.

## Run

```sh
tests/check                                   # everything CI runs
tests/lint                                    # zsh -n, shellcheck, fish --no-execute
tests/run-tests --shell zsh spec/zsh          # zsh units
tests/run-tests --shell sh spec/contract      # cross-shell startup contract
tests/run-tests --shell sh spec/repo          # runner, lint and repository checks
SHELLSPEC_BIN=/path/to/shellspec tests/run-tests --shell zsh spec/zsh
```

`run-tests` requires the ShellSpec version in [`shellspec.pin`](shellspec.pin)
(0.28.1). Install it yourself, from Homebrew or a checkout of the pinned
commit, then put it on PATH or set `SHELLSPEC_BIN`. The wrapper finds the
runner before it replaces HOME, then starts it with an explicit environment:
`PATH`, a throwaway `HOME` and XDG directories, `MARKSHARC_ROOT` (this
checkout), `REAL_GIT`, `PYTHON` and `TERM=dumb`.

## Layout

| Path | Contents |
| --- | --- |
| `run-tests` | Runner wrapper: pinned-version check, scrubbed environment, throwaway HOME |
| `lint` | Static checks for every tracked or new shell file |
| `check` | Lint plus both suites, as CI runs them |
| `shellspec.pin` | ShellSpec version, commit and source used locally and in CI |
| `spec/spec_helper.sh`, `spec/support/fixtures.sh` | Per-example sandbox and shared helpers (`stub_command`, `git_fixture`, `run_bounded`, `file_mode`) |
| `support/pty_socket.py` | OS fixture support only: a PTY child supervisor and a Unix socket binder |
| `spec/zsh/` | Specs run with `--shell zsh` |
| `spec/contract/` | Contract suite run with `--shell sh`: launches the real zsh core (bash and fish join in their phases) and proves quiet startup, environment availability, idempotent re-source and writes confined to cache/state |
| `spec/repo/` | Specs run with `--shell sh`: the harness itself and repository rules |

## Contract inventory

Each row is a behaviour and the spec that exercises it. P2.8 (DEV-48) grows
this table to cover every module.

| Area | Behaviour | Spec |
| --- | --- | --- |
| Harness | Temporary HOME and XDG dirs; stubs first on PATH; forbidden commands fail and log | `spec/zsh/smoke_spec.sh` |
| Harness | zsh is 5.9 or later | `spec/zsh/smoke_spec.sh` |
| Harness | Native zsh arrays, options, scope and literal mock arguments | `spec/zsh/native_spec.sh` |
| Runner | Missing or wrong-version ShellSpec is refused; environment is scrubbed; throwaway HOME is removed | `spec/repo/runner_spec.sh` |
| Lint | Files routed by extension and shebang; every failure reported; missing checker named | `spec/repo/lint_spec.sh` |
| Repository | Agent configuration and cwf renders are ignored and untracked; the memory index is tracked | `spec/repo/hygiene_spec.sh` |
