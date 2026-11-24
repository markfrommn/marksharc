# DEV-54 — Interactive UX enhancements implementation plan

> **For agentic workers:** Implement task by task with failing behaviour specs first. Keep the work on the DEV-54 branch; phase-lite owns the final save and share steps.

**Goal:** Add the modern interactive layer for zsh (P3.6): pinned autosuggestion and syntax-highlighting plugins, procs-backed ps helpers, a `theme` module for one colour baseline, and starship config selection with a bundled rich preset. Fish gets the theme, ps and starship parts natively.

**Authority:** `specs/MARKSHARC-SPEC.md` §§ 4.2, 6.4, 6.5, 6.8, 6.9, 6.10, 7.1, 8, 10; `specs/MARKSHARC-PLAN.md` P3.6.

## Global constraints

- Startup stays quiet and offline. Plugins load only from existing pins in the XDG cache, and `zsh-plugin-update`, `install.sh` and `marksharc sync` clone them.
- A missing tool means the native behaviour: no procs means the native `ps` helpers, no vivid means `LS_COLORS` is left alone, no bat means no `MANPAGER`, and no delta means no git include.
- Bare `ls` and `ps` are never redefined. The `ls` family is already eza-backed through `alias … when command eza` directives (DEV-49); this unit adds specs only.
- File-scope declarations say `-g`; every module is safe to source twice and to reload.
- Public modules hold no personal values. Every new behaviour that a user might not want has an option.

## Decisions

1. **Plugin loading is shared through a core helper.** `_ms_plugins_load <module>` (core/zsh/lib/modules.zsh) reads a module's `zsh.plugins` registry and calls `zsh-plugin-load` for each pin. It autoloads the loader from `modules/completion-fzf-tab/functions/zsh` when that module is disabled, so the new plugin modules do not depend on fzf-tab being enabled. `completion-fzf-tab` uses the same helper. Registries stay per module, so `zsh-plugin-update`, `install.sh`, `sync` and `doctor` pick the new pins up with no change.
2. **Load order (spec 6.4 bands).** `completion` 70 → `completion-fzf-tab` 71 → `history-atuin` 81 → `prompt-starship` 82 → … → `zsh-autosuggestions` 95 → `zsh-syntax-highlighting` 99, last. fzf-tab must load after compinit and before widget wrappers; atuin's widgets must exist before autosuggestions binds; syntax highlighting must be sourced last.
3. **Atuin interplay.** zsh-autosuggestions gets an `atuin` strategy (`atuin search --cmd-only --limit 1 --search-mode prefix`) defined only when atuin is installed. The default strategy is `atuin history completion`; strategies without a function are dropped, so a host without atuin uses `history completion`. Suggestions are fetched asynchronously (`ZSH_AUTOSUGGEST_USE_ASYNC`), atuin's search widgets clear the suggestion, and `ZSH_AUTOSUGGEST_MANUAL_REBIND` avoids rebinding at every prompt.
4. **procs backs display, not selection.** The ps helpers still select processes with `ps` and the same regular expression. With procs installed and `ps.procs` on, the selected PIDs are shown by `procs` (numeric keywords match a PID exactly); the job view inserts `Ppid`, `Pgid` and `State`. `pss` and `psj` with no pattern call `procs` directly. This keeps one meaning for scope and pattern whichever backend draws the table.
5. **Cached value init.** `_ms_init_cached -x <NAME>` (zsh) and `_ms_fish_init_cached -x <NAME>` (fish) cache a tool's output as an export of NAME rather than as a script. `theme` uses it for `vivid generate <theme>`, so a cache hit forks nothing.
6. **theme module, order 21** (before `completion` reads `LS_COLORS` for `list-colors`). Options: `ls_colors` (vivid theme name, default `molokai`, `off` to skip), `man_pager` (`bat` or `off`), `bat_theme` (empty), `delta` (`off`), `fzf` (`on`). Delta is opt-in: when on and delta is installed, the module adds an `include.path` to its `delta.gitconfig` through `GIT_CONFIG_COUNT`, appending to any entries already present and removing only its own on reload. fzf gets `FZF_DEFAULT_COMMAND` (fd, then rg, then ag), `FZF_DEFAULT_OPTS`, Ctrl-T and Alt-C previews (bat and eza when present), and fzf-tab preview zstyles.
7. **Starship.** `prompt-starship.config` names either a file (exported as `STARSHIP_CONFIG` when readable) or a bundled preset in `modules/prompt-starship/presets/`. The bundled `rich` preset keeps the left prompt short and moves context to `right_format`, with `cmd_duration`, `status`, `jobs`, `shlvl` and `sudo`, and a `command_timeout`. Empty keeps starship's own lookup, so the author's `~/.config/starship.toml` is unchanged.
8. **Packages.** Plugins come from pins, not packages. The modules declare the tools they use: `eza` (ls), `procs` (ps), `starship` (prompt-starship), and `vivid`, `bat`, `git-delta`, `fzf`, `fd` (theme), so `marksharc bootstrap` installs them.

