# DEV-41 Repo Scaffold, Conventions, and CI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the `marksharc` repository ready to receive code: the spec 6.2 layout, docs skeleton, a pinned ShellSpec harness, a lint script, local `cwf` setup, and CI that is green on macOS and Ubuntu.

**Architecture:** Plain directories with `.gitkeep` placeholders for the code that P2.2 to P2.4 bring. The test harness is copied from `mark-desktop-files/tests/shell` with three changes: it lives at `tests/`, exports `MARKSHARC_ROOT` instead of `MDF_ROOT`, and refuses a ShellSpec other than the pinned version. One POSIX `tests/lint` script and one `tests/check` script are the single source of truth for what CI and a developer run.

**Tech Stack:** POSIX sh, zsh 5.9, fish 4.x, ShellSpec 0.28.1 (commit `90e48c950239f3b8a9fdfa3e869592872c77b981`), shellcheck, GitHub Actions (`macos-latest`, `ubuntu-latest`, `actions/checkout@v7`), `cwf`.

**Spec:** [MARKSHARC-PLAN.md](../../../specs/MARKSHARC-PLAN.md) P2.1/DEV-41 and [MARKSHARC-SPEC.md](../../../specs/MARKSHARC-SPEC.md) sections 6.2, 8 and 10.

## Global Constraints

