# Fish

Fish runs on the same structure as zsh. The installer writes
`~/.config/fish/conf.d/00-marksharc.fish`, which sources `core/fish/marksharc.fish`. That
applies the rendered environment in every session and, in an interactive session, runs each
enabled module's fish setup in module order:

- `modules/<name>/init.fish` for hooks, key bindings, cached tool init and greetings;
- `modules/<name>/functions/fish/<fn>.fish` on `fish_function_path` (autoloaded);
- `modules/<name>/completions/fish/<cmd>.fish` on `fish_complete_path`;
- pinned plugins from `fish.plugins` (nvm.fish, fzf.fish) from the cache.

Tool integrations (starship, atuin, zoxide, direnv, pyenv, cwf, herdr, brew) go through
`_ms_fish_init_cached`, the fish port of the zsh init cache: a warm start forks none of them.
Write-once commands that change the calling shell (`cwf-new`, `gwt-clean`, `setup-ssh-agent`)
are fish wrappers over the directive applier. Fish's own welcome text is off unless you set
`fish_greeting`; the `greeting` module owns any greeting.

## Parity

Every module in `modules/`. *Supported* means the module does the same job in fish.
*Native-equivalent* means fish's own feature, or a fish-native implementation of it, gives the
same capability in a different way. *Not applicable* means the module has no meaning in fish.

| Module | Fish | Notes |
| --- | --- | --- |
| agent | supported | Agent markers classify the fish session; agent and batch startup are silent. |
| brew | supported | Brew directories by tier; cached `brew shellenv fish`, existing PATH order kept. |
| bun | supported | `BUN_INSTALL` and the user-tier path; bun installs its own fish completion. |
| cc-providers | supported | Provider wrappers are shims on PATH. |
| cloud | supported | Installers run from any shell. |
| command-not-found | native-equivalent | fish's native handler (apt and similar); Homebrew's `handler.fish` when present. |
| completion | native-equivalent | fish's native completion; modules add `completions/fish` and `marksharc` completes its subcommands. |
| completion-fzf-tab | not applicable | zsh line-editor plugin; fish uses `fzf-fish`. |
| cuda | supported | App-tier path and env. |
| cwf | supported | Hook registries, cached `cwf shell fish`, `cwf-new` wrapper and branch completion. |
| direnv | supported | Cached `direnv hook fish`, opt-in with `set direnv.enable on`. |
| docker | supported | Helpers on PATH; `claude-yolo` inside SANDCAT containers. |
| editor | supported | `EDITOR` from the option, else `emacs -nw`, else `vi`. |
| fish-bridge | not applicable | `run-fish` starts fish from zsh. |
| fzf-fish | supported | Pinned fzf.fish plugin. |
| git-worktree | supported | `gwt-clean` wrapper with pre-remove hooks, `git-managed`, `git-unmanaged`; `repo-sync` on PATH. |
| go | supported | `GOPATH` bin directories in the user tier. |
| go-gvm | native-equivalent | Go on PATH and `GOROOT` from the env phase; native `gvm use` and the `go.mod` hook; other `gvm` subcommands run under bash. Replaces fish-gvm and bass. |
| greeting | supported | `fortune` once per shell when enabled, never on reload. |
| herdr | supported | Session shims on PATH; cached `herdr completion fish`. |
| history-atuin | native-equivalent | Cached atuin init, `history`, `history -N` and `h` over atuin. Fish keeps its own history file because autosuggestions read it. |
| history-native | native-equivalent | fish's own history; `h` lists the last 35 entries when atuin is absent. |
| lmstudio | supported | Path and env. |
| ls | supported | `ll`, `la`, `dir`, `lf`, `lsf` (eza when installed) over fish's coloured `ls`. |
| mise | supported | Owned-tool shims in every session class; cached directory-change-only activation and optional compatibility functions in interactive fish. |
| mux | supported | `fix-tmux` re-imports the tmux client environment as data. |
| nav | native-equivalent | Alt-Left/Right are fish's `prevd`/`nextd`; Alt-Up/Down go to the parent and first child on an empty line. zsh's Ctrl-Shift-arrow directory-stack cycling is not ported; fish's `dirh`, `cdh` and `prevd`/`nextd` cover the stack. |
| node-nvm | native-equivalent | Default node on PATH from the env phase; the `.nvmrc` hook asks bash nvm in `$NVM_DIR`. Fish's fallback `nvm` command is the nvm.fish plugin, which keeps its own Node store (`~/.local/share/nvm`); when mise owns node, both the hook and plugin stand aside. |
| pager | supported | `PAGER`, `LESS`, `MANPATH`, coloured `man`, coloured `diff`, `diffcp`. |
| path | supported | Same tiers and order as zsh. |
| pnpm | supported | `PNPM_HOME` and path. |
| prompt-starship | supported | Cached `starship init fish`; `prompt-starship.config` selects a file or the bundled `rich` preset. |
| ps | supported | `pss`, `pssj`, `psj`, `pssu`, `pssuj`, `psuj`, `psju` over one implementation.; procs draws the selection when installed (`ps.procs`). |
| python | supported | uv preferred; else pyenv shims and cached `pyenv init - fish`. |
| rust | supported | Cargo bin in the user tier. |
| ssh-agent | supported | `setup-ssh-agent` once per shell; `clean-ssh-agents` on PATH. |
| theme | supported | Cached vivid `LS_COLORS`, bat man pager, opt-in delta include, fzf defaults and previews (fzf.fish directory preview with eza). |
| titles | supported | PWD hook, `chdir-set-title`, `set-title`; `fish_title` prints nothing so the tab title stands. |
| wezterm | supported | Terminfo installer runs from any shell. |
| x11 | supported | `setup-x11-display`, silent at startup. |
| zoxide | supported | Cached `zoxide init fish`. |
| zsh-options | not applicable | zsh `setopt` set. |
| zsh-autosuggestions | native-equivalent | fish suggests from its own history natively. |
| zsh-syntax-highlighting | native-equivalent | fish highlights the command line natively. |

