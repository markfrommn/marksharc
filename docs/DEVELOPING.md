# Developing marksharc

Start here if you want to change marksharc or add a module. The pages below go deeper; read the
one your task needs.

| Page | Read it when |
| --- | --- |
| [ARCHITECTURE.md](ARCHITECTURE.md) | You are changing the core, or need to know what happens at startup, render or reload |
| [MODULE-AUTHORING.md](MODULE-AUTHORING.md) | You are writing or changing a module |
| [CONFIGURATION.md](CONFIGURATION.md) | You need the directive format that `module.conf` and the overlay share |
| [DESIGN-RULES.md](DESIGN-RULES.md) | You want the reasoning behind a rule, or think you need an exception |
| [tests/README.md](../tests/README.md) | You are writing or running tests |
| [write-once.md](write-once.md) | Your command must change the shell that calls it |
| [completions.md](completions.md) | You are adding a completion |
| [MUX-ADAPTERS.md](MUX-ADAPTERS.md) | You are adding a multiplexer |
| [fish.md](fish.md) | You are writing fish module code |

The [specification](../specs/MARKSHARC-SPEC.md) is the contract. When a page here disagrees
with it, the specification is right and the page needs a fix.

## Tools

| Tool | Version | Used for |
| --- | --- | --- |
| zsh | 5.9+ | Core and CLI; the zsh suite |
| fish | 4.x | Fish loader and cross-shell contracts, `fish --no-execute` and `fish_indent --check` |
| bash | 5.x | Environment parity and contract suite |
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

This runs `tests/lint` and every suite, in the same order as CI (including the
contract-inventory check in `tests/spec/repo/inventory_spec.sh`). See
[tests/README.md](../tests/README.md) for single suites, the contract inventory
and the test rules. Run `tests/bench-startup` for an advisory batch and PTY
interactive startup-time check in a throwaway HOME.
CI runs on `macos-latest` and `ubuntu-latest` for every pull request and every
push to `main`; both must be green before a merge.

## Documentation

`docs/MODULES.md` is generated. After adding, removing or changing a module, regenerate it:

```sh
tests/support/gen-module-reference
```

`tests/spec/repo/docs_spec.sh` fails when that page is out of date, and when a relative link
in `README.md`, `docs/` or `specs/` points at a file or heading that does not exist. It runs in
`tests/check`. The main CI workflow skips Markdown-only changes, so a separate `Docs` workflow
runs this one spec for them.

To check that the README alone is enough to install on a clean machine:

```sh
tests/e2e/readme-container.sh                        # this working tree, in a fresh container
tests/e2e/readme-container.sh --source github-clone  # the README's commands as published
```

It needs Docker and is not part of CI.

Write user-facing pages for someone who has never seen marksharc. Keep examples free of
personal values, as in code. The issue tracker is private, so do not link to it from `README.md`
or `docs/`; cite an issue key as plain text where it helps.

## Measuring a live shell

The test suites run in a temporary HOME. To time a real host's startup, or to
try a tool against it, use a live shell. Three things make a measurement from
inside an agent or a script go wrong:

- **Agent markers change the session class.** A shell started from an agent
  inherits markers such as `CLAUDECODE`, so it runs as `agent` and skips the
  init phase (spec 6.6). Unset every variable in the `agent.markers` option
  first.
- **`interactive` needs a terminal on stdin and stdout.** Redirecting stdout
  to `/dev/null` or a file makes the shell `batch`. Run it under a
  pseudo-terminal and send its output to `/dev/tty`, and write the results to
  a file instead:

  ```sh
  # Linux; on macOS: script -q /dev/null zsh -f bench.zsh
  script -qec 'zsh -f bench.zsh' /dev/null
  ```

  Inside `bench.zsh`, start each shell as
  `zsh -i -c exit </dev/tty >/dev/tty`, time it with `$EPOCHREALTIME`, and
  set `MARKSHARC_ENV=` so every run rebuilds the environment. Confirm the
  class once with `echo $MARKSHARC_SESSION`.
- **Trials must not touch the real overlay or cache.** Point `MARKSHARC_CONFIG`
  at a scratch overlay and `XDG_CACHE_HOME` at a scratch cache. The scratch
  overlay links every entry of the real one except `config.conf`, which is a
  copy you can change, for example with `module node-nvm off`. Give the tool
  under trial scratch directories of its own as well.

`MARKSHARC_VERBOSE=1` prints each module's env and init time.
`specs/DEV-62-PLAN.md` gives an example of the method and its results.

## Rules

- Every behaviour change ships with a spec. Specs use a temporary HOME and
  command stubs, never real services.
- Portable code (`core/`, `modules/`, `templates/`) holds no personal values:
  no user, host, org or site names, and no home paths.
- Shell startup makes no installs or pulls. Eligible interactive shells may start the
  detached, throttled notify fetch and print a cached behind notice; batch and agent
  startup stays quiet and offline. Tests disable notify unless explicitly exercising it.
- The framework checkout is never written at run time.
- Agent configuration is never committed. `.gitignore` keeps `AGENTS.md`,
  `CLAUDE.md`, `.claude/`, `.agents/`, `.omp/`, `.codex/`, `.cursor/`,
  `.vscode/`, `.cwf*` and `docs/COMMON-WORKFLOW.md` out, and
  `tests/spec/repo/hygiene_spec.sh` checks it. Keep the agent block last in
  `.gitignore`.

[DESIGN-RULES.md](DESIGN-RULES.md) explains the fourteen design rules; section 10 of
[the specification](../specs/MARKSHARC-SPEC.md) states them.

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
   repo_version: 1
   ai:
     profile:
       - preset/generic
       - cap/gha
     values:
       repo_display: marksharc
       plan_docs: specs/*-PLAN*.md
       authority_docs: specs/MARKSHARC-SPEC.md
       verify: "tests/check (lint, zsh suite, repository suite); CI runs the same on macOS and Ubuntu"
       test_stack: "ShellSpec 0.28.1 via tests/run-tests; tests/lint for zsh -n, shellcheck, fish --no-execute and fish_indent --check"
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

   The first `cwf ai install` appends a `cwf-ai` block after the agent block in
   `.gitignore`. In a fresh clone the committed `.gitignore` already has it in
   place. If the agent block is ever not last, move it back to the end (cwf's
   block re-includes `.claude/hooks/`), then run
   `tests/run-tests --shell sh spec/repo/hygiene_spec.sh`. `cwf ai refresh`
   keeps the existing order.

4. After a template or settings change, run `cwf ai refresh` and repeat step 3.

Memory notes live in `memory/`; `cwf ai memory new` writes one and
`cwf ai memory index` rebuilds `memory/MEMORY.md`. `memory/local/` is ignored.
