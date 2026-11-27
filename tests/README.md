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
tests/run-tests --shell sh spec/repo          # runner, lint, inventory, bench and repository checks
tests/run-fish-units                          # fishtape units: modules/*/tests/*_test.fish, tests/fish/
tests/bench-startup                           # advisory startup-time check (batch and PTY interactive)
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
The runner sets `MISE_FISH_AUTO_ACTIVATE=0` inside its scrubbed environment so Homebrew's
global mise startup hook cannot inject host paths into the parent or per-file children.
Fish configuration loading stays enabled because fishtape shares its assertion counters
through universal variables; `--no-config` would disable that persistence.

`bench-startup` installs the checkout offline into a throwaway HOME, verifies
batch and PTY interactive session classification, and times both modes with
`hyperfine` (falling back to Python monotonic timing when `hyperfine` is absent).
CI runs it as an advisory step on macOS and Linux.

## Layout

| Path | Contents |
| --- | --- |
| `run-tests` | Runner wrapper: pinned-version check, scrubbed environment, throwaway HOME |
| `lint` | Static checks for every tracked or new shell file |
| `check` | Lint plus all local suites, as CI runs them |
| `bench-startup` | Advisory startup-time check for batch and PTY interactive zsh startup |
| `shellspec.pin` | ShellSpec version, commit and source used locally and in CI |
| `run-fish-units`, `fishtape.pin` | fishtape runner wrapper and its pin |
| `fish/`, `fish/support/helpers.fish` | Core fish units and the shared fish fixture |
| `spec/spec_helper.sh`, `spec/support/fixtures.sh` | Per-example sandbox and shared helpers (`stub_command`, `git_fixture`, `run_bounded`, `file_mode`) |
| `support/check-inventory.py` | Verifies every listed spec file in the contract inventory exists, every public module is listed, and coverage is at least 90%; run by `spec/repo/inventory_spec.sh` |
| `support/function-safe-check.py` | Static check that file-scope declarations in sourced zsh files say `-g`; run by `spec/zsh/function_safe_spec.sh` |
| `support/pty_socket.py` | OS fixture support only: a PTY child supervisor and a Unix socket binder |
| `e2e/install-e2e.sh` | Reusable end-to-end check: install a checkout into a fresh HOME, start login and interactive shells, uninstall; needs only sh, zsh, bash and git (fish and python3 add shell and terminal steps); also run by CI on macOS and Ubuntu |
| `e2e/bash-live.py` | Real-tool interactive Bash PTY smoke and startup timing check run in CI |
| `spec/zsh/` | Specs run with `--shell zsh` |
| `spec/install/` | Specs run with `--shell sh`: `install.sh`, `marksharc uninstall`, the end-to-end script and lint coverage, in a temporary HOME with local bare repositories |
| `spec/contract/` | Contract suite run with `--shell sh`: launches the zsh, Fish and Bash cores and checks quiet startup, environment availability, cache recovery, inheritance and interactive parity |
| `spec/repo/` | Specs run with `--shell sh`: the harness, lint, inventory, startup benchmark and repository hygiene rules |

## Contract inventory

Each row maps a module or framework area to its contract behaviour and the spec
files that exercise it. `spec/repo/inventory_spec.sh` runs
`support/check-inventory.py` in CI to verify that every listed spec file exists,
every public module under `modules/` is listed, and at least 90% of listed
behaviours are covered.

