# DEV-62: mise for version management — evaluation and decision

Authority: MARKSHARC-SPEC sections 4.3, 6.4, 6.6, 6.7, 7.1, 10 and 12; MARKSHARC-PLAN L3.

The issue's scope changed from "mise or fnm" to a trial of mise, chosen for its multi-tool
support. fnm (Node only) was not evaluated. This is an evaluation: it changes no shell code.
The decision is recorded in the spec and the plan. The implementation is follow-up L6.

## Method

All measurements were taken on sol (Linux x86_64, zsh 5.9, marksharc at `a3b1522`), as the
median of 7–15 runs inside a pseudo-terminal, with the agent markers unset so the session class
was `interactive`. mise 2026.11.13 (Homebrew) ran with its data, config, cache and state
directories in a scratch directory, so the real `~/.config/mise`, `~/.nvm` and `~/.gvm` were
only read. A scratch overlay (`MARKSHARC_CONFIG`) with `module node-nvm off` and
`module go-gvm off` stood in for "the legacy modules stand aside", and `XDG_CACHE_HOME` pointed
at scratch, so the real cache was not touched.

## Cost of nvm and gvm today

| Case                                                                     | Time                       |
| ------------------------------------------------------------------------ | -------------------------- |
| `zsh -f -c exit`                                                         | 3 ms                       |
| Batch or agent shell (`zsh -c exit`)                                     | 64–69 ms                   |
| Interactive shell (`zsh -i -c exit`)                                     | 263 ms                     |
| node-nvm, go-gvm and python env + init, from the verbose trace           | about 3.5 ms in total      |
| First `nvm` call (sources `nvm.sh`)                                      | +118 ms                    |
| First `gvm` call (sources gvm)                                           | +730 ms                    |
| `cd` into a directory with `.nvmrc` (nvm load, `nvm version`, `nvm use`) | +1.9 s, in every new shell |
| `cd` into a directory with `go.mod` (gvm load, `gvm use`)                | +720 ms                    |

DEV-38 made both managers nearly free at startup. The cost is in use: the `.nvmrc` hook costs
about two seconds in each new pane or worktree, and the first `gvm` costs most of a second.

## mise findings

From the documentation (2026-11) and the trial:

- **Activation modes.** `mise activate zsh` adds a `precmd` and a `chpwd` hook that run
  `mise hook-env` and prepend the selected tools' `bin` directories. Shims (one directory of
  links to the `mise` binary) resolve the version from the current directory each time they
  run. `mise exec` serves scripts. bash and fish are supported natively, so one tool would serve
  the fish modules (DEV-58) in place of the `nvm.fish` plugin and the fish gvm functions.
- **Version files** are off until enabled per tool
  (`idiomatic_version_file_enable_tools`, or `MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS`):
  `.nvmrc` (with `lts/*` aliases), `.node-version`, `package.json`; `.go-version`, `go.mod`,
  `go.work`; `.python-version`; `.ruby-version` and `Gemfile`.
- **`go.mod` differs from the gvm hook.** mise reads a `toolchain goX.Y.Z` line, or an exact
  `go X.Y.Z`. A two-part `go 1.25` is a minimum and selects nothing, where the gvm hook switches
  to `go1.25`. With `GOTOOLCHAIN=auto` (the default, and set on sol) the `go` command already
  fetches a newer toolchain that a module requires, so the two-part case loses little.
- **Go environment.** mise sets `GOROOT` (`go.set_goroot`, default on), no longer manages
  `GOPATH`, and by default points `GOBIN` at each Go's own directory; `go.set_gobin=false` keeps
  `go install` writing to `~/go/bin`, which the `go` module already puts on PATH.
- **Migration.** `mise sync node --nvm` linked all six nvm Nodes, with runtime aliases
  (`installs/node/24`, `lts`, `latest`), and the global npm commands they hold (for example
  `bash-language-server`, `codegraph`) appeared as shims. `mise sync python --pyenv` exists. gvm
  has no sync: Go is linked with `mise link go@X <dir>` or reinstalled. Ruby installs from
  attested prebuilt binaries on macOS arm64 and Linux glibc, which covers what rvm did.
- **Unsafe defaults for this framework.** `not_found_auto_install` (default on) installs a tool
  when a command is not found, against spec 10 rule 4; `not_found_system_fallback` lets an
  unresolved shim run an unrelated system binary.
- **Project.** MIT, about 36k stars, a release every two to three days. Fast-moving: settings
  are deprecated and removed on a published schedule.

## Trial results

| Measurement                                                | Time                                               |
| ---------------------------------------------------------- | -------------------------------------------------- |
| `mise --version` (process floor)                           | 22 ms                                              |
| `mise activate zsh` (generating the init text; cacheable)  | 23 ms                                              |
| `mise hook-env` in a plain, `.nvmrc` or `go.mod` directory | 29–30 ms                                           |
| `precmd` hook with nothing changed                         | 18–23 ms per prompt                                |
| `precmd` hook with `MISE_HOOK_ENV_CHPWD_ONLY=1`            | about 27 ms per prompt: the hook still runs `mise` |
| `chpwd` hook, interactive, legacy modules off              | about 30 ms per `cd` (61 ms for a pair)            |
| `node --version`: direct / through the shim                | 5 ms / 33 ms                                       |
| `go version`: direct / through the shim                    | 8 ms / 32 ms                                       |
| `npx --version`: direct / through the shim                 | 97 ms / 126 ms                                     |