- macOS and Linux are both supported in every PR. Native Windows is not a target.
- Every behaviour change ships with a spec. Tests use a temporary HOME and command stubs, never real services. Tests never install their runner.
- No agent configuration is committed (`AGENTS.md`, `CLAUDE.md`, `.claude/`, `.agents/`, `.omp/`, `.codex/`, `.cursor/`, `.cwf*`). The workflow tool is `cwf`, not `cwft`.
- Portable code contains no personal values. This PR adds no portable code; `specs/` is a verbatim copy of the design documents and is not portable code.
- Branch: `mark/dev-41-marksharc-p21-repo-scaffold-conventions-and-ci` (Linear's branch name).

## Decisions

- **`memory/`, not `memories/`.** Spec 6.2 names the directory `memories/` and labels it "common workflow conventions". The `cwf` memory tooling (`cwf ai memory index`, `new`, `retire`) is fixed to `memory/MEMORY.md`, and every other cwf repository uses `memory/`. The plan follows cwf so the workflow is usable (a Done-when item). The spec text is not edited here; P2.7 updates the spec's layout section to match what was built.
- **cwf renders are ignored, including `.vscode/` and `docs/COMMON-WORKFLOW.md`.** `cwf ai install` writes both outside the agent directories. They carry workflow settings and the author's tracker values, so they count as agent configuration.
- **Suites by shell.** `tests/spec/zsh/` runs with `--shell zsh`; `tests/spec/repo/` runs with `--shell sh` (dash on Ubuntu, bash-as-sh on macOS) and covers the harness and repository rules. The cross-shell contract suite arrives with P2.2.
- **Ubuntu fish comes from `ppa:fish-shell/release-4`**, because the Ubuntu archive ships fish 3.x and the tech stack is fish 4.x.

- **`When run`, not `When run command`, for repository scripts.** ShellSpec's `run command` looks the name up on PATH only (`shellspec_which`), so an absolute script path reports "not found". `run command` stays correct for PATH names such as `env` and `curl`.

## File Map

- Create `core/zsh/lib/.gitkeep`, `core/fish/lib/.gitkeep`, `core/bash/.gitkeep`, `core/cli/.gitkeep`, `modules/.gitkeep`, `templates/overlay/.gitkeep`: the spec 6.2 tree.
- Create `specs/MARKSHARC-SPEC.md`, `specs/MARKSHARC-PLAN.md`: verbatim copies from `mark-desktop-files/specs/`.
- Modify `README.md`; create `CHANGELOG.md`, `docs/DEVELOPING.md`, `tests/README.md`.
- Create `tests/run-tests`, `tests/.shellspec`, `tests/shellspec.pin`, `tests/spec/spec_helper.sh`, `tests/spec/support/fixtures.sh`, `tests/support/pty_socket.py`: the harness.
- Create `tests/spec/zsh/smoke_spec.sh`, `tests/spec/zsh/native_spec.sh`, `tests/spec/repo/runner_spec.sh`, `tests/spec/repo/lint_spec.sh`, `tests/spec/repo/hygiene_spec.sh`.
- Create `tests/lint`, `tests/check`.
- Rewrite `.gitignore`.
- Create `memory/MEMORY.md` (seeded by `cwf ai install`).
- Create `.github/workflows/ci.yml`.
- Local only, never committed: `.cwf-settings.yaml` and everything `cwf ai install` renders.

## Baseline

- `main` holds `LICENSE` (GPL-3.0), a two-line `README.md`, and a `.gitignore` that already lists the agent paths with `.claude/**`-style patterns.
- `mark-desktop-files` specs source commit: `78dfe8a78bda67e9a64c80afdca542242f0afaff`.
- `cwf status` warns that the cwf sentinel block is missing. `cwf ai install --dry-run` writes `.agents/`, `.claude/`, `.codex/`, `.cursor/`, `.omp/`, `.vscode/`, `AGENTS.md`, `GEMINI.md`, `docs/COMMON-WORKFLOW.md`, `.cwf-ai-manifest.json`, a cwf-ai `.gitignore` block, a `CLAUDE.md` memory region and `memory/MEMORY.md`. Its kernel adds `!.claude/hooks/` to `.gitignore`.
- Local tools: `/opt/homebrew/bin/shellspec` 0.28.1, shellcheck, fish 4.9.3, zsh 5.9, bash 5.3.
- shellcheck on the mdf harness reports SC1007 (`CDPATH= cd`), SC2016 (stub printf) and SC1090/SC1091 (sourcing). The copies below fix these.

---

### Task 1: Layout, docs skeleton, and specs

**Files:**
- Create: the six `.gitkeep` files, `specs/MARKSHARC-SPEC.md`, `specs/MARKSHARC-PLAN.md`, `CHANGELOG.md`, this plan
- Modify: `README.md`

**Interfaces:**
- Produces: the directory tree that P2.2 to P2.4 fill; `specs/` paths that the cwf `plan_docs` and `authority_docs` values point at.

- [ ] **Step 1: Branch**

```sh
git switch -c mark/dev-41-marksharc-p21-repo-scaffold-conventions-and-ci
```

- [ ] **Step 2: Create the tree and copy the specs**

```sh
for d in core/zsh/lib core/fish/lib core/bash core/cli modules templates/overlay; do mkdir -p "$d"; : > "$d/.gitkeep"; done
mkdir -p specs && cp ~/etc/mark-desktop-files/specs/MARKSHARC-SPEC.md ~/etc/mark-desktop-files/specs/MARKSHARC-PLAN.md specs/
```

- [ ] **Step 3: Write `README.md`**

```markdown
# marksharc

Mark's shell RC files, rebuilt for the modern, agentic era.

marksharc is a modular shell framework for **zsh** and **fish**, with the same
environment in **bash** for scripts and agents. Functional areas are modules.
Configuration lives in a separate overlay that you own, so the framework
checkout stays read-only on every host.

> **Status:** early development. This repository holds the scaffold, tests and
> CI. There is nothing to install yet; the installer arrives in a later release.

## Requirements

- macOS or Linux
- zsh 5.9 or later
- fish 4.x (optional)
- bash 5.x (environment only)
- git

Day-to-day shell use needs only the native shell. The `marksharc` command needs zsh.

## Layout

| Path | Contents |
| --- | --- |
| `core/` | Per-shell loaders (`zsh/`, `fish/`, `bash/`) and CLI commands (`cli/`) |
| `modules/` | Public modules, one directory each |
| `templates/overlay/` | Skeleton for a new `~/.config/marksharc` overlay |
| `tests/` | ShellSpec suites, lint and fixtures |
| `docs/` | User and developer documentation |
| `specs/` | Design specification and programme plan |
| `memory/` | Shared workflow memory notes |

## Documentation

- [Developing marksharc](docs/DEVELOPING.md)
- [Tests](tests/README.md)
- [Specification](specs/MARKSHARC-SPEC.md) and [plan](specs/MARKSHARC-PLAN.md)

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
```

- [ ] **Step 4: Write `CHANGELOG.md`**

```markdown
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
```

- [ ] **Step 5: Verify and commit**

Run: `cmp specs/MARKSHARC-SPEC.md ~/etc/mark-desktop-files/specs/MARKSHARC-SPEC.md && cmp specs/MARKSHARC-PLAN.md ~/etc/mark-desktop-files/specs/MARKSHARC-PLAN.md && git status --short`
Expected: no `cmp` output; the new files listed.

```sh
git add README.md CHANGELOG.md core modules templates specs docs/superpowers/plans
git commit -m "chore: scaffold repository layout and copy specs" -m "Specs copied from mark-desktop-files 78dfe8a78bda67e9a64c80afdca542242f0afaff." -m "Refs DEV-41"
```

### Task 2: Test harness with a pinned runner

**Files:**
- Create: `tests/run-tests`, `tests/.shellspec`, `tests/shellspec.pin`, `tests/spec/spec_helper.sh`, `tests/spec/support/fixtures.sh`, `tests/support/pty_socket.py`, `tests/spec/zsh/native_spec.sh`, `tests/spec/zsh/smoke_spec.sh`, `tests/spec/repo/runner_spec.sh`, `tests/README.md`

**Interfaces:**
- Produces: `tests/run-tests [shellspec args]` (exit 127 when ShellSpec is missing or not the pinned version); per-example env `TEST_ROOT`, `HOME`, `ZDOTDIR`, `OPLOG`, `XDG_{CONFIG,CACHE,DATA,STATE}_HOME`; suite env `MARKSHARC_ROOT`, `REAL_GIT`, `PYTHON`; helpers `stub_command NAME BODY`, `git_fixture [branch]`, `run_bounded CMD...`, `file_mode PATH`, `have_command`, `iecho`, `ierr`.

- [ ] **Step 1: Copy the harness, adapted for this repo**

```sh
mkdir -p tests/spec/support tests/spec/zsh tests/spec/repo tests/support
cp ~/etc/mark-desktop-files/tests/shell/support/pty_socket.py tests/support/
cp ~/etc/mark-desktop-files/tests/shell/spec/zsh/native_spec.sh tests/spec/zsh/
```

`tests/.shellspec`:

```text
--require spec_helper
```

`tests/spec/spec_helper.sh`:

```sh
# shellcheck shell=sh
# Loaded by ShellSpec (see tests/.shellspec) from the tests directory.
# shellcheck source=tests/spec/support/fixtures.sh
. ./spec/support/fixtures.sh
spec_helper_configure() {
  before_each fixture_setup
  after_each fixture_teardown
}
```

`tests/spec/support/fixtures.sh` (mdf's version with `MDF_ROOT` and `load_function` removed, a `stub_command` helper, `XDG_STATE_HOME`, and shellcheck fixes):

```sh
# shellcheck shell=sh
# Per-example sandbox: a temporary HOME with XDG dirs and ZDOTDIR, a stub bin
# directory first on PATH, and an operation log. Works under sh, bash and zsh.

# stub_command NAME BODY: install an executable NAME, first on PATH, that runs BODY under /bin/sh.
stub_command() {
  printf '#!/bin/sh\n%s\n' "$2" > "$TEST_ROOT/bin/$1"
  chmod +x "$TEST_ROOT/bin/$1"
}
fixture_setup() {
  TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/marksharc-case.XXXXXX")
  TEST_ROOT=$(CDPATH='' cd -- "$TEST_ROOT" && pwd -P)
  export TEST_ROOT HOME="$TEST_ROOT/home" ZDOTDIR="$TEST_ROOT/home/zsh" OPLOG="$TEST_ROOT/operations"
  export XDG_CONFIG_HOME="$HOME/config" XDG_CACHE_HOME="$HOME/cache" XDG_DATA_HOME="$HOME/data" XDG_STATE_HOME="$HOME/state"
  mkdir -p "$HOME" "$ZDOTDIR" "$TEST_ROOT/bin"
  : > "$OPLOG"
  # Only explicit fixture executables precede the basic OS command set.
  PATH="$TEST_ROOT/bin:/usr/bin:/bin:/usr/sbin:/sbin"; export PATH
  # Commands that reach the network, other hosts or real services fail loudly.
  for tool in curl wget sudo cwf ssh-agent ssh-add herdr collie codegraph brew gvm node npm; do
    # shellcheck disable=SC2016 # $* and $OPLOG expand when the stub runs
    stub_command "$tool" 'printf "FORBIDDEN %s\n" "'"$tool"' $*" >> "$OPLOG"; exit 99'
  done
  unset SSH_AUTH_SOCK SSH_AGENT_PID TMUX NVM_DIR BASH_ENV ENV HERDR_SOCKET_PATH HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_PANE_ID WEZTERM_PANE HC_TERMINAL_ID
}
fixture_teardown() { cd /; rm -rf -- "$TEST_ROOT"; }
iecho() { :; }
ierr() { printf '%s\n' "$*" >&2; }
have_command() { command -v "$1" >/dev/null 2>&1; }
# Real Git only operates on disposable fixtures; no real remote URLs are configured.
git_fixture() {
  "$REAL_GIT" init -q -b "${1:-main}" "$TEST_ROOT/base"
  cd "$TEST_ROOT/base" || return
  "$REAL_GIT" config user.email fixture@example.invalid
  "$REAL_GIT" config user.name Fixture
  printf '%s\n' 'node_modules/' > .gitignore
  printf '%s\n' retained > retained
  "$REAL_GIT" add .
  "$REAL_GIT" commit -qm initial
  "$REAL_GIT" worktree add -qb feature "$TEST_ROOT/worktree" >/dev/null
  cd "$TEST_ROOT/worktree" || return
}
run_bounded() {
  "$@" &
  bounded_child=$!
  (
    trap 'kill "$bounded_delay" 2>/dev/null; exit 0' TERM
    sleep 15 &
    bounded_delay=$!
    wait "$bounded_delay"
    kill -TERM "$bounded_child" 2>/dev/null
  ) &
  bounded_watch=$!
  wait "$bounded_child"
  bounded_result=$?
  kill -TERM "$bounded_watch" 2>/dev/null
  wait "$bounded_watch" 2>/dev/null
  return "$bounded_result"
}
file_mode() {
  case $(uname -s) in
    Darwin) stat -f %Lp "$1";;
    *) stat -c %a "$1";;
  esac
}
```

`tests/run-tests`, first as a straight copy (no version pin yet):

```sh
#!/bin/sh
# Run ShellSpec in a scrubbed environment with a throwaway HOME.
# Usage: tests/run-tests [shellspec options] [spec paths]
# Tests never install their runner: put the pinned ShellSpec (tests/shellspec.pin)
# on PATH or set SHELLSPEC_BIN to its executable.
set -eu
suite=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
runner=${SHELLSPEC_BIN:-$(command -v shellspec || :)}
if [ -z "$runner" ] || [ ! -x "$runner" ]; then
  echo "ShellSpec 0.28.1 required; install it or set SHELLSPEC_BIN to its executable." >&2
  exit 127
fi
runner=$(CDPATH='' cd -- "$(dirname -- "$runner")" && pwd)/$(basename -- "$runner")
workspace=$(mktemp -d "${TMPDIR:-/tmp}/marksharc-tests.XXXXXX")
trap 'rm -rf -- "$workspace"' EXIT
trap 'exit 130' HUP INT TERM
cd "$suite"
env -i PATH="$PATH" HOME="$workspace" \
  XDG_CONFIG_HOME="$workspace/config" XDG_CACHE_HOME="$workspace/cache" \
  XDG_DATA_HOME="$workspace/data" XDG_STATE_HOME="$workspace/state" \
  MARKSHARC_ROOT="$(CDPATH='' cd .. && pwd)" REAL_GIT="$(command -v git)" \
  PYTHON="$(command -v python3 || :)" TERM=dumb "$runner" "$@"
```

Run: `chmod +x tests/run-tests`

- [ ] **Step 2: Write the smoke spec**

`tests/spec/zsh/smoke_spec.sh`:

```sh
Describe 'test sandbox'
  It 'gives each example a temporary HOME and XDG directories'
    When call print -r -- "$HOME $XDG_CONFIG_HOME $XDG_STATE_HOME"
    The output should equal "$TEST_ROOT/home $TEST_ROOT/home/config $TEST_ROOT/home/state"
  End
  It 'puts fixture stubs first on PATH'
    When call command -v curl
    The output should equal "$TEST_ROOT/bin/curl"
  End
  It 'makes forbidden commands fail and record the attempt'
    When run command curl https://example.invalid
    The status should equal 99
    The contents of file "$OPLOG" should equal 'FORBIDDEN curl https://example.invalid'
  End
  It 'runs zsh 5.9 or later with no startup files'
    When run command zsh -dfc 'autoload -Uz is-at-least && is-at-least 5.9'
    The status should be success
  End
End
```

- [ ] **Step 3: Run the zsh suite**

Run: `tests/run-tests --shell zsh spec/zsh`
Expected: PASS, 6 examples (4 smoke, 2 native).

- [ ] **Step 4: Write the failing runner spec**

`tests/spec/repo/runner_spec.sh`:

```sh
Describe 'tests/run-tests'
  # fake_shellspec VERSION: a stand-in runner that reports VERSION and echoes what it was given.
  fake_shellspec() {
    mkdir -p "$TEST_ROOT/fake"
    cat > "$TEST_ROOT/fake/shellspec" <<EOF
#!/bin/sh
if [ "\$1" = --version ]; then echo $1; exit 0; fi
printf '%s\n' "home=\$HOME" "root=\$MARKSHARC_ROOT" "args=\$*" "leak=\${LEAK:-}"
[ -d "\$HOME" ] && echo home-exists
EOF
    chmod +x "$TEST_ROOT/fake/shellspec"
  }
  run_tests() { env LEAK=1 SHELLSPEC_BIN="$TEST_ROOT/fake/shellspec" "$MARKSHARC_ROOT/tests/run-tests" "$@"; }

  It 'refuses to run without ShellSpec'
    When run command env SHELLSPEC_BIN="$TEST_ROOT/missing" "$MARKSHARC_ROOT/tests/run-tests"
    The status should equal 127
    The stderr should include 'ShellSpec 0.28.1 required'
  End
  It 'refuses a ShellSpec other than the pinned version'
    fake_shellspec 0.27.0
    When run run_tests spec/zsh
    The status should equal 127
    The stderr should include "reports '0.27.0'"
  End
  It 'runs the pinned ShellSpec with a scrubbed environment and its own HOME'
    fake_shellspec 0.28.1
    When run run_tests --shell zsh spec/zsh
    The status should be success
    The line 2 of output should equal "root=$MARKSHARC_ROOT"
    The line 3 of output should equal 'args=--shell zsh spec/zsh'
    The line 4 of output should equal 'leak='
    The line 5 of output should equal 'home-exists'
    The line 1 of output should not equal "home=$HOME"
  End
  workspace_after_run() {
    fake_shellspec 0.28.1
    home=$(run_tests | sed -n 's/^home=//p')
    [ -n "$home" ] || { echo 'no home reported'; return 1; }
    if [ -e "$home" ]; then echo "left behind: $home"; else echo removed; fi
  }
  It 'removes its throwaway HOME afterwards'
    When call workspace_after_run
    The output should equal removed
  End
End
```

Run: `tests/run-tests --shell sh spec/repo/runner_spec.sh`
Expected: FAIL on "refuses a ShellSpec other than the pinned version" (the copy runs any version).

- [ ] **Step 5: Pin the runner**

`tests/shellspec.pin`:

```text
# ShellSpec pin for tests/run-tests and CI. One directive per line.
version 0.28.1
commit 90e48c950239f3b8a9fdfa3e869592872c77b981
source https://github.com/shellspec/shellspec.git
```

`tests/run-tests`, final:

```sh
#!/bin/sh
# Run ShellSpec in a scrubbed environment with a throwaway HOME.
# Usage: tests/run-tests [shellspec options] [spec paths]
# Tests never install their runner: put the pinned ShellSpec (tests/shellspec.pin)
# on PATH or set SHELLSPEC_BIN to its executable.
set -eu
suite=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
pinned=$(awk '$1 == "version" { print $2 }' "$suite/shellspec.pin")
runner=${SHELLSPEC_BIN:-$(command -v shellspec || :)}
if [ -z "$runner" ] || [ ! -x "$runner" ]; then
  echo "ShellSpec $pinned required; install it or set SHELLSPEC_BIN to its executable." >&2
  exit 127
fi
runner=$(CDPATH='' cd -- "$(dirname -- "$runner")" && pwd)/$(basename -- "$runner")
actual=$("$runner" --version 2>/dev/null || :)
if [ "$actual" != "$pinned" ]; then
  echo "ShellSpec $pinned required; $runner reports '${actual:-no version}'." >&2
  exit 127
fi
workspace=$(mktemp -d "${TMPDIR:-/tmp}/marksharc-tests.XXXXXX")
trap 'rm -rf -- "$workspace"' EXIT
trap 'exit 130' HUP INT TERM
cd "$suite"
env -i PATH="$PATH" HOME="$workspace" \
  XDG_CONFIG_HOME="$workspace/config" XDG_CACHE_HOME="$workspace/cache" \
  XDG_DATA_HOME="$workspace/data" XDG_STATE_HOME="$workspace/state" \
  MARKSHARC_ROOT="$(CDPATH='' cd .. && pwd)" REAL_GIT="$(command -v git)" \
  PYTHON="$(command -v python3 || :)" TERM=dumb "$runner" "$@"
```

- [ ] **Step 6: Run both suites**

Run: `tests/run-tests --shell zsh spec/zsh && tests/run-tests --shell sh spec/repo`
Expected: PASS (6 and 4 examples).

- [ ] **Step 7: Write `tests/README.md` and commit**

```markdown
# Tests

ShellSpec owns test cases and assertions. Every example runs in its own
temporary HOME, with XDG directories, a ZDOTDIR, executable stubs first on
PATH, and an operation log. Tests never install their runner, touch the real
HOME, or call real services.

## Run

```sh
tests/check                                   # everything CI runs
tests/lint                                    # zsh -n, shellcheck, fish --no-execute
tests/run-tests --shell zsh spec/zsh          # zsh units
tests/run-tests --shell sh spec/repo          # runner, lint and repository checks
SHELLSPEC_BIN=/path/to/shellspec tests/run-tests --shell zsh spec/zsh
```

`run-tests` requires the ShellSpec version in [`shellspec.pin`](shellspec.pin)
(0.28.1). Install it yourself, from Homebrew or a checkout of the pinned
commit, then put it on PATH or set `SHELLSPEC_BIN`. The wrapper finds the
runner before it replaces HOME, then starts it with an explicit environment:
`PATH`, a throwaway `HOME` and XDG directories, `MARKSHARC_ROOT` (this
checkout), `REAL_GIT`, `PYTHON` and `TERM=dumb`.

## Layout

| Path | Contents |
| --- | --- |
| `run-tests` | Runner wrapper: pinned-version check, scrubbed environment, throwaway HOME |
| `lint` | Static checks for every tracked or new shell file |
| `check` | Lint plus both suites, as CI runs them |
| `shellspec.pin` | ShellSpec version, commit and source used locally and in CI |
| `spec/spec_helper.sh`, `spec/support/fixtures.sh` | Per-example sandbox and shared helpers (`stub_command`, `git_fixture`, `run_bounded`, `file_mode`) |
| `support/pty_socket.py` | OS fixture support only: a PTY child supervisor and a Unix socket binder |
| `spec/zsh/` | Specs run with `--shell zsh` |
| `spec/repo/` | Specs run with `--shell sh`: the harness itself and repository rules |

## Contract inventory

Each row is a behaviour and the spec that exercises it. P2.8 (DEV-48) grows
this table to cover every module.

| Area | Behaviour | Spec |
| --- | --- | --- |
| Harness | Temporary HOME and XDG dirs; stubs first on PATH; forbidden commands fail and log | `spec/zsh/smoke_spec.sh` |
| Harness | zsh is 5.9 or later | `spec/zsh/smoke_spec.sh` |
| Harness | Native zsh arrays, options, scope and literal mock arguments | `spec/zsh/native_spec.sh` |
| Runner | Missing or wrong-version ShellSpec is refused; environment is scrubbed; throwaway HOME is removed | `spec/repo/runner_spec.sh` |
| Lint | Files routed by extension and shebang; every failure reported; missing checker named | `spec/repo/lint_spec.sh` |
| Repository | Agent configuration and cwf renders are ignored and untracked; the memory index is tracked | `spec/repo/hygiene_spec.sh` |
```

(The lint and hygiene rows refer to Tasks 3 and 4; they land in the same PR.)

```sh
git add tests
git commit -m "test: add pinned ShellSpec harness and smoke specs" -m "Harness copied from mark-desktop-files tests/shell at 78dfe8a." -m "Refs DEV-41"
```

### Task 3: Lint script

**Files:**
- Create: `tests/lint`, `tests/check`, `tests/spec/repo/lint_spec.sh`

**Interfaces:**
- Consumes: `stub_command`, `OPLOG`, `REAL_GIT`, `MARKSHARC_ROOT` from Task 2.
- Produces: `tests/lint [repo-root]`: exit 0 and `lint: ok (N files)` on stdout, or exit 1 with `lint: <path>: <reason>` lines on stderr. `tests/check`: lint plus both suites.

- [ ] **Step 1: Write the failing lint spec**

`tests/spec/repo/lint_spec.sh`:

```sh
Describe 'tests/lint'
  lint_tree() {
    tree="$TEST_ROOT/tree"
    "$REAL_GIT" init -q "$tree"
    mkdir -p "$tree/core" "$tree/tests/spec"
    printf 'print ok\n' > "$tree/core/a.zsh"
    printf 'echo ok\n' > "$tree/b.sh"
    printf 'echo ok\n' > "$tree/c.bash"
    printf 'echo ok\n' > "$tree/d.fish"
    printf '#!/usr/bin/env zsh\nprint ok\n' > "$tree/tool"
    printf '#!/bin/sh -e\necho ok\n' > "$tree/script"
    printf '#!/usr/bin/env python3\n' > "$tree/helper"
    printf "Describe 'x'\nEnd\n" > "$tree/tests/spec/x_spec.sh"
    printf '# notes\n' > "$tree/README.md"
    "$REAL_GIT" -C "$tree" add -A
  }
  # Each checker stub logs its arguments and fails for any path containing "bad".
  stub_checkers() {
    for checker in zsh shellcheck fish; do
      stub_command "$checker" 'printf "%s\n" "'"$checker"' $*" >> "$OPLOG"; case "$*" in *bad*) exit 1;; esac'
    done
  }
  BeforeEach 'lint_tree' 'stub_checkers'

  It 'routes each shell file to its checker by extension or shebang'
    When run "$MARKSHARC_ROOT/tests/lint" "$tree"
    The status should be success
    The output should equal 'lint: ok (6 files)'
    The contents of file "$OPLOG" should equal "shellcheck -x -s sh b.sh
shellcheck -x -s bash c.bash
zsh -n core/a.zsh
fish --no-execute d.fish
shellcheck -x -s sh script
zsh -n tool"
  End
  It 'checks every file and fails when any checker fails'
    printf 'x\n' > "$tree/bad.zsh"
    printf 'x\n' > "$tree/bad.sh"
    When run "$MARKSHARC_ROOT/tests/lint" "$tree"
    The status should equal 1
    The output should equal ''
    The stderr should include 'lint: bad.sh: shellcheck failed'
    The stderr should include 'lint: bad.zsh: zsh -n failed'
  End
  It 'fails and names a checker that is not installed'
    rm "$TEST_ROOT/bin/shellcheck"
    mkdir "$TEST_ROOT/minbin"
    ln -s "$REAL_GIT" "$TEST_ROOT/minbin/git"
    ln -s "$(command -v mktemp)" "$TEST_ROOT/minbin/mktemp"
    ln -s "$(command -v rm)" "$TEST_ROOT/minbin/rm"
    When run command env PATH="$TEST_ROOT/bin:$TEST_ROOT/minbin" "$MARKSHARC_ROOT/tests/lint" "$tree"
    The status should equal 1
    The stderr should include 'lint: b.sh: shellcheck is required but not found'
  End
End
```

Run: `tests/run-tests --shell sh spec/repo/lint_spec.sh`
Expected: FAIL, `tests/lint` not found.

- [ ] **Step 2: Write `tests/lint`**

```sh
#!/bin/sh
# Static checks for every shell file in the repository:
#   zsh -n for zsh, shellcheck for sh and bash, fish --no-execute for fish.
# Files are classified by extension, then by shebang. ShellSpec files
# (*_spec.sh) use the ShellSpec DSL; running the suite checks them.
# Usage: tests/lint [repo-root]   (default: this checkout)
set -eu
set -f
root=${1:-$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)}
cd "$root"

# kind_of FILE: print zsh, bash, fish or sh, or nothing for a file lint skips.
kind_of() {
  case $1 in
    *_spec.sh) return 0 ;;
    *.zsh) echo zsh; return 0 ;;
    *.bash) echo bash; return 0 ;;
    *.fish) echo fish; return 0 ;;
    *.sh) echo sh; return 0 ;;
  esac
  first=
  IFS= read -r first < "$1" || :
  case $first in '#!'*) ;; *) return 0 ;; esac
  # shellcheck disable=SC2086 # split the shebang line into words; globbing is off
  set -- ${first#??}
  interp=${1:-}
  interp=${interp##*/}
  if [ "$interp" = env ]; then interp=${2:-}; fi
  case $interp in zsh|bash|fish|sh) echo "$interp" ;; esac
}

status=0
count=0
failed() { echo "lint: $1: $2" >&2; status=1; }
need() { command -v "$1" >/dev/null 2>&1 || { failed "$2" "$1 is required but not found"; return 1; }; }

files=$(mktemp "${TMPDIR:-/tmp}/marksharc-lint.XXXXXX")
trap 'rm -f -- "$files"' EXIT
git ls-files --cached --others --exclude-standard > "$files"
while IFS= read -r f; do
  [ -f "$f" ] || continue
  kind=$(kind_of "$f")
  [ -n "$kind" ] || continue
  count=$((count + 1))
  case $kind in
    zsh) need zsh "$f" && { zsh -n "$f" < /dev/null || failed "$f" "zsh -n failed"; } ;;
    sh|bash) need shellcheck "$f" && { shellcheck -x -s "$kind" "$f" < /dev/null || failed "$f" "shellcheck failed"; } ;;
    fish) need fish "$f" && { fish --no-execute "$f" < /dev/null || failed "$f" "fish --no-execute failed"; } ;;
  esac
done < "$files"
if [ "$status" -eq 0 ]; then echo "lint: ok ($count files)"; fi
exit "$status"
```

Run: `chmod +x tests/lint`

- [ ] **Step 3: Run the lint spec, then lint the repo**

Run: `tests/run-tests --shell sh spec/repo/lint_spec.sh && tests/lint`
Expected: 3 examples pass; `lint: ok (N files)`. Fix any real shellcheck finding in the harness rather than disabling it; a disable needs a reason comment.

- [ ] **Step 4: Write `tests/check` and run it**

```sh
#!/bin/sh
# Run every check CI runs: lint, the zsh suite and the repository suite.
set -eu
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
"$here/lint"
"$here/run-tests" --shell zsh spec/zsh
"$here/run-tests" --shell sh spec/repo
```

Run: `chmod +x tests/check && tests/check`
Expected: lint ok, both suites pass.

- [ ] **Step 5: Commit**

```sh
git add tests
git commit -m "test: add shell lint and a single check entry point" -m "Refs DEV-41"
```

### Task 4: Ignore rules, cwf setup, and developer guide

**Files:**
- Modify: `.gitignore`
- Create: `tests/spec/repo/hygiene_spec.sh`, `docs/DEVELOPING.md`, `memory/MEMORY.md`
- Local only: `.cwf-settings.yaml`

**Interfaces:**
- Consumes: `REAL_GIT`, `MARKSHARC_ROOT` from Task 2.
- Produces: the ignore contract that later PRs rely on: rendered agent files never show in `git status`.

- [ ] **Step 1: Write the failing hygiene spec**

`tests/spec/repo/hygiene_spec.sh`:

```sh
Describe 'repository hygiene'
  ignored() { "$REAL_GIT" -C "$MARKSHARC_ROOT" check-ignore -q --no-index -- "$1"; }

  Parameters
    AGENTS.md
    CLAUDE.md
    GEMINI.md
    modules/example/CLAUDE.md
    .agents/skills/example/SKILL.md
    .claude/settings.json
    .claude/hooks/example.sh
    .codex/config.toml
    .cursor/rules/example.mdc
    .omp/example
    .cwf-settings.yaml
    .cwf-ai-manifest.json
    .cwf/ai/ext/example.md
    .vscode/settings.json
    docs/COMMON-WORKFLOW.md
    memory/local/example.md
  End
  It "ignores agent configuration: $1"
    When call ignored "$1"
    The status should be success
  End

  It 'keeps the shared memory index tracked'
    When call ignored memory/MEMORY.md
    The status should be failure
  End

  tracked_agent_config() {
    "$REAL_GIT" -C "$MARKSHARC_ROOT" ls-files |
      grep -E '(^|/)(AGENTS|CLAUDE|GEMINI)\.md$|^\.(agents|claude|codex|cursor|omp|vscode)/|^\.cwf|^docs/COMMON-WORKFLOW\.md$' || :
  }
  It 'tracks no agent configuration'
    When call tracked_agent_config
    The output should equal ''
  End
End
```

Run: `tests/run-tests --shell sh spec/repo/hygiene_spec.sh`
Expected: FAIL for `.vscode/settings.json`, `docs/COMMON-WORKFLOW.md` and `memory/local/example.md`.

- [ ] **Step 2: Rewrite `.gitignore`**

```text
# Editor droppings
**/*~
**/#*#

# OS droppings
.DS_Store
._*
.Spotlight-V100
.Trashes
ehthumbs.db
Thumbs.db

#BEGIN cwf
.cwf-settings-local.yaml
.common-state.json
.devcontainer/
.sandcat/
#END cwf

# Agent configuration and cwf renders stay out of the repository (spec 6.2).
# Keep this block last: git applies the last matching rule, and cwf's
# generated blocks above may re-include agent paths.
AGENTS.md
CLAUDE.md
GEMINI.md
KILO.md
WARP.md
.agents/
.claude/
.codex/
.cursor/
.omp/
.vscode/
.cwf*
docs/COMMON-WORKFLOW.md
memory/local/
```

Run: `tests/run-tests --shell sh spec/repo/hygiene_spec.sh`
Expected: PASS.

- [ ] **Step 3: Write `.cwf-settings.yaml` (local) and render**

Write the settings file from `docs/DEVELOPING.md` step 1 with the author's values: `github_org: markfrommn`, `linear_workspace: https://linear.app/psols`, `linear_mcp: linear-server-psols`, `linear_team: DEV`, project link `https://linear.app/psols/project/marksharc-3ff9057f0630`. If `cwf ai init --dry-run --force --profile preset/generic,cap/gha` shows extra required keys (such as `git.mode`), add them.

Run: `cwf ai install && git status --short --ignored`
Expected: new tracked candidates are only `memory/MEMORY.md` and `.gitignore`; every rendered agent path shows as ignored (`!!`).

- [ ] **Step 4: Keep the agent block last**

Open `.gitignore`. If cwf placed its cwf-ai block below the agent block, move the agent block back to the end. Leave cwf's own lines as written.

Run: `tests/run-tests --shell sh spec/repo/hygiene_spec.sh && cwf status && cwf ai status`
Expected: hygiene passes; `cwf status` shows no gitignore warning; `cwf ai status` reports no drift. Record any remaining cwf warning in the PR.

- [ ] **Step 5: Write `docs/DEVELOPING.md`**

```markdown
# Developing marksharc

## Tools

| Tool | Version | Used for |
| --- | --- | --- |
| zsh | 5.9+ | Core and CLI; the zsh suite |
| fish | 4.x | Fish lint now; the fish phase later |
| bash | 5.x | Environment parity later |
| ShellSpec | 0.28.1, pinned in `tests/shellspec.pin` | All specs |
| shellcheck | current | Lint for `sh` and `bash` files |
| git, python3 | any recent | Fixtures |

On macOS: `brew install fish shellcheck shellspec`, then check that
`shellspec --version` prints the pinned version. Elsewhere, or for an exact
pin, check out the commit in `tests/shellspec.pin` and point
`SHELLSPEC_BIN` at its `shellspec` script, as CI does.

## Checks

```sh
tests/check
```

This runs `tests/lint` and both suites, in the same order as CI. See
[tests/README.md](../tests/README.md) for single suites and the test rules.
CI runs on `macos-latest` and `ubuntu-latest` for every pull request and every
push to `main`; both must be green before a merge.

## Rules

- Every behaviour change ships with a spec. Specs use a temporary HOME and
  command stubs, never real services.
- Portable code (`core/`, `modules/`, `templates/`) holds no personal values:
  no user, host, org or site names, and no home paths.
- Shell startup is quiet, offline and makes no installs.
- The framework checkout is never written at run time.
- Agent configuration is never committed. `.gitignore` keeps `AGENTS.md`,
  `CLAUDE.md`, `.claude/`, `.agents/`, `.omp/`, `.codex/`, `.cursor/`,
  `.vscode/`, `.cwf*` and `docs/COMMON-WORKFLOW.md` out, and
  `tests/spec/repo/hygiene_spec.sh` checks it. Keep the agent block last in
  `.gitignore`.

The design rules are in section 10 of [the specification](../specs/MARKSHARC-SPEC.md).

## Branches, commits and pull requests

- One pull request per Linear issue. Name the branch after the issue, such as
  `<user>/dev-41-<slug>`.
- Use Conventional Commit subjects (`feat:`, `fix:`, `test:`, `docs:`, `chore:`, `ci:`).
- Add a line to `CHANGELOG.md` under `Unreleased` for user-visible changes.

## Workflow tooling (cwf), set up by hand

The `cwf` workflow tool renders agent definitions into a working copy. Its
settings file and everything it renders stay local; none of it is committed.

1. Write `.cwf-settings.yaml` at the repository root:

   ```yaml
   ai:
     profile:
       - preset/generic
       - cap/gha
     values:
       repo_display: marksharc
       plan_docs: specs/*-PLAN*.md
       authority_docs: specs/MARKSHARC-SPEC.md
       verify: "tests/check (lint, zsh suite, repository suite); CI runs the same on macOS and Ubuntu"
       test_stack: "ShellSpec 0.28.1 via tests/run-tests; tests/lint for zsh -n, shellcheck and fish --no-execute"
       ports: "n/a (shell framework, no server)"
       github_org: <github-org>
       linear_workspace: <linear-workspace-url>
       linear_mcp: <linear-mcp-server-name>
       linear_team: <linear-team-key>
       linear_projects:
         - "[MarkSharc](<linear-project-url>)"
   ```

2. Render the agent definitions:

   ```sh
   cwf ai install
   ```

   This writes `AGENTS.md`, `CLAUDE.md`, `.agents/`, `.claude/` and the other
   agent trees, `docs/COMMON-WORKFLOW.md`, and a cwf block in `.gitignore`. It
   seeds `memory/MEMORY.md` if it is missing.

3. Check the result:

   ```sh
   git status --short     # expect no new files; at most a moved .gitignore block
   cwf ai status          # render integrity
   cwf status             # repository checks
   ```

   If `cwf ai install` added or moved its block below the agent block in
   `.gitignore`, move the agent block back to the end, then run
   `tests/run-tests --shell sh spec/repo/hygiene_spec.sh`.

4. After a template or settings change, run `cwf ai refresh` and repeat step 3.

Memory notes live in `memory/`; `cwf ai memory new` writes one and
`cwf ai memory index` rebuilds `memory/MEMORY.md`. `memory/local/` is ignored.
```

- [ ] **Step 6: Run everything and commit**

Run: `tests/check`
Expected: PASS.

```sh
git add .gitignore docs/DEVELOPING.md memory/MEMORY.md tests/spec/repo/hygiene_spec.sh
git commit -m "chore: ignore agent configuration and document cwf setup" -m "Refs DEV-41"
```

### Task 5: CI on macOS and Ubuntu

**Files:**
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: `tests/shellspec.pin` (`commit`, `source`), `tests/lint`, `tests/run-tests`.

- [ ] **Step 1: Write the workflow**

```yaml
name: CI

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read

concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

jobs:
  check:
    name: check (${{ matrix.os }})
    strategy:
      fail-fast: false
      matrix:
        os: [macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v7

      - name: Install shells and linters (Ubuntu)
        if: runner.os == 'Linux'
        run: |
          sudo add-apt-repository -y ppa:fish-shell/release-4
          sudo apt-get update -q
          sudo apt-get install -y -q zsh fish shellcheck

      - name: Install shells and linters (macOS)
        if: runner.os == 'macOS'
        run: brew install fish shellcheck

      - name: Install pinned ShellSpec
        run: |
          commit=$(awk '$1 == "commit" { print $2 }' tests/shellspec.pin)
          source=$(awk '$1 == "source" { print $2 }' tests/shellspec.pin)
          dir="$RUNNER_TEMP/shellspec"
          git init -q "$dir"
          git -C "$dir" fetch -q --depth 1 "$source" "$commit"
          git -C "$dir" checkout -q FETCH_HEAD
          echo "SHELLSPEC_BIN=$dir/shellspec" >> "$GITHUB_ENV"

      - name: Tool versions
        run: |
          zsh --version
          fish --version
          bash --version | head -n 1
          shellcheck --version | sed -n 2p
          "$SHELLSPEC_BIN" --version

      - name: Lint
        run: tests/lint

      - name: zsh suite
        run: tests/run-tests --shell zsh spec/zsh

      - name: Repository suite
        run: tests/run-tests --shell sh spec/repo
```

- [ ] **Step 2: Check the pin is fetchable the way CI fetches it**

Run (in a scratch dir): `git init -q s && git -C s fetch -q --depth 1 https://github.com/shellspec/shellspec.git 90e48c950239f3b8a9fdfa3e869592872c77b981 && git -C s checkout -q FETCH_HEAD && s/shellspec --version`
Expected: `0.28.1`.

- [ ] **Step 3: Lint, commit, push, open the PR**

Run: `tests/check`

```sh
git add .github/workflows/ci.yml
git commit -m "ci: run lint and suites on macOS and Ubuntu" -m "Refs DEV-41"
git push -u origin HEAD
gh pr create --title "DEV-41: repo scaffold, conventions, and CI" --body-file <body>
```

- [ ] **Step 4: Watch CI and fix what Linux exposes**

Run: `gh pr checks --watch`
Expected: `check (macos-latest)` and `check (ubuntu-latest)` both pass. For each failure, reproduce locally if possible (for dash, run `tests/run-tests --shell dash spec/repo` when dash is installed), fix, add a spec when the fix is a behaviour change, and push.

## Done when

- [ ] CI is green on macOS and Ubuntu for the PR.
- [ ] `cwf status` and `cwf ai status` are clean and `git status` shows no rendered agent files.
- [ ] DEV-41 is In Review with the PR linked. Merging is the user's call.
