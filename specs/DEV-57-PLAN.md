# DEV-57 — Fish core implementation plan

**Goal** — Fish and zsh start with the same framework-managed environment and PATH on macOS.

**Architecture** — The zsh renderer reads shared configuration and emits native files in the host cache. Fish applies its cached environment and owns its session classification, interactive initialization, reload, and caller-state application.

**Authority** — MARKSHARC-SPEC §§ 6.1–6.11, 6.15, 8, and 10 and MARKSHARC-PLAN P4.1.

## 1. Render and load the environment

- [x] Add a failing ShellSpec contract that runs real fish and zsh against the same temporary HOME, config, PATH, and stubs. Compare the ordered PATH and managed environment, including overlay values, runtime guards, manager directories, and shims. Exercise quoted values and literal metacharacters.
- [x] Extend `core/zsh/lib/render.zsh` to publish `env.fish` from the same resolved inputs as `env.zsh`. Source and validate the cache from `core/fish/marksharc.fish`. Preserve runtime guards, tier ordering, inherited PATH entries, and exports. Keep warm startup quiet and offline.
- [x] Exercise batch, agent, and terminal-backed interactive launches, configurable agent markers, inherited render IDs, and repeat sourcing in ShellSpec. Check login in the independent fresh-home comparison.

## 2. Install and manage the fish stub

- [x] Add failing installer examples for the XDG `fish/conf.d/00-marksharc.fish` path and custom roots with spaces and quotes, keeping `config.fish` byte-identical. Cover dry run, rerun, collision handling, uninstall, and compatibility with an existing zsh-only manifest.
- [x] Extend `install.sh` and the existing `core/cli/uninstall` ownership lifecycle to manage the fish stub. Cover ownership and checksum behavior in `doctor` where the existing diagnostics apply. The stub sources the public fish entry point.
- [x] Run `tests/run-tests --shell sh spec/install` and the install end-to-end check against a temporary HOME.

## 3. Initialize, load pins, and reload

- [x] Add failing fish-facing contract examples for a missing clone, a pinned clone with functions, completions, and ordered conf.d hooks, and reload after editing the overlay. Verify interactive work stays out of batch and agent sessions, foreign search paths survive, and managed paths remain de-duplicated.
- [x] Add the fish plugin loader and immutable revision pins for the two plugins named in P4.1. Reuse the install/update pin workflow and doctor diagnostics. The plugin loader only reads the cache. Fish reload delegates rendering to the CLI, applies the new environment in the same shell, and keeps the session class even with redirected output.
- [x] Add failing protocol tests in the contract suite. Apply `cd`, `pushd`, `setenv`, and `unsetenv` natively to the existing tab-delimited, percent-encoded format. Require literal preservation of spaces, tabs, newlines, percent signs, and shell metacharacters. Check malformed and unknown records, unsafe variable names, and command failures.

## 4. Verify and record the result

- [x] Run `tests/check`, the install end-to-end check, and stack-check on `origin/main...HEAD`. Verify repeat rendering, cache containment, and absence of generated-file drift. Add the new coverage to `tests/README.md` and update the changelog.
- [x] Verify hosted macOS and Ubuntu checks on the implementation head. DEV-58 owns the module migration, fishtape adoption, and retirement of the previous fish configuration.

The implementation uses fish 4.x, zsh 5.9+, and the pinned ShellSpec runner. Tests use isolated homes, stubbed commands, and disposable repositories.

## Local verification

`tests/check` passed on Linux with 84 files linted, 424 zsh examples with one platform skip,
35 cross-shell contract examples, 51 installer examples, and 27 repository examples.
The standalone end-to-end test passed both checkout and clone installation and uninstall.
An independent temporary-home smoke confirmed matching fish and zsh exports and ordered PATH,
live directory guards, stable repeat rendering, and uninstall. The Linux login comparison excludes
distribution-provided fish vendor snippets so it measures the framework. Both upstream plugin pins
loaded successfully in a disposable fish terminal.

The independent review verified the fixes for pending-tier `uv` detection, git-worktree
options in executable environments, and verbose fish startup and reload. Stack-check passed.

## Delivery

The fish core is implemented in [PR #10](https://github.com/markfrommn/marksharc/pull/10).
Both hosted check jobs and both install end-to-end jobs passed on implementation commit
`72c90f9`. The test runner preserves the selected fish executable inside its isolated PATH,
including Homebrew installs on macOS. Personal Mac overlay parity remains unverified.
[Hosted check results](https://github.com/markfrommn/marksharc/actions/runs/45145933674)
