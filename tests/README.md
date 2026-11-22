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
tests/run-tests --shell sh spec/install       # install.sh, uninstall and the end-to-end install
tests/e2e/install-e2e.sh <checkout>           # install into a fresh HOME and start shells
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
| `support/function-safe-check.py` | Static check that file-scope declarations in sourced zsh files say `-g`; run by `spec/zsh/function_safe_spec.sh` |
| `support/pty_socket.py` | OS fixture support only: a PTY child supervisor and a Unix socket binder |
| `e2e/install-e2e.sh` | Reusable end-to-end check: install a checkout into a fresh HOME, start login and interactive zsh shells, uninstall; needs only sh, zsh and git (python3 adds a terminal step); also run by CI on macOS and Ubuntu |
| `spec/zsh/` | Specs run with `--shell zsh` |
| `spec/install/` | Specs run with `--shell sh`: `install.sh`, `marksharc uninstall`, the end-to-end script and lint coverage, in a temporary HOME with local bare repositories |
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
| Modules | module.conf contract; module tests linkage (every module `tests/` directory is linked from `spec/zsh/modules/<name>`) | `spec/zsh/module_specs_spec.sh` |
| agent | Agent marker option declared by the module, core classification reads it | `spec/zsh/modules/agent/agent_spec.sh` |
| ssh-agent | Cache in the state dir, one-time migration from the legacy path, insecure source/state parents refused, probing, parsing, cleanup | `spec/zsh/modules/ssh-agent/agents_spec.sh` |
| x11 | Inherited DISPLAY remembered as DISPLAY_ORIG, empty DISPLAY dropped, no sleep, no network probes | `spec/zsh/modules/x11/x11_spec.sh` |
| docker | claude-yolo only in docker with SANDCAT; cleanup-docker kills and removes through docker only | `spec/zsh/modules/docker/docker_spec.sh` |
| mux | fix-tmux re-imports the tmux client environment (ssh-agent fix) | `spec/zsh/modules/mux/mux_spec.sh` |
| titles | set-title/chdir-set-title escape and skip behavior | `spec/zsh/modules/titles/titles_spec.sh` |
| herdr | Session wrappers from herdr session list, collie detection, cached completion | `spec/zsh/modules/herdr/herdr_spec.sh` |
| wezterm | install-wezterm-terminfo failure propagation | `spec/zsh/modules/wezterm/wezterm_spec.sh` |
| cc-providers | Provider files linked from the option/overlay directory | `spec/zsh/modules/cc-providers/providers_spec.sh` |
| git-worktree | gwt-clean preflight, squash/merge detection, pre-remove hook point; repo-sync roots/orgs options | `spec/zsh/modules/git-worktree/cleanup_spec.sh`, `spec/zsh/modules/git-worktree/repo_sync_spec.sh` |
| cwf | cwf-new creation checks, unmanaged copies, post-create hook point and copy-exclude, codegraph reindex gate; init sources cwf shell zsh once per shell | `spec/zsh/modules/cwf/cwf_spec.sh` |
| fish-bridge | run-fish curated environment | `spec/zsh/modules/fish-bridge/fish_bridge_spec.sh` |
| cloud | install-krew failure propagation and artifact cleanup | `spec/zsh/modules/cloud/cloud_spec.sh` |
| System modules | Real-tree wiring (functions, hooks, options via synthesized overlay), env/init load order, quiet agent/batch/PTY startup | `spec/zsh/system_modules_spec.sh` |
| Installer | Fresh install from a checkout: stub, template overlay, manifest; paths with spaces, quotes and dollars survive; non-default MARKSHARC_CONFIG named in the stub | `spec/install/installer_spec.sh` |
| Installer | Existing zsh dotfiles (regular files, symlinks, a foreign `~/.zshenv`) backed up privately and recorded; idempotent re-run keeps the original backup | `spec/install/installer_spec.sh` |
| Installer | `--dry-run` prints every action and writes nothing; framework from `--home`, own checkout or a clone (reused, never pulled); `--overlay` path, URL, conflict and existing overlay; zsh, git and zsh version checked before any write; chsh hint only; runs under dash | `spec/install/installer_spec.sh` |
| Installer | A re-run that finds recorded backups but no stub of ours stops before any write (deleted or replaced stub), naming the backup; a hand-edited stub is copied to the state dir before it is rewritten (and next to the restored file on uninstall); MARKSHARC_CONFIG judged against ~/.config with XDG defaults, unset or non-default, and warnings for the other XDG variables; trailing slashes stripped; a checkout's bin/marksharc acts on its own framework | `spec/install/rerun_spec.sh` |
| Uninstall | Restores files and symlinks, removes stub and ZDOTDIR, keeps framework, overlay and cache; conflicts and missing backups fail before any change; `--purge` confirmation, scope and guards | `spec/install/uninstall_spec.sh` |
| Install e2e | Two passes (`--home` from a checkout; piped installer cloning via MARKSHARC_REPO from a non-checkout directory, ending in `uninstall --purge --yes`): login and interactive shells quiet with MARKSHARC_SESSION set and the command on PATH, uninstall; lint covers the installer and CLI files | `spec/install/e2e_spec.sh`, `e2e/install-e2e.sh` |
| Stub fallback | Missing, unreadable, failing or unparsable core: minimal PATH, exactly one stderr line, clean stdout, batch, login, agent and PTY | `spec/zsh/fallback_spec.sh` |
| CLI | usage, unknown commands, version (VERSION plus git describe), reload explanation, module list statuses, enable/disable edits (template lines, explicit lists, host override, symlinked config.conf, refusals) | `spec/zsh/core_cli_spec.sh` |
| Core | `marksharc` function: quiet and verbose reload in the current shell, delegation, absent in batch and agent; bin/ on PATH in every class | `spec/zsh/core_cli_spec.sh` |
| Overlay template | No active module line, one commented off line per public module, real option examples, silent post hook | `spec/zsh/template_overlay_spec.sh` |
| Function-safe modules | File-scope declarations in module env/init files, core files and overlay hooks say -g (`tests/support/function-safe-check.py`); the env phase ends with `true`; `marksharc reload` and `cs` leave the same globals, PS1 and history settings | `spec/zsh/function_safe_spec.sh` |
| Hygiene | Personal-value lint over the portable tree | `spec/zsh/personal_values_spec.sh` |
| Contract | Quiet batch/agent startup, same environment in every zsh mode, idempotent re-source, writes confined to cache/state | `spec/contract/zsh_spec.sh` |
