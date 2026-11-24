# DEV-72 — Opt-in mise module implementation plan

> **For agentic workers:** Implement task-by-task with failing behavior specs first. Keep the work on the DEV-72 branch; phase-lite owns the final save/share steps.

**Goal:** Add an opt-in `mise` module that owns node, Go, Python, and Ruby per host while preserving nvm, gvm, pyenv, and uv as the automatic default/fallback.

**Architecture:** `modules/mise` loads at order 29 and defines one ownership predicate per shell. Its env phase exports safe `MISE_*` settings, removes only owned legacy PATH entries, and puts mise shims in `manager`; its interactive init adds cached native activation and compatibility wrappers. The legacy modules consult the predicate, so an empty tool list or missing `mise` executable leaves their existing behavior untouched.

**Tech stack:** zsh 5.9, fish 4.x, Bash 5, ShellSpec 0.28.1, fishtape 3.0.1, mise’s documented shell activation and `MISE_*` settings.

**Authority:** `specs/MARKSHARC-SPEC.md` §§ 4.3, 5, 6.4, 6.6, 6.7, 7.1, 8, 10, 12; `specs/MARKSHARC-PLAN.md` L6; `specs/DEV-62-PLAN.md` decisions 1–6.

## Global constraints

- `mise.tools` defaults to empty and recognizes only `node`, `go`, `python`, and `ruby`; empty or unavailable mise changes nothing.
- Env work uses native shell operations and stays quiet. Startup never installs, pulls, or updates anything.
- Shims use `${MISE_SHIMS_DIR:-${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims}` in the `manager` tier in every session class.
- `hook` is `chpwd` by default: remove mise’s prompt hook, retain its directory hook, and refresh after `shell`, `sh`, `use`, `unuse`, and `deactivate`. `prompt` retains the prompt hook; `off` is shims-only.
- Export `MISE_NOT_FOUND_AUTO_INSTALL`, `MISE_GO_SET_GOBIN`, and comma-separated `MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS` only while at least one supported tool is owned.
- The pyenv fallback stands aside for owned Python; uv remains preferred.
- Tests use a temporary HOME and stub `mise`, never a real installation or service.
- Follow file-scope `typeset -g` and fish `set -g`/`set -gx` rules; preserve literal arguments and paths containing spaces.

## File map and interfaces

- Create `modules/mise/{module.conf,env.zsh,env.bash,init.zsh,init.fish,installers/mise,tests/mise_spec.sh,tests/mise_test.fish}` and `tests/spec/zsh/modules/mise -> ../../../../modules/mise/tests`.
- Modify `modules/node-nvm/{env.zsh,init.zsh,init.fish}`, `modules/go-gvm/{env.zsh,init.zsh,init.fish}`, `modules/python/{env.zsh,init.zsh,init.fish}` for ownership and reload cleanup.
- Modify `core/fish/lib/modules.fish`, `core/bash/path.bash`, and `core/zsh/lib/render-fish.zsh` for native env parity and conditional nvm.fish loading.
- Modify `core/cli/doctor`; extend `tests/spec/zsh/{doctor_spec.sh,day2_spec.sh}` and the cross-shell contract specs as needed.
- Create `docs/mise.md`; update `README.md`, `docs/fish.md`, `CHANGELOG.md`, `tests/README.md`, `templates/overlay/config.conf`, and the spec/plan outcome.

Ownership predicates, callable by every later module:

```zsh
_ms_mise_owns() {
    [[ $1 == (node|go|python|ruby) ]] || return 1
    _ms_command_available mise || return 1
    local -a tools=( ${=_ms_opt_mise_tools-} )
    (( ${tools[(Ie)$1]} ))
}
```

```fish
function _ms_fish_mise_owns
    contains -- "$argv[1]" node go python ruby; or return 1
    _ms_fish_command_available mise; or return 1
    contains -- "$argv[1]" (string split ' ' -- "$_ms_opt_mise_tools")
end
```

Compatibility translations preserve the remaining argv and normalize gvm’s `go` prefix:

