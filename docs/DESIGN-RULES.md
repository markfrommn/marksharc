# Design rules

These are the fourteen rules marksharc is built on. Section 10 of the
[specification](../specs/MARKSHARC-SPEC.md) states them; this page says what each means when you
write code, and which check holds the line.

When a change seems to need an exception, look for the design that does not. The one standing
exception is written into rule 4.

| # | Rule | Enforced by |
| --- | --- | --- |
| 1 | Match capabilities, not file trees | The cross-shell contract suite, `tests/spec/contract/` |
| 2 | Let each shell be itself | Review; [fish.md](fish.md) parity table |
| 3 | Login, interactive and agent are separate questions | `tests/spec/zsh/core_session_spec.sh`, the contract suite |
| 4 | Startup is quiet, fast and offline | The contract suite; `tests/bench-startup`; `marksharc doctor` |
| 5 | Reload is safe | `tests/spec/zsh/core_reload_spec.sh`, `function_safe_spec.sh`, `modules_spec.sh` |
| 6 | Data stays data | Renderer and directive specs |
| 7 | Scope mutable state | The contract suite's "no writes outside cache and state" cases |
| 8 | Fail before destructive work | Install, uninstall and cleanup specs |
| 9 | Optional means optional | `tests/spec/zsh/modules_spec.sh`; per-module specs with missing tools |
| 10 | Portable code holds no personal values | `tests/support/personal-values-check.py` |
| 11 | The framework is read-only on a host | The contract suite |
| 12 | Generated commands are shims on PATH | Shim specs in the `cc-providers` module |
| 13 | Prove behaviour without touching real services | The test harness itself: `tests/run-tests` |
| 14 | Do not canonise old bugs | Review |

## 1. Match capabilities, not file trees

A working command, a discoverable binary and the right exported variable matter more than
identical structure across shells.

*In practice:* judge parity by what the user can do. If `gwt-clean` works and behaves the same
in fish, fish has parity, even though the files that make it work look nothing like zsh's. Do
not add a file to one shell just because another shell has it.

## 2. Let each shell be itself

Share data and executables; write interactive behaviour natively.

*In practice:* environment lines are declared once and rendered. Commands with logic are one
executable. But hooks, key bindings and completion are written in each shell's own idiom: fish
events and lists, zsh widgets and `fpath`, Bash `PROMPT_COMMAND`. Translating one shell's
machinery into another produces code that fights its host.

## 3. Login, interactive and agent are separate questions

Env belongs to every mode. Prompting, history tools, titles and greetings need an eligible
interactive session.

*In practice:* never use "is this a login shell" to decide whether to print or prompt. Ask the
session class. Put anything a script needs in the env phase and everything else in init. A login
shell started by an agent is still an agent session and must stay silent.

## 4. Startup is quiet, fast and offline

Installs and pulls are explicit commands.

*In practice:* no output, no network access and no installation while a shell starts. Hints
about missing tools belong in `marksharc doctor`. Fetching belongs in `marksharc update` and
`marksharc sync`. Cache anything a tool would otherwise compute on every start.

*The exception:* an interactive shell may start one detached, throttled fetch to learn whether
the host is behind, and a later shell may print one line about it. The fetch never merges. It is
described in section 6.14 of the specification, and nothing else may use the network at startup.

## 5. Reload is safe

Keep inherited paths, deduplicate, replace named hooks, track what you generated.

*In practice:* `marksharc reload` re-runs your module in a live shell that already ran it. So
every file must be safe to source twice, hooks must be replaced and not stacked, and a module may
remove only what it added. The PATH builder is the model: it records the entries it generated
and touches nothing else. In zsh, file-scope declarations use `-g` so that a reload from inside a
function leaves the same state as startup.

## 6. Data stays data

Preserve spaces and metacharacters. Apply directives; never evaluate generated text, except a
tool's own documented shell integration.

*In practice:* configuration lines, provider files, directive files and command output are
parsed and quoted, never passed to `eval` or sourced. A path with a space or a `$` in it must
survive every hop. The single place generated text is sourced is `_ms_init_cached`, for output
such as `starship init zsh` that the tool documents as shell code.

## 7. Scope mutable state

Per-host cache, per-shell cache files, connectivity checks on cached sockets.

*In practice:* the cache directory includes the host name, because a home directory can be
shared between machines. Files that differ by shell have the shell in their name. A cached
value that can go stale, such as an agent socket, is tested before it is trusted.

## 8. Fail before destructive work

Validate, confirm, and let the owning tool delete.

*In practice:* run every check before the first change, so a failure leaves nothing half done.
`install.sh` and `marksharc uninstall` work this way. Ask before deleting. Prefer the owning
tool's own removal (`git worktree remove`) to a recursive delete of your own, and never walk
into paths you did not create.

## 9. Optional means optional

A missing tool or directory never breaks startup.

*In practice:* every module must load cleanly on a host that has none of the tools it wraps.
Use `requires command`, a `when` condition or a guard in native code, and stay silent when the
guard fails. A broken module is contained too: the loader skips a file that fails and carries
on.

## 10. Portable code holds no personal values

Names, hosts, organisations and paths arrive from the overlay.

*In practice:* nothing under `core/`, `modules/` or `templates/` names a person, a host, an
employer, a site or a home path. If a module needs such a value, it declares an option with an
empty or generic default. The same applies to examples in documentation.

## 11. The framework is read-only on a host

Configuration goes in the overlay; state goes in the cache and state directories.

*In practice:* no command and no startup path writes into the framework checkout. That is what
makes every update a clean fast-forward. If you want
to write a file, it belongs under `~/.cache/marksharc/<host>/` when it can be rebuilt, and under
`~/.local/state/marksharc/` when it cannot.

## 12. Generated commands are shims on PATH

So every shell and every agent can run them.

*In practice:* when configuration should produce a command, such as one per provider file,
render a small executable into the per-host `bin/` directory. Do not define a shell function: a
function exists only in the shell that defined it, so agents, scripts and the other shells would
not have it. A shim reads its data when it runs and never contains a secret.

## 13. Prove behaviour without touching real services

Temporary HOME, stubs, disposable repositories.

*In practice:* a test never reads the real home directory, calls a real service, or installs
anything. Each example gets its own HOME and XDG directories, and commands are stubs first on
PATH. This is why the suite is safe to run anywhere and gives the same answer in CI.
[tests/README.md](../tests/README.md) describes the harness.

## 14. Do not canonise old bugs

Use the old setup to find intent, then implement the useful contract.

*In practice:* when porting behaviour, ask what it was for, not what it happened to do. If the
old code had an accident in it, write the test for the intended behaviour and implement that.
