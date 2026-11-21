# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added

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
- Cross-shell contract suite (`tests/spec/contract/`), run in CI on macOS and
  Ubuntu.
- Personal-value lint over the portable tree.
