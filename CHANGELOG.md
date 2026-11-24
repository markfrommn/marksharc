# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

- Fish is a daily-driver shell: modules carry `init.fish`, `functions/fish` and
  `completions/fish` (nav, ls, ps, titles, mux, x11, docker, greeting,
  command-not-found, node-nvm, go-gvm, python, brew, pager, editor, history-atuin,
  history-native, prompt-starship, zoxide, direnv, cwf, herdr, ssh-agent,
  git-worktree), tool init is cached, `marksharc` has fish completions, and
  [docs/fish.md](docs/fish.md) publishes the parity table. `gvm use` works natively in
  fish, so fish-gvm and bass are no longer needed.
- `doctor` reports fisher leftovers so a host can drop fisher, and accepts an
  unchanged fish stub whatever spacing `cksum` prints.
- Fish units run under fishtape 3.0.1 (`tests/run-fish-units`, pinned in
  `tests/fishtape.pin`) in `tests/check` and CI.
- Interactive fish no longer prints fish's welcome text unless `fish_greeting` is set.

### Fixed

- `marksharc reload` in fish now finishes its own work: the entry point's final `return`
  used to end the reload early, leaving the session marked as reloading. A reload that
  disables a module also removes the hooks, wrappers and key bindings its `init.fish` added.

- Bash environment rendering and startup stubs provide PATH and tool exports to Bash
  sessions. `set agent.bash_env on` enables the noninteractive Bash hook for agents.

### Fixed

- `doctor` recognizes unchanged installer-managed Bash startup files, reports
  modified or missing files, and identifies provider configuration that needs migration.
- Interactive zsh startup on the Mac drops from about 5 s to under 1 s: `node-nvm`
  and `go-gvm` load nvm and gvm on first use instead of at startup. The env phase
  already puts the default node and Go on PATH, and `go-gvm` sets `GOPATH` and
  `gvm_go_name` itself. The `.nvmrc` and `go.mod` hooks load the manager only
  when a switch may be needed.
- `install.sh` fetches the pinned plugins, so fzf-tab works after a fresh install
  (`--no-plugins` skips the fetch). `doctor` names `marksharc update` for a
  missing pin.
- `doctor` no longer reports a missing required command for a module that is
  enabled by default and skips itself (for example `herdr` on a host with only
  the herdr app). It reports a startup that outlives `doctor.startup_timeout_ms`
  (default 5000) as timed out instead of failed.
- zsh startup on Debian/Ubuntu: the distro-global `compinit` no longer runs
  (`skip_global_compinit` is set in the env phase), so non-tty and agent shells
  no longer abort at startup; the completion module now runs `compinit -i`, so
  the security audit still applies but an insecure system directory (seen on the
  ubuntu-latest CI image) is excluded instead of prompting or hanging the shell.

### Added

- Opt-in `mise` ownership of Node, Go, Python, and Ruby per host, with manager-tier shims
  for every session class, directory-change-only interactive activation, safe `MISE_*`
  defaults, legacy-manager fallback, optional nvm/gvm compatibility functions, doctor
  diagnostics, and explicit install/update integration. Migration is in
  [docs/mise.md](docs/mise.md).
- `marksharc bootstrap`, declarative package bundles, selectable update steps and
  explicit installers for krew, gvm, WezTerm terminfo, pyenv and nvm. Updates
  report each result and continue after failures.
- Fish startup loads a rendered environment, pinned plugins, caller-state
  commands, and current-shell reload. The installer manages a fish conf.d stub.
- Write-once workflow, SSH-agent and Docker commands run as module executables.
  zsh wrappers apply caller-state directives; provider and session shims are generated
  in the private host cache and can be called from child shells. Provider files and
  workflow hooks migrate as described in `docs/write-once.md`.
- `marksharc render`: declarative module and overlay `env`, `path`, `alias` and
  `completion` directives, with `when` guards, per-host cached `env.zsh`, generated
  completions, render ids and stale-input reload. Overlay `tiers` lines customize
  PATH order. The directive-expressible public environment and aliases now render
  from `module.conf`, and the old compatibility host-fact names are gone.
- `marksharc sync`, `update`, and `doctor`: fast-forward safe checkouts, refresh
  plugin pins, report health, and notify interactively after a throttled detached fetch.
- Installer and command: `install.sh` (`--home`, `--overlay`, `--dry-run`; backs up
  the HOME zsh dotfiles with a manifest, writes the `~/.zshenv` stub with a
  minimal-PATH fallback, safe to re-run), `bin/marksharc` (`reload`,
  `module list|enable|disable`, `uninstall [--purge]`, `version`), the overlay
  template in `templates/overlay/`, and an install end-to-end CI job on macOS and
  Ubuntu (`tests/e2e/install-e2e.sh`).
- Repository layout from the specification (`core/`, `modules/`,
  `templates/overlay/`, `tests/`, `docs/`, `specs/`, `memory/`).
- ShellSpec test harness with a pinned runner, per-example sandbox and smoke specs.
- `tests/lint`: `zsh -n`, shellcheck and `fish --no-execute` over every shell file.
- GitHub Actions CI on macOS and Ubuntu.
- Developer guide in `docs/DEVELOPING.md`.
- Zsh core loader (`core/zsh/`): session classes, env/init phases, module
  loader, tiered PATH builder hooks, cached tool init, generated ZDOTDIR,
  verbose reload (`cs`/`li`).
- The 26 environment and tool modules (`modules/`): path, brew, zsh-options,
  editor, pager, ls, ps, nav, zoxide, completion, completion-fzf-tab,
  command-not-found, history-atuin, history-native, prompt-starship,
  node-nvm, go-gvm, python, bun, pnpm, rust, go, lmstudio, cuda, direnv,
  greeting.
- The 13 system and workflow modules (`modules/`) with their module-local
  specs linked from `tests/spec/zsh/modules/`: agent, ssh-agent, x11,
  docker, mux, titles, herdr, wezterm, cc-providers, git-worktree, cwf,
  fish-bridge, cloud.
- Cross-shell contract suite (`tests/spec/contract/`), run in CI on macOS and
  Ubuntu.
- Personal-value lint over the portable tree.
