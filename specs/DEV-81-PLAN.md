# DEV-81 Bash tool integrations implementation plan

The approved [Bash specification](BASH-SPEC.md) defines this unit. Exercise
the installed interactive entry point with Bash 4.4 and 5.x. Keep the
environment entry point compatible with Bash 3.2.

## Prompt and history

- Test a failed and a negated pipeline in a PTY with Starship, a foreign
  prompt command, and Atuin. Check the original status and pipeline statuses.
- Initialize Starship from cached full Bash init with its transport
  isolated. Register prompt and timing callbacks through DEV-80's hook
  registry. Use the provider's PS0 timing when no preexec backend is loaded.
- Cache Atuin's generated Bash code and allow its bundled bash-preexec
  to initialize once per Readline session. Register MarkSharc callbacks on
  the selected backend. Reuse its timing and status support where available.
- Verify native XDG history after disabled, missing, failed, empty and
  backend-less Atuin init. Verify recording, fresh child sessions, history
  listing and builtin passthrough, and check bindings across reload/disable.

## Navigation and environment

- Load zoxide with its hook disabled and register one directory callback.
  Keep its functions and specialized completion. Use the cached direnv
  hook with the framework prompt registry so `direnv allow` refreshes the
  environment on the next prompt even in the same directory.
- Test repeated prompts, directory transitions, disabled modules and
  user replacements. Document prompt-time directory observation.

## Version managers

- Source cached mise activation with upstream hooks disabled. Run the
  environment hook through the configured directory or prompt callback.
  Test explicit selection, hook off, per-tool compatibility translations,
  deactivation, removal on reload and fallback when mise is missing.
- Test legacy managers with available and unavailable project versions.
  Load nvm/gvm only on demand and preserve native Bash directory semantics
  when loading gvm. Use PATH and GOROOT consistent with the selected Go.
  Test pyenv fallback and suppression when uv or mise owns Python.

## Delivery

- Run `tests/check`, the install E2E and `git diff --check`. Inspect the
  disposable Linux PTY and run the focused contract on Bash 4.4 and 5.x.
  Full macOS/Linux composition, editor acquisition and warm startup
  acceptance remain in DEV-83.
