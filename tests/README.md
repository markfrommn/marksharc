# Tests

ShellSpec owns test cases and assertions. Every example runs in its own
temporary HOME, with XDG directories, a ZDOTDIR, executable stubs first on
PATH, and an operation log. Tests never install their runner, touch the real
HOME, or call real services.

## Run

```sh
tests/check                                   # everything CI runs
tests/lint                                    # zsh -n, shellcheck, fish syntax and indentation
tests/run-tests --shell zsh spec/zsh          # zsh units
tests/run-tests --shell sh spec/contract      # cross-shell startup contract
tests/run-tests --shell sh spec/install       # install.sh, uninstall and the end-to-end install
tests/e2e/install-e2e.sh <checkout>           # install into a fresh HOME and start shells
tests/run-tests --shell sh spec/repo          # runner, lint and repository checks
tests/run-fish-units                          # fishtape units: modules/*/tests/*_test.fish, tests/fish/
SHELLSPEC_BIN=/path/to/shellspec tests/run-tests --shell zsh spec/zsh
```

`run-tests` requires the ShellSpec version in [`shellspec.pin`](shellspec.pin)
(0.28.1). Install it yourself, from Homebrew or a checkout of the pinned
commit, then put it on PATH or set `SHELLSPEC_BIN`. The wrapper finds the
runner before it replaces HOME, then starts it with an explicit environment:
`PATH`, a throwaway `HOME` and XDG directories, `MARKSHARC_ROOT` (this
checkout), `REAL_GIT`, `REAL_FISH`, `PYTHON` and `TERM=dumb`. Fixtures create
a private launcher for the selected fish executable so it remains available
after PATH is restricted.

`run-fish-units` requires fishtape at the version in [`fishtape.pin`](fishtape.pin)
(3.0.1). Check out the pinned commit and set `FISHTAPE_FUNC` to its
`functions/fishtape.fish`. The wrapper starts fish with `PATH`, a throwaway `HOME`
and XDG directories, `TMPDIR`, `MARKSHARC_ROOT`, `REAL_GIT` and `TERM=dumb`.
fishtape runs each test file in its own fish process. Files source
`fish/support/helpers.fish` (`ms_fixture`, `ms_stub`, `ms_module`, `ms_cleanup`)
for a private HOME, stubs first on PATH, and loud stubs for network and service commands.

## Layout

