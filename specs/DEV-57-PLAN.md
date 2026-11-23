# DEV-57 — Fish core implementation plan

**Goal** — Fish and zsh start with the same framework-managed environment and PATH on macOS.

**Architecture** — The zsh renderer reads shared configuration and emits native files in the host cache. Fish applies its cached environment and owns its session classification, interactive initialization, reload, and caller-state application.

**Authority** — MARKSHARC-SPEC §§ 6.1–6.11, 6.15, 8, and 10 and MARKSHARC-PLAN P4.1.

## 1. Render and load the environment

- [ ] Add a failing ShellSpec contract that runs real fish and zsh against the same temporary HOME, config, PATH, and stubs. Compare the ordered PATH and managed environment, including overlay values, runtime guards, manager directories, and shims. Exercise quoted values and hostile literal data.
- [ ] Extend `core/zsh/lib/render.zsh` and its cache validation to publish a usable `env.fish` from the same resolved inputs as `env.zsh`. Source the cache from `core/fish/marksharc.fish`. Preserve runtime guards, tier ordering, inherited PATH entries, and exports. Keep warm startup quiet and offline.
- [ ] Extend the contract to exercise login, batch, agent, and terminal-backed interactive launches, configurable agent markers, inherited render IDs, and repeat sourcing. Use `tests/run-tests --shell sh spec/contract` for the focused check.

## 2. Install and manage the fish stub

- [ ] Add failing installer examples for the XDG `fish/conf.d/00-marksharc.fish` path and custom roots with spaces and quotes, keeping `config.fish` byte-identical. Cover dry run, rerun, collision handling, uninstall, and compatibility with an existing zsh-only manifest.
- [ ] Extend `install.sh` and the existing `core/cli/uninstall` ownership lifecycle to manage the fish stub. Cover ownership and checksum behavior in `doctor` where the existing diagnostics apply. The stub sources the public fish entry point.
- [ ] Run `tests/run-tests --shell sh spec/install` and the install end-to-end check against a temporary HOME.

## 3. Initialize, load pins, and reload

- [ ] Add failing fish-facing contract examples for a missing clone, a pinned clone with functions, completions, and ordered conf.d hooks, and reload after editing the overlay. Verify interactive work stays out of batch and agent sessions, foreign search paths survive, and managed paths remain de-duplicated.
- [ ] Add the fish plugin loader and reviewed revision pins for the two plugins named in P4.1. Reuse the install/update pin workflow and doctor diagnostics. Startup only reads the cache. Fish reload delegates rendering to the CLI, applies the new environment in the same shell, and keeps the session class even with redirected output.
- [ ] Add failing protocol tests in the contract suite. Apply `cd`, `pushd`, `setenv`, and `unsetenv` natively to the existing tab-delimited, percent-encoded format. Require literal preservation of spaces, tabs, newlines, percent signs, and shell metacharacters. Check malformed and unknown records, unsafe variable names, and directory errors.

## 4. Verify and record the result

- [ ] Run `tests/check`, the install end-to-end check, and stack-check on `origin/main...HEAD`. Verify repeat rendering, cache containment, and absence of generated-file drift. Add the new coverage to `tests/README.md` and update the changelog.
- [ ] Verify hosted macOS and Ubuntu checks on the PR head. Report personal Mac overlay verification separately if it is unavailable. DEV-58 owns the module migration, fishtape adoption, and retirement of the previous fish configuration.

The implementation uses fish 4.x, zsh 5.9+, and the pinned ShellSpec runner. Tests use isolated homes, stubbed commands, and disposable repositories.