## Writing fish module code

- `init.fish` is sourced inside a function: use `set -g`/`set -gx` for anything that must persist,
  and define event handlers (`--on-variable PWD`) there, not in autoload files.
- Call `_ms_fish_track_functions NAME` before defining a function over one of fish's own (`fish_title`,
  `man`, `history`), so a reload that disables the module can put fish's back.
- Never `functions -e` a name you expect to autoload later: fish then refuses to autoload it for
  the rest of the session. Fish may also embed its functions in the binary, so copy fish's
  function (`functions -c`) rather than sourcing `$__fish_data_dir/functions/*.fish`.
- Fish has no `$prefix_$var` indirection; use `set -l name prefix_$var` and `$name`.
- Test PATHs keep `/bin` (macOS has `bash` and `cat` only there) and use `touch -t`, not `touch -d`.
- fishtape skips, without counting, an `@test` whose expression errors; `run-fish-units` therefore
  fails on any fish error in its output.

## Retiring the old fish configuration

The old configuration (`config/fish` in mark-desktop-files) and fisher are no longer needed.
On each host:

1. Install or update marksharc so `conf.d/00-marksharc.fish` exists, then run `marksharc update`
   to fetch the pinned fish plugins.
2. Run `marksharc doctor`. It lists every line of a foreign `~/.config/fish/config.fish`, including a
   link to the old `config.fish`, and reports fisher leftovers (`fish_plugins`, `functions/fisher.fish`).
   Move anything still wanted into an overlay module or `local/post.fish`.
3. Remove the old `config.fish` link, `fish_plugins` and the plugin files fisher installed into
   `~/.config/fish/{functions,completions,conf.d}` (fisher, nvm.fish, fzf.fish, bass, fish-gvm).
4. Start a new fish and check `marksharc reload --verbose`.

## Tests

Fish units use fishtape 3.0.1 (pinned in `tests/fishtape.pin`) through `tests/run-fish-units`.
Each module's units are in `modules/<name>/tests/<name>_test.fish`; core units are in `tests/fish/`.
The cross-shell contract suite covers startup, environment parity, reload and plugin loading.

`config/fish/tests/test_parity.py` is replaced as follows:

| test_parity.py case | Now covered by |
| --- | --- |
| syntax | `tests/lint` (`fish --no-execute`, `fish_indent --check`) |
| quiet startup and reload | `spec/contract/fish_render_spec.sh` |
| path with system go and spaces | `spec/contract/fish_render_spec.sh` (tiered PATH builder) |
| tmux native set and unset | `modules/mux/tests/mux_test.fish` |
| private tmp parents, no ssh skips agent, ssh state is separate and quiet, stale agent socket, agent cleanup without pid | `modules/ssh-agent/tests/agents_spec.sh`, `modules/ssh-agent/tests/ssh-agent_test.fish` |
| krew failure preserves cwd | `modules/cloud/tests/cloud_spec.sh` |
| runfish spellings | `modules/fish-bridge/tests/fish_bridge_spec.sh` |
| node switch, install, default and failure; system default; upstream nvm switch and restore | `modules/node-nvm/tests/node-nvm_test.fish` |
| herdr names, arguments and reload | `modules/herdr/tests/herdr_spec.sh`, `modules/herdr/tests/herdr_test.fish` |
| providers scoped exports and stale cleanup | `modules/cc-providers/tests/shims_spec.sh` |
| cwf rejects base and creation failure; core-platform setup and unmanaged copy | `modules/cwf/tests/cwf_spec.sh`, `modules/cwf/tests/cwf_test.fish`, `spec/contract/fish_directives_spec.sh` |
| git classification; git paths are literal | `modules/git-worktree/tests/git-worktree_test.fish` |
| cleanup refuses before mutation; never walks external symlinks; base branch and pull failure | `modules/git-worktree/tests/cleanup_spec.sh`, `modules/git-worktree/tests/repo_sync_spec.sh` |
| titles detached, no remote and spaces; optional window and combined values | `modules/titles/tests/titles_test.fish` |
| interactive aliases and reload hooks | `spec/contract/fish_render_spec.sh`, module units |
| gvm wins and universal paths survive | `spec/contract/fish_render_spec.sh`, `modules/go-gvm/tests/go-gvm_test.fish` |
| hook init failure retries | `tests/fish/cache_test.fish` (a failing tool caches nothing) |
| mdf-sync propagates failure without chdir | `spec/zsh/sync_spec.sh` |
| terminal modes and fortune once | `spec/contract/fish_render_spec.sh`, `modules/greeting/tests/greeting_test.fish` |
| docker multiple containers | `modules/docker/tests/docker_spec.sh`, `modules/docker/tests/docker_test.fish` |
| x11 probe deadline | `modules/x11/tests/x11_spec.sh`, `modules/x11/tests/x11_test.fish` (no probe remains) |