| Path | Contents |
| --- | --- |
| `run-tests` | Runner wrapper: pinned-version check, scrubbed environment, throwaway HOME |
| `lint` | Static checks for every tracked or new shell file |
| `check` | Lint plus both suites, as CI runs them |
| `shellspec.pin` | ShellSpec version, commit and source used locally and in CI |
| `run-fish-units`, `fishtape.pin` | fishtape runner wrapper and its pin |
| `fish/`, `fish/support/helpers.fish` | Core fish units and the shared fish fixture |
| `spec/spec_helper.sh`, `spec/support/fixtures.sh` | Per-example sandbox and shared helpers (`stub_command`, `git_fixture`, `run_bounded`, `file_mode`) |
| `support/function-safe-check.py` | Static check that file-scope declarations in sourced zsh files say `-g`; run by `spec/zsh/function_safe_spec.sh` |
| `support/pty_socket.py` | OS fixture support only: a PTY child supervisor and a Unix socket binder |
| `e2e/install-e2e.sh` | Reusable end-to-end check: install a checkout into a fresh HOME, start login and interactive zsh shells, uninstall; needs only sh, zsh and git (python3 adds a terminal step); also run by CI on macOS and Ubuntu |
| `spec/zsh/` | Specs run with `--shell zsh` |
| `spec/install/` | Specs run with `--shell sh`: `install.sh`, `marksharc uninstall`, the end-to-end script and lint coverage, in a temporary HOME with local bare repositories |
| `spec/contract/` | Contract suite run with `--shell sh`: launches the zsh and Bash cores and checks quiet startup, environment availability, cache recovery and inheritance |
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
| Core | Cached tool init: hit/miss keys, symlink resolution, missing/failing tools, unwritable cache, empty output, fixed PATH, `-x` export values | `spec/zsh/core_cache_spec.sh` |
| Core | `cs`/`li` reload: rebuild, trace, session kept, edit pickup | `spec/zsh/core_reload_spec.sh` |
| Renderer | Golden conf-to-env rendering; shell-word/hostile tokenizer cases; all guards; overlay directives and tiers; completion artifacts, render ids, stale refresh and public module conversion | `spec/zsh/render_spec.sh` |
| Bash environment | Rendered Bash syntax, PATH and export parity, late guards, manager paths, agent markers, inheritance and cache recovery | `spec/contract/bash_spec.sh` |
| Core | Modern host facts, exports, ZDOTDIR generation and read-only fallback, no repo writes, umask cache | `spec/zsh/core_env_spec.sh` |
| Core | Agent/batch quiet on the full tree; gvm selection without forks | `spec/zsh/core_agent_spec.sh` |
| Startup | Mode matrix quiet/reload; greeting opt-in; offline pinned plugin and cached completion; cached init reuse; installer failure propagation | `spec/zsh/startup_spec.sh` |
| path | Tier order goldens (macOS/Linux/modules), placement, reload, dot rule, spaces, tiers option, pending commands, env finalizers, requires-after-brew | `spec/zsh/path_spec.sh` |
| node-nvm, go-gvm, python | Manager tier ahead of brew in every class; nvm alias resolution; gvm selection and GOROOT; hooks; nvm and gvm loaded on first use, not at startup; pyenv vs uv | `spec/zsh/manager_paths_spec.sh` |
| mise | Per-tool ownership and automatic fallback; manager shims and stale-entry removal; safe exports; cached activation and hook modes; immediate refresh; compatibility translations; legacy reload restoration; Bash and fish parity | `spec/zsh/modules/mise/mise_spec.sh`, `modules/mise/tests/mise_test.fish`, `spec/contract/bash_spec.sh`, `spec/contract/fish_render_spec.sh` |
| brew, core libs | setup-homebrew variants; host-fact seams | `spec/zsh/environment_spec.sh` |
| Tool modules | brew/go/rust/bun/pnpm/lmstudio/cuda env placement; ls/pager/zsh-options/nav/zoxide/starship/direnv/greeting/completion init; editor selection (option, then emacs, then vi, no xemacs fallback); FreeBSD sourcing of the kept modules with no CLICOLOR/startx behavior | `spec/zsh/tools_spec.sh` |
| ps | Seven helpers, header kept, self-match excluded, portable flags | `spec/zsh/ps_spec.sh` |
| ps (procs) | Native fallback when procs is missing or `ps.procs` is off; ps selects and procs draws the selected PIDs; job columns; plain procs for all processes; empty selection; bare `ps` untouched; fish parity | `spec/zsh/modules/ps/ps_spec.sh`, `modules/ps/tests/ps_test.fish` |
| Line-editor plugins | Load order (fzf-tab, nav and atuin before zsh-autosuggestions, zsh-syntax-highlighting last of all); each pin sourced once in order, not on reload; silent without clones; loads with completion-fzf-tab off; atuin strategy only with atuin; strategy filtering, async and atuin widgets clearing the suggestion; highlighters | `spec/zsh/modules/zsh-syntax-highlighting/load_order_spec.sh`, `spec/zsh/modules/zsh-autosuggestions/autosuggestions_spec.sh` |
| theme | Native behaviour without vivid, bat, delta, fd or eza; cached vivid `LS_COLORS`; bat or batcat man pager; `BAT_THEME`; delta include appended to and removed from `GIT_CONFIG_COUNT`; fzf command, layout and previews, fzf-tab preview zstyles; reload removal; loads before completion; fish parity | `spec/zsh/modules/theme/theme_spec.sh`, `modules/theme/tests/theme_test.fish` |
| prompt-starship | Config option: bundled preset or file exported as `STARSHIP_CONFIG`, unknown ignored, only its own value removed; the rich preset; fish parity | `spec/zsh/modules/prompt-starship/starship_spec.sh`, `modules/prompt-starship/tests/prompt-starship_test.fish` |
| OMZ keepers | No OMZ references; no cloud startup; plugin loader kinds, pins, update, no-eval; nav widgets; coloured man; command-not-found | `spec/zsh/omz_removal_spec.sh` |
| history-atuin, history-native | Wrapper over atuin, policy, native fallback, no stray history files | `spec/zsh/history_spec.sh` |
| Overlay | Private module root, host config, env-id invalidation, reload paths, function ownership, post hook, option restore | `spec/zsh/overlay_spec.sh` |
| Modules | Bands, double-source idempotency, layout, interactive load | `spec/zsh/modules_spec.sh` |
| Modules | module.conf contract; module tests linkage (every module `tests/` directory is linked from `spec/zsh/modules/<name>`) | `spec/zsh/module_specs_spec.sh` |
| agent | Agent marker option declared by the module, core classification reads it | `spec/zsh/modules/agent/agent_spec.sh` |
| ssh-agent | Cache in the state dir, one-time migration from the legacy path, insecure source/state parents refused, probing, parsing, cleanup | `spec/zsh/modules/ssh-agent/agents_spec.sh` |
| x11 | Inherited DISPLAY remembered as DISPLAY_ORIG, empty DISPLAY dropped, no sleep, no network probes | `spec/zsh/modules/x11/x11_spec.sh` |
| docker | claude-yolo only in docker with SANDCAT; cleanup-docker kills and removes through docker only | `spec/zsh/modules/docker/docker_spec.sh` |
| mux | Adapter contracts, nested title updates, tmux reattach and bounded forwarding recovery | `spec/zsh/modules/mux/`, `modules/mux/tests/mux_test.fish` |
| titles | set-title/chdir-set-title escape and skip behavior | `spec/zsh/modules/titles/titles_spec.sh` |
| herdr | Session shims from herdr session list, collie detection, render-time completion generation and generator-failure atomicity | `spec/zsh/modules/herdr/herdr_spec.sh`, `spec/zsh/modules/cc-providers/shims_spec.sh` |
| wezterm | install-wezterm-terminfo failure propagation | `spec/zsh/modules/wezterm/wezterm_spec.sh` |
| cc-providers | Data-only provider files, secret-free executable shims, bash invocation and private cache | `spec/zsh/modules/cc-providers/shims_spec.sh` |
| git-worktree | gwt-clean preflight, squash/merge detection, pre-remove hook point; repo-sync roots/orgs options | `spec/zsh/modules/git-worktree/cleanup_spec.sh`, `spec/zsh/modules/git-worktree/repo_sync_spec.sh` |
| cwf | cwf-new executable creation checks, unmanaged copies, executable post-create hooks and copy-exclude; render generates zsh integration without evaluating it, interactive init sources the cache, reload does not regenerate, batch/agent stays quiet | `spec/zsh/modules/cwf/cwf_spec.sh` |
| Commands | Encoded caller-state directives, hostile values, state wrappers and private staged shims | `spec/zsh/directives_spec.sh`, `spec/zsh/render_spec.sh` |
| fish-bridge | run-fish curated environment | `spec/zsh/modules/fish-bridge/fish_bridge_spec.sh` |
| cloud | install-krew failure propagation and artifact cleanup | `spec/zsh/modules/cloud/cloud_spec.sh` |
| System modules | Real-tree wiring (functions, hooks, options via synthesized overlay), env/init load order, quiet agent/batch/PTY startup | `spec/zsh/system_modules_spec.sh` |
| Installer | Fresh install from a checkout: stub, template overlay, manifest, first declarative render; paths with spaces, quotes and dollars survive; non-default MARKSHARC_CONFIG named in the stub | `spec/install/installer_spec.sh` |
| Installer | Existing zsh dotfiles (regular files, symlinks, a foreign `~/.zshenv`) backed up privately and recorded; idempotent re-run keeps the original backup | `spec/install/installer_spec.sh` |
| Bash installer | Fresh and upgraded installs preserve regular and symlinked startup files, edited stubs and interrupted retries | `spec/install/installer_spec.sh`, `spec/install/rerun_spec.sh`, `spec/install/uninstall_spec.sh` |
| Installer | `--dry-run` prints every action and writes nothing; framework from `--home`, own checkout or a clone (reused, never pulled); `--overlay` path, URL, conflict and existing overlay; zsh, git and zsh version checked before any write; chsh hint only; runs under dash | `spec/install/installer_spec.sh` |
| Installer | A re-run that finds recorded backups but no stub of ours stops before any write (deleted or replaced stub), naming the backup; a hand-edited stub is copied to the state dir before it is rewritten (and next to the restored file on uninstall); MARKSHARC_CONFIG judged against ~/.config with XDG defaults, unset or non-default, and warnings for the other XDG variables; trailing slashes stripped; a checkout's bin/marksharc acts on its own framework | `spec/install/rerun_spec.sh` |
| Installer | Plugin pins cloned into the cache at the pinned commit; `--no-plugins` skips and names `marksharc update`; dry run only reports; an unreachable pin warns and the install completes | `spec/install/plugins_spec.sh` |
| Uninstall | Restores files and symlinks, removes stub and ZDOTDIR, keeps framework, overlay and cache; conflicts and missing backups fail before any change; `--purge` confirmation, scope and guards | `spec/install/uninstall_spec.sh` |
| Install e2e | Two passes, offline with `--no-plugins` (`--home` from a checkout; piped installer cloning via MARKSHARC_REPO from a non-checkout directory, ending in `uninstall --purge --yes`): login and interactive shells quiet with MARKSHARC_SESSION set and the command on PATH, uninstall; lint covers the installer and CLI files | `spec/install/e2e_spec.sh`, `e2e/install-e2e.sh` |
| Stub fallback | Missing, unreadable, failing or unparsable core: minimal PATH, exactly one stderr line, clean stdout, batch, login, agent and PTY | `spec/zsh/fallback_spec.sh` |
| CLI | usage, unknown commands, version (VERSION plus git describe), reload explanation, module list statuses, enable/disable edits (template lines, explicit lists, host override, symlinked config.conf, refusals) | `spec/zsh/core_cli_spec.sh` |
| Sync | Local bare remotes, deleted upstreams, configured upstream and host-overridden extra repos, linked overlay owner and deduplication, dirty/ahead/diverged/offline and failed status checks, plugin pins, cache invalidation and minimal update | `spec/zsh/sync_spec.sh` |
| Push sync & updates | `update -y` (never passed to `brew upgrade`, passed to `mise` and system updates) and `--system` (macOS no-op, Linux `apt`/`dnf`/`yum`); `sync --auto` (quiet, flock lock, state log, dirty-tree skip), `sync --update`, `sync timer on\|off\|status` launchd/systemd golden units; `hosts.conf` inventory and `gum`/`fzf` populate from `.ssh/config` and `hc machine ls --json`; `push` parallel SSH fan-out, regex host selection, per-host timeout and result table | `spec/zsh/push_sync_spec.sh` |
| Day 0 and Day 2 | Package rendering, safe bundle input, update selection, failure continuation, ordering and installer registry | `spec/zsh/day2_spec.sh` |
| Notify | Local fetch without merge, deleted upstreams and host overrides, later PTY notice and sync, failed-check throttle, concurrent workers, killed-lock-holder and stale-result recovery, batch and agent exclusion | `spec/zsh/notify_spec.sh` |
| Doctor | Stub checksums and generated stubs, broken links, missing commands only for modules named in the overlay, plugin pins with the update hint, dirty repos and host overrides, foreign lines, duplicate PATH, environment ID, and PTY startup budget and timeout with notify suppressed | `spec/zsh/doctor_spec.sh` |
| Core | `marksharc` function: quiet and verbose reload in the current shell, delegation, absent in batch and agent; bin/ on PATH in every class | `spec/zsh/core_cli_spec.sh` |
| Overlay template | No active module line, one commented off line per public module, real option examples, silent post hook | `spec/zsh/template_overlay_spec.sh` |
| Function-safe modules | File-scope declarations in module env/init files, core files and overlay hooks say -g (`tests/support/function-safe-check.py`; fixture covers function, anonymous-function, `function name()`, here-string, case-arm and `builtin`/`command` forms); the env phase ends with `true`; `marksharc reload` and `cs` leave the same globals, PS1 and history settings, and after markers are planted in module scratch variables (and PS1 exported) no reload path leaves a marker or an exported PS1 (this spec fails against the pre-`-g` modules) | `spec/zsh/function_safe_spec.sh` |
| Hygiene | Personal-value lint over the portable tree | `spec/zsh/personal_values_spec.sh` |
| Contract | Quiet batch/agent startup, same environment in every zsh mode, idempotent re-source, writes confined to cache/state | `spec/contract/zsh_spec.sh` |
| Fish contract | Shared environment and PATH, session classification, inherited render ID, reload (including unloading a disabled module's functions), native modules and plugin loading, safe caller-state directives | `spec/contract/fish_render_spec.sh`, `spec/contract/fish_plugin_spec.sh`, `spec/contract/fish_directives_spec.sh` |
| Fish units | Init cache (hit, miss, key change, empty, failing and missing tool, -P, -x), `marksharc` completion | `fish/cache_test.fish`, `fish/completions_test.fish` |
| Fish modules | Native fish behaviour per module: nav, ps, titles, mux, x11, docker, greeting, command-not-found, node-nvm, go-gvm, python, mise, brew, pager, editor, history-atuin, history-native, prompt-starship, zoxide, direnv, cwf, herdr, ssh-agent, git-worktree | `modules/<name>/tests/<name>_test.fish` (run by `run-fish-units`) |
| Doctor (fish) | Unchanged, modified, missing and symlinked fish stub; foreign `config.fish` lines; fisher leftovers | `spec/zsh/doctor_spec.sh` |
| Fish runner | Pinned-version check, scrubbed environment, default discovery, workspace removal | `spec/repo/fish_runner_spec.sh` |