| Input | mise invocation |
| --- | --- |
| `nvm use V` / `gvm use goV` | `mise shell node@V` / `mise shell go@V` |
| `nvm install V` / `gvm install goV` | `mise install node@V` / `mise install go@V` |
| `nvm ls` / `gvm ls` / `gvm list` | `mise ls node` / `mise ls go` |
| `nvm current` / `gvm current` | `mise current node` / `mise current go` |
| `nvm alias default V` / `gvm alias default goV` | `mise use --global node@V` / `mise use --global go@V` |
| any other verb | print the corresponding `mise shell`, `install`, `ls`, `current`, or `use --global` forms and return 2 |

### Task 1: Zsh and Bash ownership, activation, and legacy fallback

- [x] **Write failing specs** in `modules/mise/tests/mise_spec.sh` for: empty tools and missing mise; manager-tier shims in agent/batch/interactive classes; owned-only nvm/gvm stale-entry removal; `MISE_*` option values; cached activation once; no `_mise_hook_precmd` under `chpwd`; refresh after `mise shell` and `mise use`; `prompt` and `off`; compat translations and hints; node/gvm hooks and first-use stubs removed on reload and restored on fallback; Python/uv behavior; Bash PATH parity.
- [x] **Run the red gate:** `tests/run-tests --shell zsh tests/spec/zsh/modules/mise/mise_spec.sh`. Failed as expected on missing ownership, activation, compatibility, and reload behavior; fixture-scope errors were corrected before implementation.
- [x] **Implement the module metadata and env phases:** `order 29`; options `tools ""`, `version_files on`, `compat on`, `auto_install off`, `set_gobin off`, `hook chpwd`; `package brew mise`; `update mise-tools mise upgrade`; `installer mise installers/mise`. Implement the ownership, settings, shim, and stale-PATH contracts in zsh and Bash, with the fish-native equivalent added to `core/fish/lib/modules.fish` in Task 2. Guard `node-nvm`, `go-gvm`, and `python` env branches with the predicate.
- [x] **Implement zsh init and legacy cleanup:** source `_ms_init_cached -k <auto_install> mise mise activate zsh` once per unchanged configuration per interactive shell unless `hook off`; re-source the cached activation when reload changes ownership, hook mode, or activation-shaping settings. Save the activation’s `mise` function before wrapping it so cleanup can restore it; remove/restore hooks and compat functions on reload. Refresh after successful `shell`, `sh`, `use`, and `unuse`; `deactivate` preserves the original command’s status without calling the hook it removes. Mark legacy first-use stubs so owned reloads remove only stubs, never an already loaded real nvm/gvm or a mise compat function. Remove `load-nvmrc` and `_gvm_auto_use` from `chpwd_functions` when owned. Preserve the manager-tier shim entry after activation: with `MISE_NOT_FOUND_AUTO_INSTALL=false`, upstream activation removes the shim entry on initial source; run the existing PATH builder afterward. Subsequent `chpwd` hook-env preserves a restored shim entry.
- [x] **Run the green gate:** the module spec passes with no startup output. The combined focused zsh/doctor/Day 2 run passed 66 examples; `manager_paths_spec.sh` remains in the final `tests/check` gate below.

### Task 2: Fish activation, plugin stand-aside, and reload

- [x] **Write failing fishtape units** in `modules/mise/tests/mise_test.fish` and focused legacy-module regressions for: shims/exports, owned-only stale paths, cached activation once, removal of `__mise_env_eval_on_prompt` under `chpwd`, immediate refresh after `mise use`, compat mappings, legacy hook removal, fallback without mise, and nvm.fish not loading for owned node.
- [x] **Run the red gate:** `tests/run-fish-units modules/mise/tests/mise_test.fish`. Failed as expected on missing fish ownership and activation; invalid exact-match assertions were corrected before implementation.
- [x] **Implement fish init:** cached `mise activate fish`, a restorable `mise` wrapper, directory-only hooks under `chpwd`, and compat functions. Rebuild PATH after initial activation because auto-install-off activation removes the shim entry in fish too. Add ownership branches to the legacy fish env/init paths. In the fish renderer, wrap only node-nvm’s plugin load in a runtime ownership check; keep its pin in `fish.plugins` so install/update/doctor continue to manage it. An absent predicate must mean “not owned” for explicit module lists that omit mise.
- [x] **Run the green gate:** the new fish units plus `tests/spec/contract/fish_plugin_spec.sh`, `tests/spec/contract/fish_render_spec.sh`, and the existing node/gvm/python fish units pass: 196 assertions and 52 cross-shell examples.

