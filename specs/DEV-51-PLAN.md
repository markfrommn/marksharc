# DEV-51 — Write-once commands and shims

Authority: MARKSHARC-SPEC sections 6.4–6.11, 7, and 10; MARKSHARC-PLAN P3.3.

## Scope and sequence

1. Add focused failing tests for the tab-delimited, percent-encoded caller-state protocol; implement a non-evaluating zsh applier and thin temporary-file wrapper.
2. Move cwf-new, gwt-clean, repo-sync, ssh-agent discovery and cleanup, and Docker helpers into module executables. Preserve preflight and option behavior, use executable hooks, and keep wrappers only for caller-state changes. Remove obsolete codegraph integration.
3. Render secret-free provider and session shims into the private host cache, read provider configuration as data at invocation, and put module and shim directories on PATH in all session classes.
4. Migrate existing module tests to executable invocation and add cross-shell, hostile-data, permission, and regeneration tests. Document provider and hook migration and update the changelog and contract inventory.
5. Run tests/check, the install e2e, module suites, render stability/no-drift verification, and stack-check on origin/main...HEAD. Record outcomes and reconcile delivered facts here.

All tests use temporary homes, stubs and disposable repositories. No live cleanup or service access is authorized. Bash caller-state application remains later work.

## Acceptance criteria

- [x] Listed commands callable from zsh and bash; complex function implementations removed.
- [x] Safe directive encoding and application, including unknown-directive warnings.
- [x] Executable hooks and per-command behavior covered.
- [x] Provider/session shims private, secret-free, callable from bash, and rendered on PATH in every session class.
- [x] Documentation and local checks completed; isolated repeat rendering showed no unintended generated drift.

## Outcome

Implemented in [PR #8](https://github.com/markfrommn/marksharc/pull/8), awaiting human merge.

The shell wrapper applies directives emitted by the executable, including committed state changes
before an executable failure. CWF and worktree hooks run as executable programs. Providers use
data-only conf files and generated shims read provider values on invocation. Session shims are
refreshed by render; cached shim manifests support recovery on reload. Provider and hook migration
is documented in `docs/write-once.md`.

Local `tests/check` passed: lint 78 files, zsh 422 examples (one Apple Terminal platform skip),
contract 4, install 46 and repository 26. The standalone install e2e passed both checkout and
clone paths. Hermetic renderer tests cover repeat output, stale shim removal and failure recovery;
runtime artifacts stay in the temporary cache, with no repository drift. Tests use stubs and
disposable repositories; live CWF session creation/destruction, Herdr/Collie, SSH agents, Docker,
and provider services were not exercised. Hosted macOS and Ubuntu checks and install e2e passed on
the implementation head. Independent quality review is READY after all five findings were fixed
and re-reviewed; stack-check passes. No vendor review provider is configured, so local review is
`skipped:not-configured`; secondary review is off by default.