A shim adds about 27 ms to each call. A `cd` into a `.nvmrc` directory drops from about 1.9 s
to about 30 ms.

Correctness through shims (no activation, as an agent shell would run):

| Directory                          | node                            | go                                |
| ---------------------------------- | ------------------------------- | --------------------------------- |
| plain                              | v24.19.0 (global `node = "24"`) | go1.27.2                          |
| `.nvmrc` = `22`                    | v22.22.3                        | go1.27.2                          |
| `go.mod` with `go 1.25`            | v24.19.0                        | go1.27.2 (a floor, as documented) |
| `go.mod` with `toolchain go1.25.5` | v24.19.0                        | go1.25.5, `GOROOT` to match       |

Interplay with the framework:

- **Reload.** With activation in place, `marksharc reload` kept mise's directory at the head of
  PATH: the builder treats it as an inherited, unmanaged entry ahead of the managed block
  (spec 6.7), and the next `precmd` left it there.
- **Stale entries win (defect to design around).** `mise hook-env` does not prepend a tool
  directory whose resolved path is already on PATH. A Go linked from gvm resolves to
  `~/.gvm/gos/go1.27.2/bin`; when that directory was inherited from a parent shell behind
  Linuxbrew, Homebrew's `go` (1.27.4) won in the interactive shell while `GOROOT` named 1.27.2.
  Long-lived parents (a tmux or herdr server) carry such entries. The module must put mise's
  directory in the `manager` tier and drop legacy manager entries for tools it owns; real mise
  installs are preferred to `mise link`.
- **Directory-change-only activation.** `hook_env.chpwd_only` does not remove the per-prompt cost:
  the `precmd` hook still runs `mise`. Removing `_mise_hook_precmd` from `precmd_functions`
  after sourcing the activation does. Prompts then cost nothing, the `chpwd` hook still switches
  versions on `cd`, and `cd .` picks up an edited `.nvmrc` or `mise.toml` (zsh runs `chpwd` hooks for
  `cd .`; verified). Without the prompt hook, `mise shell node@22` and `mise use` take effect only at
  the next hook run, so the module wraps the activation's `mise` function to run `_mise_hook` after
  those commands.
- **`~/.python-version`.** sol has `~/.python-version` with uv's pin format
  `cpython-3.13-any-any-any`; mise read it as a Python request and reported it missing.
  Enabling Python version files needs a check against uv's pins.

## Decision

Operator decisions, 2026-11-24:

1. **Adopt mise as an opt-in module (approach A).** A new public `mise` module takes over the
   tools the overlay names, per host: `set mise.tools "node go python ruby"`. For each owned
   tool, `node-nvm`, `go-gvm` and the pyenv branch of `python` stand aside, in the way
   `history-native` stands aside for atuin. Without mise, or with the option empty, they run as
   today, which is the fallback. nvm, gvm and pyenv stay the public default. Rejected: a
   shims-only module (B), and replacing the legacy managers outright (C).
2. **Agent and batch shells use shims.** The shim directory goes in the `manager` tier in every
   session class, so an agent working in a worktree gets that project's version. The cost is
   about 27 ms per tool call.
3. **Interactive shells add cached activation** (`_ms_init_cached mise mise activate zsh`) for
   real `bin` directories, `mise shell` and `[env]`. **The hook runs on directory change only by
   default** (option `hook`, default `chpwd`; operator, after review of the per-prompt cost): the
   module removes mise's `precmd` hook, so prompts cost nothing and each `cd` costs about 30 ms. A
   wrapper refreshes after `mise shell`, `use` and similar commands. To pick up a config file edited
   by hand, run `cd .`. `hook prompt` keeps mise's own per-prompt hook; `hook off` uses shims only.
4. **Tools in scope:** node, go, python (replacing the pyenv fallback only; uv stays preferred)
   and ruby (new; no legacy module).
5. **Muscle memory:** thin `nvm` and `gvm` functions behind an option translate the common
   verbs to mise and print the mise equivalent for the rest. Full emulation is out of scope.
6. **Safe defaults** are module options exported as `MISE_*` variables, so configuration stays
   in the overlay: `not_found_auto_install=false`, `go.set_gobin=false`, and version files
   enabled for the owned tools.

## Follow-up

L6 in MARKSHARC-PLAN carries the implementation; its Linear issue is linked there. This
evaluation ran against `a3b1522`; since then explicit installers (P3.4) and the native fish modules
(DEV-58) have landed, so L6 covers a mise installer and the fish half of the module as well.

## Result

Evaluation complete; no shell code changed. Spec sections 4.3, 5, 6.7, 7.1 and 12 and plan
entries L3 and L6 record the outcome.
