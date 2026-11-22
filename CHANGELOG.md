# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- zsh startup on Debian/Ubuntu: the distro-global `compinit` no longer runs
  (`skip_global_compinit` is set in the env phase), so non-tty and agent shells
  no longer abort at startup; the completion module now runs `compinit -i`, so
  the security audit still applies but an insecure system directory (seen on the
  ubuntu-latest CI image) is excluded instead of prompting or hanging the shell.

### Added

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
