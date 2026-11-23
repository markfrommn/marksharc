# DEV-52 — Bootstrap, updates and explicit installers

Authority: MARKSHARC-SPEC sections 6.3–6.5, 6.15 and 7–10; MARKSHARC-PLAN P3.4.

## Scope and sequence

1. Specify behavior with failing ShellSpec examples in isolated homes: enabled module and overlay package selection, golden Brewfile, apt/dnf confirmation, update ordering and failure continuation, selection and dry-run, and installer registry dispatch.
2. Implement directive collection using existing module selection and safe shell-word parsing, without changing startup behavior. Implement bootstrap, ordered update and installer dispatch.
3. Convert the five explicit installers into module-owned scripts, preserve error propagation, and remove superseded interactive functions. Document overlay bundle format, migration and CLI usage; keep personal data in the companion overlay.
4. Run focused and full local CI checks, render stability checks and stack-check on `origin/main...HEAD`. Exercise safe runtime paths with disposable homes and stubs; report live package, installer and host validation gaps.

## Acceptance criteria

- [x] Enabled module and overlay `package`, `update` and `installer` directives work safely as data.
- [x] Bootstrap creates a Brewfile and runs Homebrew; apt/dnf commands are printed and confirmed.
- [x] Update runs sync, plugin pins and module steps in order, supports list, only and dry-run, continues on errors and summarizes results.
- [x] Registered krew, gvm, WezTerm terminfo, pyenv and nvm installers replace legacy install functions.
- [x] Golden Brewfile, runner and registry tests plus startup and install regression checks pass locally.
- [x] The companion overlay migration is published separately and the live cutover status is recorded.

## Validation and boundary

The isolated install e2e runs bootstrap with a stubbed Homebrew in both checkout and
clone installations. The companion overlay was exercised separately in a disposable
home: apt decline and confirmation with stubbed sudo, update listing and the Codex
step including daemon restart, and the Go tools installer from an unrelated working
directory. The WezTerm installer was exercised using the current upstream terminfo
source as a local curl fixture and real `tic` in a disposable home.

Merge and deploy the framework before applying the companion overlay. Live package
installation, end-to-end upstream installer execution, clean-host provisioning, and
replacement of the legacy updater on the Mac and sol remain unverified.
[Companion overlay PR #19](https://github.com/markfrommn/mark-desktop-files/pull/19)

Update captures and validates all registered argv before sync. Registration changes
fetched by sync take effect on the next invocation, so the commands executed match
the validated snapshot.
