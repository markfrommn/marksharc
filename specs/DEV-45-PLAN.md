# DEV-45: sync and doctor implementation plan

Authority: MARKSHARC-SPEC sections 6.14, 6.15 and 10; MARKSHARC-PLAN P2.5.

The operator approved the notify exception to offline startup: an eligible interactive shell
starts a detached fetch at most once per `sync.check_hours` (default 12 hours), and a later
eligible shell prints the cached behind notice. The fetch never pulls. All validation uses a
temporary HOME, disposable local repositories and stubs; actual hosts and services are out of scope.

1. Write focused failing tests for sync using local bare remotes: clean fast-forward; dirty,
   ahead, diverged and offline states; framework, overlay owning checkout (including symlink or
   subdirectory), and configured extra repositories. Implement safe fetch and fast-forward;
   never modify unsafe working trees. Test plugin pins and cache/render refresh and ensure a
   doctor summary follows sync. The MVP `update` runs sync and pins only.
2. Write failing tests for notify eligibility, detached execution, throttle, status persistence,
   failed fetch and the next-shell behind notice. Implement without blocking startup or pulling.
3. Write one focused failing fixture per doctor check: stubs and links, render freshness,
   enabled-module commands, plugin clones, repository state, foreign dotfile lines, duplicate
   PATH and startup budget. Implement a useful summary that tolerates missing optional inputs.
4. Reconcile README and development guidance with the approved startup exception. Run the
   repository gates, CI-only checks including `tests/e2e/install-e2e.sh "$PWD"`, and a local
   bare-repository end-to-end exercise covering a subsequent shell notice. Commit logical
   checkpoints and audit `origin/main...HEAD` with stack-check. Report live Mac-to-sol behavior
   as unverified; this task does not authorize access to either host.

Result: local bare-repository tests and the independent fresh-install fixture exercise
the push, detached fetch, later PTY notice, fast-forward and notice clearing. The
live Mac-to-sol acceptance remains unverified. The existing on-demand environment ID
and caches provide the MVP refresh; the P3.1 renderer is deferred.