### Task 3: Diagnostics, Day 2, migration notes, and repository contract

- [x] **Add failing doctor/Day 2 examples:** nonempty `mise.tools` without `mise`; uv-format `~/.python-version` (`cpython-…-any-any-any`) only for owned Python; clean standard version files and fallback; public installer failure propagation; `mise-tools` update listing/dry-run; Brewfile includes `mise`.
- [x] **Run red:** `tests/run-tests --shell zsh tests/spec/zsh/doctor_spec.sh tests/spec/zsh/day2_spec.sh` failed on the new missing-mise, uv-pin, package/update, and installer examples.
- [x] **Implement diagnostics and installer:** doctor reads configured/default options without requiring the module to be explicitly listed, and does not demand the nvm.fish pin while owned node suppresses that plugin. `installers/mise` downloads `https://mise.run` to a temporary file, runs it with `MISE_INSTALL_HELP=0`, never edits profiles, cleans up, and propagates curl/install failure.
- [x] **Document the built module:** `docs/mise.md` covers per-host options, `cd .`, shims versus activation, fallback, `mise sync node --nvm`, `mise sync python --pyenv`, and reinstalling Go with mise instead of linking gvm. Update the overlay template, installer list, fish parity, changelog, test inventory, and spec/plan so §§ 6.7/7.1 and L6 describe the implementation as built.
- [x] **Run green and final gates:** the focused doctor/Day 2 specs pass. `tests/check` passed with 486 zsh examples, 68 contract examples, 57 install examples, 35 repository examples, and 582 fish assertions (one platform skip). `tests/e2e/install-e2e.sh "$PWD"` passed both checkout and clone install paths.
- [x] **Live acceptance on sol:** use a scratch overlay/cache and the real mise 2026.11.13, never modify the real overlay. Verify an agent shell in a `.nvmrc` worktree selects that Node, mise Go beats Homebrew with inherited gvm paths in every session class, interactive startup remains within `doctor.startup_ms`, doctor’s only Python warning is resolved by moving the uv pin, and clearing `mise.tools` restores legacy managers. Record any live step that cannot be completed rather than claiming it. Baseline before the change: the real overlay’s doctor reported only `startup budget exceeded: 905.2 ms (budget 500 ms)`.

## Review and live acceptance evidence

- Follow-up reviews are READY with no remaining findings. The final boundary check confirms empty tools preserve foreign user activation while prior module-owned activation still cleans up across off, empty-tools, module-disable, and missing-executable transitions.
- Inherited gvm `GOPATH`, overlay, and `GOROOT` state is cleared only when it points into gvm; custom `GOPATH` values remain unchanged.
- Real mise 2026.11.13 in a disposable HOME: agent and batch shells in a `.nvmrc` worktree selected Node 22.22.3 and Go 1.27.2 through shims, with Homebrew behind them. Interactive zsh and fish selected those versions through activation, retained shims after `cd .`, and had no mise prompt hook. `hook off` retained shims but removed activated tool paths and auxiliary state; empty tools restored real nvm/gvm paths; removing the executable restored nvm Node 24.19.0 and gvm Go 1.27.2.
- Live doctor with ownership enabled completed with 0 issues and measured interactive startup at 151.6 ms against the 500 ms budget.

## Self-review

- Spec coverage: decisions 1–6 map to Tasks 1–2; doctor/Day 2/migration map to Task 3; every Done-when item has either an automated behavior spec or the explicit live acceptance step.
- Interface consistency: all three shells use the same four tool names, shim path, option values, activation command names, and compatibility mappings.
- Scope: no nvm/gvm/pyenv removal, no full compatibility emulation, no gvm linking migration, no startup installation, and no provider/overlay changes in this repository.