## Tasks

### Task 1: Plugin modules and load order
- [x] Specs: the plugin load-order spec (orders, last-module rule, sourced order with stub clones, missing clone silent, reload does not re-source); autosuggestion strategy filtering and atuin widget clearing; highlighters option.
- [x] Implement `_ms_plugins_load`, refactor `completion-fzf-tab/init.zsh`, add `modules/zsh-autosuggestions` and `modules/zsh-syntax-highlighting`.

### Task 2: procs-backed ps helpers (zsh and fish)
- [x] Specs: procs missing means native output and args; procs present receives the selected PIDs; job columns; no pattern; `ps.procs off`; bare `ps` untouched.
- [x] Implement in `_ms_ps` (zsh) and `_ms_ps` (fish); add the option and package.

### Task 3: theme module and cached value init
- [x] Specs: `-x` caching (hit forks nothing); vivid present/missing/off; MANPAGER with bat, batcat, none; delta off by default, on with and without delta, append and reload removal; fzf command preference and previews; reload and double source.
- [x] Implement zsh and fish `init`, `delta.gitconfig`, the fzf-tab `FZF_DEFAULT_COMMAND` precedence change. The fish cache writes `true` after a cached `set -gx`, because fish's `set` keeps the previous status and a hit would otherwise report failure.

### Task 4: starship config selection
- [x] Specs: empty option leaves `STARSHIP_CONFIG`; preset name; file path; missing file ignored; fish parity.
- [x] Implement options and the `rich` preset.

### Task 5: Docs and gates
- [x] Update README module list, `templates/overlay/config.conf`, `tests/README.md` inventory, `CHANGELOG.md`, spec 7.1 rows and the plan outcome.
- [x] `tests/check`; live check on sol: plugins cloned, interactive startup measured against the 500 ms doctor budget.

## Outcome

Implemented as planned. `tests/check` passed: lint (204 files), every zsh, contract, install and repository example, and 621 fish assertions. The existing band and init-order specs now reserve 95–99 for the line-editor plugins and expect `zsh-syntax-highlighting` as the last init.

Live check on sol, using a scratch overlay, cache and state that point at the worktree (docs/DEVELOPING.md): `zsh-plugin-update` cloned both pins. An interactive shell loaded fzf-tab, zsh-autosuggestions (strategy `atuin,history,completion`) and zsh-syntax-highlighting last. Typing `git sta` drew `git` in green with atuin's grey suggestion `tus --short --branch`, and an unknown command was drawn in bold red. `LS_COLORS` came from vivid, `MANPAGER` was bat, `FZF_DEFAULT_COMMAND` used fd, `ll` expanded to `eza -lA` with bare `ls` and `ps` untouched, and `pss` was drawn by procs. Startup over 15 PTY runs, with the three new modules on and then off: median 331 and 327 ms on, 297 and 295 ms off, so about 33 ms added. Warm `marksharc doctor` reported 302–353 ms against the 500 ms budget; the first run after a config change (render and compinit rebuild) took 1.2 s with or without the new modules.

Hosts pick the modules up by default: the author's overlay has no explicit module list. Each host needs `marksharc update` to clone the two pins and `marksharc bootstrap` (or Homebrew) for procs and vivid; sol has both installed.
