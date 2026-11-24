# DEV-58 — Fish modules and retirement of the old fish config

**Goal** — Fish is a daily-driver shell on the marksharc structure: every MVP module is supported,
native-equivalent, or not applicable in fish, and nothing depends on the old `config/fish` tree or fisher.

**Architecture** — Each module that needs interactive fish behaviour carries `init.fish`,
`functions/fish/<fn>.fish` and, where useful, `completions/fish/<cmd>.fish`; the fish loader from
DEV-57 already sources and path-registers them. Tool integrations (`starship`, `atuin`, `zoxide`,
`direnv`, `pyenv`, `cwf`, `herdr`, `brew`) go through a fish port of the zsh init cache. Write-once
commands that change caller state are called through per-module fish wrappers over the existing
directive applier. Native fish code is tested with fishtape units next to each module.

**Authority** — MARKSHARC-SPEC §§ 6.4, 6.6, 6.8–6.13, 7.1, 8, 10 and MARKSHARC-PLAN P4.2.

## Decisions

- fishtape 3.0.1 is pinned in `tests/fishtape.pin` (commit `21ccd8c0742b2549093fe5918b0bd565dd43a9ba`).
  Like ShellSpec, tests never install it: `tests/run-fish-units` needs `FISHTAPE_FUNC` (the pinned
  `functions/fishtape.fish`) and runs in a scrubbed environment with a throwaway HOME. CI fetches the pin.
- Unit files are `modules/<name>/tests/<name>_test.fish` and `tests/fish/*_test.fish`; each file runs in
  its own fish process (fishtape's model) and builds its own temporary HOME and command stubs.
- `_ms_fish_init_cached [-k key] [-P PATH] <tool> <command…>` in `core/fish/lib/cache.fish` mirrors
  `_ms_init_cached`: keyed on the resolved binary, its mtime, the arguments, the key and the PATH; a hit
  forks nothing; empty output is never cached; a missing tool returns 1 silently.
- The caller-state wrappers (`cwf-new`, `gwt-clean`, `setup-ssh-agent`) move out of the hardcoded switch in
  `core/fish/lib/modules.fish` into each module's `functions/fish/`. `cwf-new` and `gwt-clean` pass their
  hook lists (`cwf_new_post_create_hooks`, `cwf_new_copy_exclude`, `gwt_clean_pre_remove_hooks`) as the
  same newline-joined variables the zsh wrappers pass.
- `go-gvm` switches Go natively (PATH, `GOROOT`, `GOPATH`, `gvm_go_name`) from the known gvm layout, so
  fish-gvm and bass are no longer needed; other `gvm` subcommands run gvm under bash.
- `node-nvm`'s `.nvmrc` hook asks bash nvm in `$NVM_DIR` (the store the env phase and zsh use) for the
  bin directory and applies it as data. The pinned nvm.fish plugin from DEV-57 stays as fish's `nvm`.
- `doctor` keeps listing foreign `config.fish` lines and also reports fisher leftovers (`fish_plugins`,
  `functions/fisher.fish`), so a host can drop fisher.

## 1. Fish unit runner and shared helpers

- [x] Pin fishtape; add `tests/run-fish-units`; wire it into `tests/check` and both CI jobs.
- [x] Add `core/fish/lib/cache.fish` with `_ms_fish_init_cached` and units for hit, miss, key change,
      empty output, failing tool and missing tool.
- [x] Move the caller-state wrappers into module `functions/fish/` and keep the contract specs green.

## 2. Module ports (init.fish, functions/fish, completions/fish, units)

- [x] nav (Alt-Up/Down on an empty command line; fish already binds Alt-Left/Right to prevd/nextd),
      ls (bare `ls` stays fish's own wrapper), ps (the seven helpers over one `_ms_ps`).
- [x] titles (`chdir-set-title`, `set-title`, the PWD hook, a quiet `fish_title`), mux (`fix-tmux` as data),
      x11 (`setup-x11-display`), docker (`claude-yolo` inside SANDCAT containers), greeting.
- [x] node-nvm, go-gvm, python, brew, pager, editor, command-not-found.
- [x] history-atuin (`history`, `h`), history-native (`h`), prompt-starship, zoxide, direnv, cwf, herdr,
      ssh-agent, git-worktree (`git-managed`, `git-unmanaged`).
- [x] Completions: `marksharc` subcommands and module commands that take a fixed vocabulary.

## 3. Retirement

- [x] doctor fixtures for unchanged, modified, missing and foreign fish files, plus fisher leftovers.
- [x] `docs/fish.md`: the parity table, the retirement steps for `config/fish` and fisher, and where each
      `test_parity.py` case now lives.

## 4. Verify and record

- [x] `tests/check` (lint, zsh, contract, install, repo, fish units) on Linux; a PTY smoke of an
      interactive fish against a temporary HOME with the real tools on this host.
- [x] Update `tests/README.md`, `README.md`, the changelog and the P4.2 outcome.
- [x] Hosted macOS and Ubuntu checks on the PR. The Mac daily-driver check stays a manual acceptance step.

## Local verification

On Linux with fish 4.0.2 and zsh 5.9: `tests/lint` passed over 182 files; the zsh suite ran
452 examples with one platform skip; the contract suite 61, the install suite 57 and the
repository suite 34 examples, all passing. `tests/run-fish-units` under the pinned fishtape 3.0.1
ran 25 files and passed 490 assertions, and it exits non-zero on a deliberately failing unit.
An install of this checkout into a temporary HOME started an interactive fish in a PTY with
no output, the module helpers, hooks and key bindings in place, and about 165 ms warm startup.

The review found the runner could not report failures (fishtape's universal counters under
`--no-config`) and that a reload disabling a module left its hooks and bindings behind. Both are
fixed. Reloading also exposed an older defect: the entry point's final `return` ended
`marksharc reload` early and left `_ms_fish_reloading` set. That is fixed too, with regression checks.

Fish on the Mac and sol as a daily driver remains a manual acceptance step.

## Delivery

Implemented in [PR #13](https://github.com/markfrommn/marksharc/pull/13). Both hosted check jobs
and both install end-to-end jobs passed on commit `68b5dce`
([run](https://github.com/markfrommn/marksharc/actions/runs/45301839514)). The first hosted runs
exposed portability gaps the Linux host could not show: Homebrew fish 4.9 embeds its function
files and lists comments in `bind --user`, macOS keeps `bash` and `cat` only in `/bin` and has BSD
`touch`, and fishtape skips without counting an assertion whose expression errors. The code and
units now handle each case, and `run-fish-units` fails on a fish error.
