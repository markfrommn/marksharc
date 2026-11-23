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

- [ ] Listed commands callable from zsh and bash; complex function implementations removed.
- [ ] Safe directive encoding and application, including unknown-directive warnings.
- [ ] Executable hooks and per-command behavior covered.
- [ ] Provider/session shims private, secret-free, callable from bash, and rendered on PATH in every session class.
- [ ] Documentation, tests and required checks completed; no unintended generated drift.
