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
| Core | Session classes; silent batch/agent startup; marker override; PTY interactive | `spec/zsh/core_session_spec.sh` |
| Core | Env/init phase ordering through generated ZDOTDIR; MARKSHARC_ENV inherit-skip; zprofile PATH re-assert | `spec/zsh/core_phases_spec.sh` |
| Core | Module discovery, order, requires, options, fpath, idempotency, failure containment, guard cache | `spec/zsh/core_modules_spec.sh` |
| Core | Cached tool init: hit/miss keys, symlink resolution, missing/failing tools, unwritable cache, empty output, fixed PATH | `spec/zsh/core_cache_spec.sh` |
| Core | `cs`/`li` reload: rebuild, trace, session kept, edit pickup | `spec/zsh/core_reload_spec.sh` |
| Core | Host facts, dname, exports, ZDOTDIR generation and read-only fallback, no repo writes, umask cache | `spec/zsh/core_env_spec.sh` |
| Core | Agent/batch quiet on the full tree; gvm selection without forks | `spec/zsh/core_agent_spec.sh` |
| Startup | Mode matrix quiet/reload; greeting opt-in; offline pinned plugin and cached completion; cached init reuse; installer failure propagation | `spec/zsh/startup_spec.sh` |
| path | Tier order goldens (macOS/Linux/modules), placement, reload, dot rule, spaces, tiers option, pending commands, env finalizers, requires-after-brew | `spec/zsh/path_spec.sh` |
| node-nvm, go-gvm, python | Manager tier ahead of brew in every class; nvm alias resolution; gvm selection and GOROOT; hooks; pyenv vs uv | `spec/zsh/manager_paths_spec.sh` |
| brew, core libs | setup-homebrew variants; host-fact seams | `spec/zsh/environment_spec.sh` |
| Tool modules | brew/go/rust/bun/pnpm/lmstudio/cuda env placement; ls/pager/zsh-options/nav/zoxide/starship/direnv/greeting/completion init; editor selection (option, then emacs, then vi, no xemacs fallback); FreeBSD sourcing of the kept modules with no CLICOLOR/startx behavior | `spec/zsh/tools_spec.sh` |
| ps | Seven helpers, header kept, self-match excluded, portable flags | `spec/zsh/ps_spec.sh` |
| OMZ keepers | No OMZ references; no cloud startup; plugin loader kinds, pins, update, no-eval; nav widgets; coloured man; command-not-found | `spec/zsh/omz_removal_spec.sh` |
| history-atuin, history-native | Wrapper over atuin, policy, native fallback, no stray history files | `spec/zsh/history_spec.sh` |
| Overlay | Private module root, host config, env-id invalidation, reload paths, function ownership, post hook, option restore | `spec/zsh/overlay_spec.sh` |
| Modules | Bands, double-source idempotency, layout, interactive load | `spec/zsh/modules_spec.sh` |
| Modules | module.conf contract; module tests linkage | `spec/zsh/module_specs_spec.sh` |
| Hygiene | Personal-value lint over the portable tree | `spec/zsh/personal_values_spec.sh` |
| Contract | Quiet batch/agent startup, same environment in every zsh mode, idempotent re-source, writes confined to cache/state | `spec/contract/zsh_spec.sh` |
