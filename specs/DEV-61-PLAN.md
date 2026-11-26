# DEV-61 task plan

Status: design and four-PR decomposition approved 2026-11-25. The operator also
authorized the Fish test-runner isolation fix found during verification. Interactive
runtime work belongs to DEV-80–DEV-83 and their per-issue task plans.

1. Read the live Linear issue, comments and prerequisites, then the authoritative spec,
   current L2 plan entry and repository memory index. **Done.** DEV-50 and DEV-68 are
   Done; DEV-61 has no discussion comments at research time.
2. Audit Bash env/render/startup, caller-state wrappers and public interactive modules;
   compare supported tool backends and Bash versions with primary upstream sources.
   **Done.** See [BASH-SPEC.md](BASH-SPEC.md).
3. Verify the current Bash baseline and narrowly probe installed tool generation and
   interpreter compatibility in temporary HOME directories. **Done:** 29 Bash contract
   examples pass; Carapace rejects system Bash 3.2 and loads on Homebrew Bash 5.3.
4. Present options, recommend the functionality contract and estimate a reviewable
   delivery boundary. **Done:** four implementation units approved.
5. Obtain the design decision required by DEV-61's process. **Done.** Bash 4.4+ full
   interaction, older-version env-only fallback, no automatic exec and optional
   recommended ble.sh are approved. No runtime installation occurs in this unit.
6. Publish [BASH-SPEC.md](BASH-SPEC.md), reconcile the authoritative spec and parent
   plan, and create scoped Linear issues/dependencies: DEV-80 (runtime/wrappers),
   DEV-81 (tool integrations/managers), DEV-82 (native modules/workflow), DEV-83
   (completion/editor/acceptance). Verify doc links, consistency and dependency edges;
   commit/publish the design PR. Keep design delivery distinct from runtime acceptance.
   Merge remains a human decision; phase-lite is not used for this unit.
7. Isolate the Fish unit runner from Homebrew's global mise activation. **Authorized.**
   Set `MISE_FISH_AUTO_ACTIVATE=0` inside the runner's `env -i` boundary and retain
   configuration loading for fishtape's universal counters. Own `tests/run-fish-units`,
   `tests/spec/repo/fish_runner_spec.sh` and the runner documentation in `tests/README.md`.
   Add a parent/child regression, reproduce its failure, then verify the runner specs,
   full Fish suite, lint and hosted macOS/Linux CI. This fixes the test harness only.

Verification for the documentation: `git diff --check`, local Markdown link
checks, source/reference inspection and a self-review for unresolved design ambiguity.
`tests/run-tests --shell sh spec/contract/bash_spec.sh` is baseline evidence, not a
claim that the proposed interactive functionality is implemented.
