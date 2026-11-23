# DEV-52 — Bootstrap, updates and explicit installers

Authority: MARKSHARC-SPEC sections 6.3–6.5, 6.15 and 7–10; MARKSHARC-PLAN P3.4.

## Scope and sequence

1. Specify behavior with failing ShellSpec examples in isolated homes: enabled module and overlay package selection, golden Brewfile, apt/dnf confirmation, update ordering and failure continuation, selection and dry-run, and installer registry dispatch.
2. Implement directive collection using existing module selection and safe shell-word parsing, without changing startup behavior. Implement bootstrap, ordered update and installer dispatch.
3. Convert the five explicit installers into module-owned scripts, preserve error propagation, and remove superseded interactive functions. Document overlay bundle format, migration and CLI usage; keep personal data in the companion overlay.
4. Run focused and full local CI checks, render stability checks and stack-check on `origin/main...HEAD`. Exercise safe runtime paths with disposable homes and stubs; report live package, installer and host validation gaps.

## Acceptance criteria

- [ ] Enabled module and overlay `package`, `update` and `installer` directives work safely as data.
- [ ] Bootstrap creates a Brewfile and runs Homebrew; apt/dnf commands are printed and confirmed.
- [ ] Update runs sync, plugin pins and module steps in order, supports list, only and dry-run, continues on errors and summarizes results.
- [ ] Registered krew, gvm, WezTerm terminfo, pyenv and nvm installers replace legacy install functions.
- [ ] Golden, runner and registry tests plus startup and install regression checks pass.
- [ ] Companion personal package/update migration is prepared and coordinated separately; real host replacement is verified or explicitly reported as unverified.
