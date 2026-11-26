# DEV-80 Bash runtime implementation plan

The approved [Bash specification](BASH-SPEC.md) and [MarkSharc specification](MARKSHARC-SPEC.md#616-interactive-bash) govern this unit. Reuse the installed Bash stubs and the shared zsh renderer. Keep Bash 3.2 and `BASH_ENV` on the quiet environment entry point. The interactive path requires Bash 4.4+, both TTYs, and an interactive session classification.

## Render and lifecycle

- Extend `core/zsh/lib/render-bash.zsh` and `core/zsh/lib/render.zsh` to stage `init.bash` alongside `env.bash`, with the same generated header and render ID. Emit ordered `_ms_bash_load_module NAME DIR` calls, option values via `_ms_bash_option NAME VALUE`, and aliases via `_ms_bash_alias NAME VALUE`. Compile OS/host guards and retain runtime command, directory, and file guards. Load native static completion files. External Bash completion generators and editor integration are DEV-83.
- In `core/bash/bashrc.bash`, source the environment and then `core/bash/interactive.bash` only when the session qualifies and matching artifacts are usable. Keep the artifact checks in `core/bash/env-cache.bash` compatible with Bash 3.2. Guard initialization by Bash process ID. Source `init.bash`, native functions, static completions and `local/post.bash` through the loader. Document the overlay and registration interfaces in `templates/overlay/README.md` and install a comment-only `templates/overlay/local/post.bash`.
- In `interactive.bash`, define `marksharc reload`, `cs` and `li`. Validate arguments, render and validate the new artifacts before touching live state. Track effects installed by the runtime and compare current values to the installed values before undoing them. Preserve later user definitions across subsequent reloads. Native integrations can register cleanup for effects outside the loader's tracked surfaces.
- Exercise login, non-login and inherited-ID child shells, duplicate sources, no-TTY and agent sessions, stale and unwritable rendered caches, failed render, module disable and repeated reload with later user definitions in `tests/spec/contract/bash_interactive_spec.sh`. Exercise both installed Bash entry paths in `tests/e2e/install-e2e.sh`.

## Hook registry

- Implement `core/bash/hooks.bash` with `_ms_bash_register_prompt FUNCTION`, `_ms_bash_register_chpwd FUNCTION`, `_ms_bash_register_preexec FUNCTION`, `_ms_bash_hooks_install`, and `_ms_bash_hooks_reset`. The prompt callback arguments are the incoming status followed by individual pipeline statuses. A directory callback runs at initialization and once per observed directory change. Preexec callbacks receive the command line through the active backend. Support ble.sh and bash-preexec through their documented registration interfaces. Keep existing DEBUG traps and the native scalar or array prompt transport.
- In `tests/spec/contract/bash_hooks_spec.sh`, test foreign hooks, incoming failed pipeline status, directory changes and duplicate registration, transport changes on reset, and preexec registration and removal with backend stubs.

## Tool init cache

- Implement `_ms_bash_init_cached [-k KEY] TOOL COMMAND [ARG ...]` in `core/bash/cache.bash`. Resolve the executable, key by path and modification time, exact argv, and the optional options/backend key. Cache under the Bash-specific host directory. Use atomic publication, leave no cache entry for a missing or failed generator, and apply successful output even when cache writes fail.
- Add `tests/spec/contract/bash_cache_spec.sh` cases for cache hits, executable/argument/options changes, malformed or empty entries, missing/failing tools and an unwritable cache.

## Caller state

- Implement `_ms_bash_run_with_directives COMMAND [ARG ...]` and `_ms_bash_decode_field VALUE` in `core/bash/directives.bash`. The decoder writes `_ms_bash_decoded` in the caller's scope, preserving trailing newlines. Apply tab-separated `cd`, `pushd`, `setenv`, `unsetenv`, and deferred `exit`. Validate variable targets and field counts, preserve literal data, and remove the private file on every return path. Retain the executable's status and honor deferred exit only after command, application, and cleanup succeed.
- Load Bash wrapper files from `modules/{cwf,git-worktree,ssh-agent,x11,mux}/functions/bash/`. Keep hook lists and copy exclusions newline-separated for the shared executables. First-prompt launch execution and the remaining native module behavior belong to DEV-82.
- In `tests/spec/contract/bash_directives_spec.sh`, exercise empty fields, hostile literal data, malformed operations, typed/readonly/nameref targets, command and apply failures, cleanup failures, deferred exit, and each wrapper's argument/option transport.

## Delivery checks

- Run `tests/check`, `tests/e2e/install-e2e.sh "$PWD"`, and `git diff --check`. Run the runtime contract with actual Bash 4.4 and current 5.x, exercise the environment-only fallback with Bash 3.2 where available, and record interpreter versions and platform limits.
- Observe the disposable installed Bash sessions in a PTY and measure warm startup against the 500 ms budget. Leave full tool/editor parity and the hosted interpreter matrix to DEV-81–DEV-83.

## Linux PTY timings

Five warm non-login starts per interpreter in an installed temporary HOME with
sync disabled. Time runs from process start to the first visible prompt.

| Bash | Cold | Warm median | Warm max |
| --- | ---: | ---: | ---: |
| 4.4.0(1) | 1,072 ms | 230 ms | 248 ms |
| 5.2.37(1) | 1,042 ms | 208 ms | 219 ms |
| 5.3.0(1) | 1,086 ms | 218 ms | 229 ms |

Bash 3.2.57(2) exercised the environment-only contract on Linux. macOS verification
runs through the existing hosted checks and installer jobs.
