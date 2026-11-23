# Developing marksharc

## Tools

| Tool | Version | Used for |
| --- | --- | --- |
| zsh | 5.9+ | Core and CLI; the zsh suite |
| fish | 4.x | Fish lint now; the fish phase later |
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

This runs `tests/lint` and every suite, in the same order as CI. See
[tests/README.md](../tests/README.md) for single suites and the test rules.
CI runs on `macos-latest` and `ubuntu-latest` for every pull request and every
push to `main`; both must be green before a merge.

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

   The first `cwf ai install` appends a `cwf-ai` block after the agent block in
   `.gitignore`. In a fresh clone the committed `.gitignore` already has it in
   place. If the agent block is ever not last, move it back to the end (cwf's
   block re-includes `.claude/hooks/`), then run
   `tests/run-tests --shell sh spec/repo/hygiene_spec.sh`. `cwf ai refresh`
   keeps the existing order.

4. After a template or settings change, run `cwf ai refresh` and repeat step 3.

Memory notes live in `memory/`; `cwf ai memory new` writes one and
`cwf ai memory index` rebuilds `memory/MEMORY.md`. `memory/local/` is ignored.
