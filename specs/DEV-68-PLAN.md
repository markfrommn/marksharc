# DEV-68 provider and doctor diagnostics

The linked issue asks for provider setup troubleshooting, correct Bash stub
recognition, and guidance for the remaining fish migration. The design authority
is MARKSHARC-SPEC sections 6.6, 6.11, 6.15 and 10. DEV-51 establishes data-only
provider files and generated commands, and DEV-58 owns the remaining fish work.

- Detect enabled legacy provider files or an explicitly configured empty provider
  directory, and document conversion and rendering.
- Compare both installer-managed Bash files against the recorded checksum, while
  reporting modifications, missing files, symlinks and foreign configuration.
- Record fish stub and foreign-config coverage in the DEV-58 plan.
- Exercise diagnostics in temporary homes, run `tests/check`, and run
  `tests/e2e/install-e2e.sh "$PWD"`.

## Outcome

[PR #12](https://github.com/markfrommn/marksharc/pull/12) implements the Bash
stub and provider diagnostics. The local suites and both installer paths pass.
A scratch installation verified that converting a legacy provider definition
and rendering makes the generated command available in a fresh shell.

The affected installation needs the private overlay migration described in
[the provider guide](../docs/write-once.md). The `cwf-new` post-create hook
requires its own executable-hook migration under the DEV-51 contract.