| Area | Behaviour | Spec |
| --- | --- | --- |
| Harness | Temporary HOME and XDG dirs; stubs first on PATH; forbidden commands fail and log | `spec/zsh/smoke_spec.sh` |
| Harness | zsh is 5.9 or later | `spec/zsh/smoke_spec.sh` |
| Harness | Native zsh arrays, options, scope and literal mock arguments | `spec/zsh/native_spec.sh` |
| Harness | PTY supervisor drains output while delivering input larger than the terminal queue | `spec/repo/pty_fixture_spec.sh` |
| Runner | Missing or wrong-version ShellSpec is refused; environment is scrubbed; throwaway HOME is removed | `spec/repo/runner_spec.sh` |
| Lint | Files routed by extension and shebang; every failure reported; missing checker named | `spec/repo/lint_spec.sh` |
| Inventory | Every listed spec file exists, every public module is listed, and coverage meets the 90% floor | `spec/repo/inventory_spec.sh` |
| Startup benchmark | Advisory startup-time check measures batch and PTY interactive startup in a throwaway HOME with hyperfine or Python fallback | `spec/repo/bench_spec.sh` |
| Repository | Agent configuration and cwf renders are ignored and untracked; the memory index is tracked | `spec/repo/hygiene_spec.sh` |
| Core | Session classes; silent batch/agent startup; marker override; PTY interactive | `spec/zsh/core_session_spec.sh` |
| Core | Env/init phase ordering through generated ZDOTDIR; MARKSHARC_ENV inherit-skip; zprofile PATH re-assert | `spec/zsh/core_phases_spec.sh` |
| Core | Module discovery, order, requires, options, fpath, idempotency, failure containment, guard cache | `spec/zsh/core_modules_spec.sh` |
| Core | Cached tool init: hit/miss keys, symlink resolution, missing/failing tools, unwritable cache, empty output, fixed PATH, `-x` export values | `spec/zsh/core_cache_spec.sh` |
| Core | `cs`/`li` reload: rebuild, trace, session kept, edit pickup | `spec/zsh/core_reload_spec.sh` |
| Core | Modern host facts (macOS and Linux `/etc/os-release` / `redhat-release`), exports, ZDOTDIR generation and read-only fallback, no repo writes, umask cache | `spec/zsh/core_env_spec.sh`, `spec/zsh/environment_spec.sh` |
| Core | Agent/batch quiet on the full tree; gvm selection without forks | `spec/zsh/core_agent_spec.sh` |
| Core | `marksharc` function: quiet and verbose reload in the current shell, delegation, absent in batch and agent; `bin/` on PATH in every class | `spec/zsh/core_cli_spec.sh` |
| Startup | Mode matrix quiet/reload; greeting opt-in; offline pinned plugin and cached completion; cached init reuse; installer failure propagation | `spec/zsh/startup_spec.sh` |
| Renderer | Golden conf-to-env rendering; shell-word/hostile tokenizer cases; all guards; overlay directives and tiers; completion artifacts, render ids, stale refresh and public module conversion | `spec/zsh/render_spec.sh` |
| Bash environment | Rendered Bash syntax, PATH and export parity, late guards, manager paths, agent markers, inheritance and cache recovery | `spec/contract/bash_spec.sh` |
| Bash runtime | Interactive Bash session gating (4.4+ vs 3.2 env-only), init cache, caller-state directives, and reload ownership | `spec/contract/bash_interactive_spec.sh`, `spec/contract/bash_cache_spec.sh`, `spec/contract/bash_directives_spec.sh` |
| Bash tool integrations | Cached prompt, navigation and environment hooks, Atuin recording and bindings, native history fallback and lazy version-manager selection | `spec/contract/bash_tools_spec.sh`, `spec/contract/bash_hooks_spec.sh` |
| Bash native modules | Directory history, Readline keys and prompt refresh, native stack, tools and platform fallbacks, workflow hooks, static completions, and cleanup with user replacements | `spec/contract/bash_nav_spec.sh`, `spec/contract/bash_utilities_spec.sh`, `spec/contract/bash_workflow_spec.sh`, `spec/contract/bash_static_completion_spec.sh` |
| Bash startup | Sync notice generation and throttle, detached checks, opt-in fortune in eligible sessions, and real-tool live PTY smoke check | `spec/contract/bash_startup_spec.sh`, `e2e/bash-live.py` |
| path | Tier order goldens (macOS/Linux/modules), placement, reload, dot rule, spaces, tiers option, pending commands, env finalizers, requires-after-brew | `spec/zsh/path_spec.sh` |
| agent | Agent marker option declared by the module; core classification reads it across session modes | `spec/zsh/modules/agent/agent_spec.sh`, `spec/zsh/core_session_spec.sh` |
| brew | Homebrew and Linuxbrew tier placement, `setup-homebrew` variants, reload skip, cached shellenv, and Fish parity | `spec/zsh/tools_spec.sh`, `spec/zsh/environment_spec.sh`, `modules/brew/tests/brew_test.fish` |
| bun | `BUN_INSTALL` export, user-tier bin placement when installed, and completion `fpath` wiring | `spec/zsh/tools_spec.sh` |
| pnpm | `PNPM_HOME` export for macOS (`~/Library/pnpm`) and Linux (`~/.local/share/pnpm`), and `pnpm.path` option toggle | `spec/zsh/tools_spec.sh` |
| go | `GOPATH` bin directories added to the user tier when present | `spec/zsh/tools_spec.sh` |
| rust | `CARGO_HOME` / `~/.cargo/bin` added to the user tier when present | `spec/zsh/tools_spec.sh` |
| lmstudio | LM Studio CLI directory in `local` tier on macOS and `app` tier on Linux | `spec/zsh/tools_spec.sh` |
| cuda | Linux-only CUDA path and MPS exports gated on `/dev/nvidiactl` without forking `lspci` | `spec/zsh/tools_spec.sh` |
| node-nvm | Manager tier ahead of brew, nvm alias resolution, lazy load on first use, `.nvmrc` hook, and Fish parity | `spec/zsh/manager_paths_spec.sh`, `spec/zsh/startup_spec.sh`, `modules/node-nvm/tests/node-nvm_test.fish` |
| go-gvm | Manager tier ahead of brew, fork-free gvm selection and `GOROOT`, lazy load, `go.mod` hook, installer, and Fish parity | `spec/zsh/manager_paths_spec.sh`, `spec/zsh/core_agent_spec.sh`, `modules/go-gvm/tests/go-gvm_test.fish` |
| python | uv preferred over pyenv, pyenv shims in manager tier, lazy pyenv fallback, and Fish parity | `spec/zsh/manager_paths_spec.sh`, `spec/zsh/startup_spec.sh`, `modules/python/tests/python_test.fish` |
| mise | Per-tool ownership and automatic fallback; manager shims and stale-entry removal; safe exports; cached activation and hook modes; immediate refresh; compatibility translations; legacy reload restoration; Bash and Fish parity | `spec/zsh/modules/mise/mise_spec.sh`, `modules/mise/tests/mise_test.fish`, `modules/mise/tests/mise_foreign_test.fish`, `spec/contract/bash_spec.sh`, `spec/contract/fish_render_spec.sh` |
| zsh-options | Kept `setopt` set, locale, `TERM` normalization, unexported `PS1`, `j` alias, FreeBSD compatibility, and PTY persistence | `spec/zsh/tools_spec.sh`, `spec/zsh/pty_interactive_spec.sh` |
| editor | Editor selection (`editor.command` option, then `emacs -nw`, then `vi`, no xemacs fallback), PTY persistence, and Fish parity | `spec/zsh/tools_spec.sh`, `spec/zsh/pty_interactive_spec.sh`, `modules/editor/tests/editor_test.fish` |
| pager | `PAGER`, `LESS`, `MANPATH`, native coloured man pages, coloured `diff` and `diffcp`, PTY persistence, and Fish parity | `spec/zsh/tools_spec.sh`, `spec/zsh/omz_removal_spec.sh`, `spec/zsh/pty_interactive_spec.sh`, `modules/pager/tests/pager_test.fish` |
| ls | One consistent `ll`/`la`/`dir`/`lf`/`lsf` family with and without `eza`, macOS `-G` and Linux `--color=auto` native `ls` aliases, and PTY persistence | `spec/zsh/tools_spec.sh`, `spec/zsh/pty_interactive_spec.sh` |
| ps | Seven helpers (`pss`, `pssj`, `psj`, `pssu`, `pssuj`, `psuj`, `psju`), header kept, self-match excluded, portable macOS/Linux flags; procs drawing when installed (`ps.procs`), bare `ps` untouched, and Fish parity | `spec/zsh/ps_spec.sh`, `spec/zsh/modules/ps/ps_spec.sh`, `modules/ps/tests/ps_test.fish` |
| nav | Directory stack options, Alt-arrow navigation widgets in every keymap, spaced paths, history caps, reload persistence in PTY, and Fish parity | `spec/zsh/tools_spec.sh`, `spec/zsh/omz_removal_spec.sh`, `spec/zsh/pty_interactive_spec.sh`, `modules/nav/tests/nav_test.fish` |
| zoxide | Cached init once per shell, skipped on reload, and Fish parity | `spec/zsh/tools_spec.sh`, `spec/zsh/startup_spec.sh`, `modules/zoxide/tests/zoxide_test.fish` |
| direnv | Opt-in cached hook once per shell, skipped on reload, and Fish parity | `spec/zsh/tools_spec.sh`, `modules/direnv/tests/direnv_test.fish` |
| greeting | Opt-in fortune once per interactive shell, quiet by default, and Fish parity | `spec/zsh/tools_spec.sh`, `spec/zsh/startup_spec.sh`, `modules/greeting/tests/greeting_test.fish` |
| command-not-found | Homebrew (Apple Silicon and Intel symlink) and Linux apt handlers, missing-provider 127 fallback, and Fish parity | `spec/zsh/omz_removal_spec.sh`, `modules/command-not-found/tests/command-not-found_test.fish` |
| completion | Native `compinit -i -d` with cache fingerprint rebuild, zstyles with no forks, insecure `fpath` handling, `completion-ui`, and PTY init; managed startup skips global compinit even with insecure `fpath` | `spec/zsh/tools_spec.sh`, `spec/zsh/startup_spec.sh`, `spec/zsh/pty_interactive_spec.sh`, `spec/zsh/doctor_spec.sh` |
| completion-fzf-tab | Offline pinned plugin loading (`source`/`fpath`), entry-file order, explicit `zsh-plugin-update`, no-eval parsing, and PTY one-time load | `spec/zsh/omz_removal_spec.sh`, `spec/zsh/startup_spec.sh`, `spec/zsh/pty_interactive_spec.sh` |
| completion-carapace | Opt-in default (off); activation via `enable` option or explicit `module` line; mutual exclusion with `completion-fzf-tab` unless `allow_fzf_tab` or `MARKSHARC_COMPLETION_UI=both`; silent fallback to fzf-tab when `carapace` is missing; normalized `bridges`/`excludes` and cached init invalidation; `completion-ui` session switching with `exec zsh -l` guidance; reload and inherited-export cleanup; quiet batch/agent; doctor and Homebrew package | `spec/zsh/modules/completion-carapace/carapace_spec.sh`, `spec/zsh/doctor_spec.sh`, `spec/zsh/day2_spec.sh` |
| zsh-autosuggestions | Pinned plugin load order after fzf-tab, nav and atuin; sourced once, not on reload; silent without clone; atuin strategy gating and widget clearing | `spec/zsh/modules/zsh-autosuggestions/autosuggestions_spec.sh`, `spec/zsh/modules/zsh-syntax-highlighting/load_order_spec.sh` |
| zsh-syntax-highlighting | Pinned plugin loads last of all interactive modules; highlighters; sourced once, not on reload; silent without clone | `spec/zsh/modules/zsh-syntax-highlighting/load_order_spec.sh`, `spec/zsh/system_modules_spec.sh` |
| fzf-fish | Pinned `fzf.fish` plugin loads in interactive Fish sessions and is skipped in batch sessions | `spec/contract/fish_plugin_spec.sh` |
| line-editor-ble | Explicit opt-in `ble.sh` acquisition (`install ble.sh` / `update --only ble-sh`), failed-build cleanup, pin reuse, and changed-pin updates | `spec/contract/bash_ble_acquisition_spec.sh` |
| theme | Native behaviour without vivid, bat, delta, fd or eza; cached vivid `LS_COLORS`; bat or batcat man pager; `BAT_THEME`; delta include appended to and removed from `GIT_CONFIG_COUNT`; fzf command, layout and previews, fzf-tab preview zstyles; reload removal; loads before completion; Fish parity | `spec/zsh/modules/theme/theme_spec.sh`, `modules/theme/tests/theme_test.fish` |
| prompt-starship | Cached init; `config` option selects bundled preset or file as `STARSHIP_CONFIG`, unknown ignored, only its own value removed; rich preset; Fish parity | `spec/zsh/tools_spec.sh`, `spec/zsh/modules/prompt-starship/starship_spec.sh`, `modules/prompt-starship/tests/prompt-starship_test.fish` |
| history-atuin | Wrapper over atuin (`history`, `h`), session UUID handling, builtin fallback, no native history files written in PTY (including Apple Terminal), and Fish parity | `spec/zsh/history_spec.sh`, `modules/history-atuin/tests/history-atuin_test.fish` |
| history-native | Fallback state-dir history file when atuin is absent, no stray history files, and Fish parity | `spec/zsh/history_spec.sh`, `modules/history-native/tests/history-native_test.fish` |
| OMZ removal | No OMZ, p10k, COMPFIX or legacy cloud startup references; no kubectl/gcloud startup side effects | `spec/zsh/omz_removal_spec.sh` |
| Overlay | Private module root, host config, env-id invalidation, reload paths, function ownership, post hook, option restore | `spec/zsh/overlay_spec.sh` |
| Modules | Bands, double-source idempotency, layout, interactive load, module.conf contract, and module `tests/` symlink linkage | `spec/zsh/modules_spec.sh`, `spec/zsh/module_specs_spec.sh` |
| ssh-agent | Cache in state dir, one-time migration from legacy path, insecure parents refused, probing, parsing, cleanup, same-host launch parent socket, Linux `XDG_RUNTIME_DIR/openssh_agent` and `--forwarded` discovery, and Fish parity | `spec/zsh/modules/ssh-agent/agents_spec.sh`, `modules/ssh-agent/tests/ssh-agent_test.fish` |
| x11 | Inherited DISPLAY remembered as DISPLAY_ORIG, empty DISPLAY dropped, same-host launch parent display, no sleep or network probes, and Fish parity | `spec/zsh/modules/x11/x11_spec.sh`, `modules/x11/tests/x11_test.fish` |
| docker | `claude-yolo` only in docker with SANDCAT; `cleanup-docker` through docker only; `fix-docker-socket` Darwin `-f %Sg` vs Linux `-c %G` stat flags and group check; Fish parity | `spec/zsh/modules/docker/docker_spec.sh`, `modules/docker/tests/docker_test.fish` |
| mux | Adapter contracts, nested title updates, tmux reattach, bounded forwarding recovery, launch capabilities, and Fish parity | `spec/zsh/modules/mux/mux_spec.sh`, `spec/zsh/modules/mux/adapters_spec.sh`, `spec/zsh/modules/mux/tmux_launch_spec.sh`, `spec/zsh/modules/mux/herdr_launch_spec.sh`, `modules/mux/tests/mux_test.fish` |
| launch | Positional and flag syntax, validation and results, mux and machine selection, dry-run argv, session metadata and forwarding; repository and worktree resolution | `spec/zsh/modules/launch/launch_session_spec.sh`, `spec/zsh/modules/launch/launch_repo_spec.sh` |
| Run after init | One-shot zsh, Fish and Bash startup hooks, encoded and empty argv words, exec mode, and interactive class only | `spec/contract/launch_run_spec.sh` |
| Launch completions | Host and mux candidates, positional host syntax, options, and offline cached repository names | `spec/zsh/launch_completions_spec.sh`, `fish/completions_test.fish`, `spec/zsh/modules/launch/launch_repo_spec.sh` |
| titles | `set-title`/`chdir-set-title` escape and skip behavior, PTY `cd` title updates and reload hook deduplication, and Fish parity | `spec/zsh/modules/titles/titles_spec.sh`, `spec/zsh/pty_interactive_spec.sh`, `modules/titles/tests/titles_test.fish` |
| herdr | Session shims from herdr session list, collie detection, render-time completion generation, generator-failure atomicity, and Fish parity | `spec/zsh/modules/herdr/herdr_spec.sh`, `spec/zsh/modules/cc-providers/shims_spec.sh`, `modules/herdr/tests/herdr_test.fish` |
| wezterm | `install-wezterm-terminfo` failure propagation and cleanup | `spec/zsh/modules/wezterm/wezterm_spec.sh` |
| cc-providers | Data-only provider files, secret-free executable shims, bash invocation and private cache | `spec/zsh/modules/cc-providers/shims_spec.sh` |
| git-worktree | `gwt-clean` preflight, squash/merge detection, pre-remove hook point, launched cleanup terminal exit; `repo-sync` roots/orgs options; `repo-list` inventory and remote cache; Fish parity | `spec/zsh/modules/git-worktree/cleanup_spec.sh`, `spec/zsh/modules/git-worktree/repo_sync_spec.sh`, `spec/zsh/modules/launch/launch_repo_spec.sh`, `modules/git-worktree/tests/git-worktree_test.fish` |
| cwf | `cwf-new` creation, unmanaged copies, executable hooks and copy-exclude; launched handoff, base repository selection and worktree marker; cached integration during interactive init and reload, quiet batch/agent; Fish parity | `spec/zsh/modules/cwf/cwf_spec.sh`, `modules/cwf/tests/cwf_test.fish` |
| Commands | Encoded caller-state directives, hostile values, state wrappers, deferred validated exit after file removal, and private staged shims | `spec/zsh/directives_spec.sh`, `spec/contract/fish_directives_spec.sh`, `spec/zsh/render_spec.sh` |
| fish-bridge | `run-fish` curated environment | `spec/zsh/modules/fish-bridge/fish_bridge_spec.sh` |
| cloud | `install-krew` failure propagation and artifact cleanup | `spec/zsh/modules/cloud/cloud_spec.sh` |
| System modules | Real-tree wiring (functions, hooks, options via synthesized overlay), env/init load order, quiet agent/batch/PTY startup | `spec/zsh/system_modules_spec.sh` |
| Installer | Fresh install from a checkout: stub, template overlay, manifest, first declarative render; paths with spaces, quotes and dollars survive; non-default MARKSHARC_CONFIG named in the stub | `spec/install/installer_spec.sh` |
| Installer | Existing zsh dotfiles (regular files, symlinks, a foreign `~/.zshenv`) backed up privately and recorded; idempotent re-run keeps the original backup | `spec/install/installer_spec.sh` |
| Bash installer | Fresh and upgraded installs preserve regular and symlinked startup files, edited stubs and interrupted retries | `spec/install/installer_spec.sh`, `spec/install/rerun_spec.sh`, `spec/install/uninstall_spec.sh` |
| Installer | `--dry-run` prints every action and writes nothing; framework from `--home`, own checkout or a clone (reused, never pulled); `--overlay` path, URL, conflict and existing overlay; zsh, git and zsh version checked before any write; chsh hint only; runs under dash | `spec/install/installer_spec.sh` |
| Installer | Re-run conflict detection (deleted/replaced stub, hand-edited stub copy), MARKSHARC_CONFIG and XDG checks, trailing slashes, checkout `bin/marksharc` | `spec/install/rerun_spec.sh` |
| Installer | Plugin pins cloned into the cache at the pinned commit; `--no-plugins` skips and names `marksharc update`; dry run only reports; an unreachable pin warns and the install completes | `spec/install/plugins_spec.sh` |
| Uninstall | Restores files and symlinks, removes stub and ZDOTDIR, keeps framework, overlay and cache; conflicts and missing backups fail before any change; `--purge` confirmation, scope and guards | `spec/install/uninstall_spec.sh` |
| Coexist installer | `--coexist` adds one marked source line to `~/.zshenv` and `~/.zshrc` without redirecting `ZDOTDIR` or modifying Bash/Fish files; preserves existing files, symlinks and permissions; safe fallback, idempotent re-run, mode conflict guards, doctor diagnostics and clean uninstall | `spec/install/coexist_spec.sh`, `spec/zsh/doctor_spec.sh`, `e2e/install-e2e.sh` |
| Install e2e | Checkout, piped clone (`--purge --yes`), legacy `--clobber` and `--coexist` passes: login, interactive and PTY shells quiet with MARKSHARC_SESSION set, uninstall and restoration | `spec/install/e2e_spec.sh`, `e2e/install-e2e.sh` |
| Stub fallback | Missing, unreadable, failing or unparsable core: minimal PATH, exactly one stderr line, clean stdout, batch, login, agent and PTY | `spec/zsh/fallback_spec.sh` |
| CLI | usage, unknown commands, version (VERSION plus git describe), reload explanation, module list statuses, enable/disable edits (template lines, explicit lists, host override, symlinked config.conf, refusals) | `spec/zsh/core_cli_spec.sh` |
| Sync | Local bare remotes, deleted upstreams, configured upstream and host-overridden extra repos, linked overlay owner and deduplication, dirty/ahead/diverged/offline and failed status checks, plugin pins, cache invalidation and minimal update | `spec/zsh/sync_spec.sh` |
| Push sync & updates | `update -y` (never passed to `brew upgrade`, passed to `mise` and system updates) and `--system` (macOS no-op, Linux `apt`/`dnf`/`yum`); `sync --auto` (quiet, flock lock, state log, dirty-tree skip), `sync --update`, `sync timer on\|off\|status` launchd/systemd golden units; `hosts.conf` inventory and `gum`/`fzf` populate from `.ssh/config` and `hc machine ls --json`; `push` parallel SSH fan-out, regex host selection, per-host timeout and result table | `spec/zsh/push_sync_spec.sh` |
| Launch foundation | Picker tools, cancellation, and terminal requirements; shared JSON reply parsing; reserved host names and per-instance machine resolution; tmux, Herdr TUI, and Herdr Core launch capabilities, instance discovery, placements, dry runs, and literal argument forwarding | `spec/zsh/launch_foundation_spec.sh`, `modules/mux/tests/tmux_launch_spec.sh`, `modules/mux/tests/herdr_launch_spec.sh` |
| Day 0 and Day 2 | Package rendering, safe bundle input, update selection, failure continuation, ordering and installer registry | `spec/zsh/day2_spec.sh` |
| Notify | Local fetch without merge, deleted upstreams and host overrides, later PTY notice and sync, failed-check throttle, concurrent workers, killed-lock-holder and stale-result recovery, batch and agent exclusion | `spec/zsh/notify_spec.sh` |
| Doctor | Stub checksums and generated stubs, broken links, missing commands only for modules named in the overlay, plugin pins with the update hint, dirty repos and host overrides, foreign lines, duplicate PATH, environment ID, and PTY startup budget and timeout with notify suppressed; real compinit and new-user blocked prompts, prompt progress, and blocked-child cleanup | `spec/zsh/doctor_spec.sh` |
| Doctor (fish) | Unchanged, modified, missing and symlinked fish stub; foreign `config.fish` lines; fisher leftovers | `spec/zsh/doctor_spec.sh` |
| Overlay template | No active module line, one commented off line per public module, real option examples, silent post hook | `spec/zsh/template_overlay_spec.sh` |
| Function-safe modules | File-scope declarations in module env/init files, core files and overlay hooks say `-g`; env phase ends with `true`; `marksharc reload` and `cs` leave clean globals, unexported PS1 and history settings | `spec/zsh/function_safe_spec.sh` |
| Hygiene | Personal-value lint over the portable tree | `spec/zsh/personal_values_spec.sh` |
| Contract | Quiet batch/agent startup, same environment in every zsh mode, idempotent re-source, writes confined to cache/state | `spec/contract/zsh_spec.sh` |
| Fish contract | Shared environment and PATH, session classification, inherited render ID, reload (including unloading a disabled module's functions), native modules and plugin loading, safe caller-state directives | `spec/contract/fish_render_spec.sh`, `spec/contract/fish_plugin_spec.sh`, `spec/contract/fish_directives_spec.sh` |
| Fish units | Init cache (hit, miss, key change, empty, failing and missing tool, `-P`, `-x`), `marksharc` completion | `fish/cache_test.fish`, `fish/completions_test.fish` |
| Fish runner | Pinned-version check, scrubbed environment, default discovery, workspace removal | `spec/repo/fish_runner_spec.sh` |
