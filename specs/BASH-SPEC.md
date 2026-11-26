# MarkSharc Interactive Bash Specification

Status: design approved 2026-11-25; runtime implementation pending DEV-80–DEV-83.
Issue: [DEV-61](https://linear.app/psols/issue/DEV-61/marksharc-l2-full-interactive-bash).
Evidence date: 2026-11-25, checkout `624d27d`.
Authority: [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md), especially sections 6, 6.16 and 10.
This feature spec extends that contract. Delivery is tracked in
[MARKSHARC-PLAN.md](MARKSHARC-PLAN.md); [DEV-61-PLAN.md](DEV-61-PLAN.md) covers the
design/docs PR. Approval covers this design and decomposition, not runtime installation.

## Supported versions and design decisions

Support full interactive Bash **4.4 and newer** on macOS and Linux. Keep the existing
environment path compatible with macOS Bash 3.2. Older Bash stays environment-only,
quietly; `doctor` explains the limitation. Never search for and automatically exec a
different Bash. Installing or choosing a newer login shell remains an explicit action.

| Approach | Benefit | Cost or gap |
| --- | --- | --- |
| **4.4+ interactive; older versions env-only (selected)** | Supports zoxide's interactive completion and modern completion tools without requiring the newest Bash | Two prompt-hook representations must be supported across 4.4 and 5.1+; macOS users choose a newer Bash explicitly |
| 5.1+ interactive; older versions env-only | Native `PROMPT_COMMAND` arrays simplify hook composition | Excludes 4.4 and 5.0 hosts without adding an essential interactive capability |
| 3.2+ interactive with per-feature degradation | Native macOS Bash gets a richer experience without a shell upgrade | Carapace 1.8.5 rejects it; zoxide's enhanced completion is unavailable; maintaining several editor/completion profiles increases scope |

Write-once zsh executables already remove most command implementation differences.
They cannot install caller functions, change the caller's directory, bind keys, draw a
prompt, or compose hooks in the parent Bash process. Those seams still need native Bash.
Associative arrays are a convenience, rather than the reason to choose a version floor.

Use the existing starship, atuin, zoxide, fzf and Carapace tools. Add an optional,
recommended **ble.sh >= 0.4** integration to supply suggestions, highlighting and a
completion menu. The fully equipped profile is the parity target; absent tools retain
documented fallbacks. The integration is approved; acquisition belongs to DEV-83's
explicit install/update tooling and is not performed by the design/docs PR.

## Implementation baseline at `624d27d`

| Capability | Current implementation and remaining work |
| --- | --- |
| Environment and PATH | `core/bash/env.bash`, `path.bash` and `core/zsh/lib/render-bash.zsh` implement native exports, tiered paths, agent classification, inheritance, stale-cache recovery, legacy manager defaults and mise ownership |
| Startup | Both installer-managed Bash files source `core/bash/bashrc.bash`; it currently sources only the environment entry point |
| Declarative configuration | The Bash emitter handles `env` and `path`; it does not emit interactive aliases or an init plan |
| Tooling and shims | Module `bin/` directories and generated provider/session shims already work across shells; the CLI remains a zsh executable |
| Caller state | zsh and Fish have directive appliers and wrappers; Bash needs its own applier and functions |
| Interactive modules | Public modules have zsh/Fish init files and native functions; there are no public `init.bash` implementations at this checkout |
| mise | Bash has env ownership, shims and fallback filtering; interactive activation and compatibility functions remain to be added |
| Completion | `completion-carapace` currently initializes zsh; launch/cwf static completions are zsh/Fish; Bash needs registrations and shell-specific generated artifacts |
| Tests | Existing Bash contract suite passes: 29 examples, 0 failures. Most cases explicitly launch `/bin/bash`; a full interactive matrix must also select newer interpreters explicitly |

This inventory is based on direct source reads. The graph index reports substantial
shell/config parsing gaps, so graph absence is not used as evidence of missing behavior.
Private overlay code is not certified by this inventory. Shared declarations and shims
carry forward; private shell-specific hooks need a separate inventory during adoption.

## Behavior contract

### Startup, rendering and reload

1. Keep `BASH_ENV` pointed at the environment-only entry point. Scripts and agents never
   gain interactive hooks through it. Interactive init requires Bash >= 4.4, `$-`
   containing `i`, stdin and stdout TTYs, and no active configured agent marker.
2. Both installed entry paths load env, then the same native interactive loader. A
   process-local guard prevents duplicate init when both paths are sourced. A child
   process initializes its own hooks even when `MARKSHARC_ENV` matches its parent.
3. Extend the existing zsh renderer to produce an ordered Bash init plan, options,
   guarded aliases and completion artifacts from shared module/overlay data. Keep Bash
   4.4-only syntax out of the environment artifact and 3.2 entry path. Do not parse
   configuration again in Bash or translate zsh functions at startup.
4. Run only enabled, OS-compatible modules with satisfied runtime command guards.
   Source native `init.bash` and `functions/bash/<fn>.bash` definitions, then overlay
   `local/post.bash`. Static completions use `completions/bash/<cmd>.bash`.
   Preserve ordering and missing-tool containment.
5. Provide `marksharc reload [--verbose|-v]`, `cs` and `li` in the current shell.
   Re-render before changing live state; a render failure leaves the current init
   intact. Remove disabled module effects, replace owned registrations once, and
   retain later user replacements and foreign hooks. Invalid reload arguments fail
   before changes. `cs` and `li` are verbose reloads, with no shell replacement.
6. Use shell-specific cached tool init, keyed by resolved executable/mtime, argv and
   integration options. Include backend/context where it changes generated code.
   Never share cached zsh/Fish scripts with Bash. Missing/failed tools must not leave a
   successful-looking artifact. Cache session-independent code, not a session UUID.
7. Normal startup is quiet and offline under the existing spec exceptions. Retain the
   explicit opt-in greeting and detached, throttled sync notification policy; no
   installation, update or shell upgrade occurs at startup. The existing 500 ms doctor
   budget applies to warm interactive startup and is measured rather than assumed.

### Caller changes and command surface

Implement the existing tab-separated, percent-encoded protocol natively: `cd`, `pushd`,
`setenv`, `unsetenv`, and deferred `exit`. Preserve empty fields, whitespace, literal
metacharacters, percent signs and final lines without a newline. Never evaluate protocol
data. Reject invalid names and unsafe typed/readonly/nameref assignment targets. Validate
arity and exit status. Clean up the private temporary file on success and failure;
honor an exit only after successful execution, application and cleanup.

Add thin Bash wrappers for `cwf-new`, `gwt-clean`, `setup-ssh-agent`,
`setup-x11-display`, `fix-tmux` and `refresh-env`, preserving the existing hook/option
transport and command status. Reuse executable implementations and shims. Commands that
need no caller change remain executables. Cover launch's first-prompt `LAUNCH_RUN` and
`LAUNCH_RUN_EXEC` argv contract with the same literal decoding and one-shot behavior.

### Hooks, navigation and version managers

Bash has no native `chpwd` event. Observe `$PWD` changes once before the next prompt,
including changes performed by directives and external tool functions. Run directory
callbacks only when it changes; initialize them once for the starting directory.
Directory-key commands also refresh the visible prompt immediately. This means a
compound `cd project; node ...` on one line may run before prompt-based manager selection;
an explicit manager command or mise shims handles that case. Document this difference.

Provide one owned hook registry for framework prompt/directory callbacks. Preserve
foreign scalar `PROMPT_COMMAND` on 4.4/5.0 and array form on 5.1+, the incoming status,
pipeline status and existing DEBUG traps. Use documented tool/backend hook interfaces
for preexec; do not build a competing general DEBUG-trap engine. With ble.sh, use its
hooks; with current Atuin on Readline, use its bundled bash-preexec. No module overwrites
the hook transport independently. Without either backend, prompt/directory work remains
available; precise preexec behavior is a documented degraded capability.

Port back/forward directory history, parent/first-child navigation and Alt-arrow
bindings. Keep Bash's native directory stack and `cd` semantics; do not reproduce every
zsh option. Provide emacs and vi editing bindings and preserve bindings owned by others
when the feature is disabled or reloaded.

Port mise activation, hook modes, ownership, compatibility functions, immediate explicit
selection and cleanup. Keep lazy nvm/gvm, `.nvmrc`/`go.mod` selection and uv/pyenv fallback
for tools mise does not own. Preserve the existing safe PATH/GOROOT behavior; never
introduce automatic installation where the declared policy forbids it.

### Prompt, history, completion and editing

| Area | Full profile | Fallback and important difference |
| --- | --- | --- |
| Prompt | Cached `starship init bash`, same selected config/preset | Plain Bash prompt if starship is absent; status and command duration must survive other hooks |
| History | Atuin recording, Ctrl-R/Up, `history`, `history -N`, `h`; other arguments use Bash builtin | A Bash-specific history file under XDG state when Atuin integration is unavailable/disabled. Atuin mode keeps in-memory recall and disables the native persistent store |
| History backend | ble.sh >= 0.4; current Atuin bundled bash-preexec on Readline | Atuin documents duration/status gaps with bash-preexec. If neither backend is usable, keep native history and report degraded recording in doctor; never silently disable all persistence |
| Navigation | zoxide `z`/`zi`, native stack, directory keys | Native navigation if zoxide/fzf is absent; enhanced zoxide completion requires Bash 4.4+ |
| Completion data | Opt-in Carapace; bash-completion where installed; framework static/generated registrations override overlapping generic ones | Native filename/command completion if engines are absent; no startup generation of external command completions |
| Completion menu | ble.sh menu selection and filtering | Readline completion/listing; Carapace alone supplies candidates, not zsh's fzf-tab UI |
| Suggestions and highlighting | ble.sh | Unavailable in plain Readline; Bash 5.x alone does not supply them |
| fzf | File/directory selection, shared previews and theme settings | Atuin retains Ctrl-R ownership; do not stack a second history binding or promise identical fzf-tab widgets |

Load bash-completion once when available, then Carapace when selected, then the
framework/tool-specific registrations. Preserve zoxide's specialized completion. Keep
`completion-carapace.enable`, bridges and excludes meaningful in Bash; define a Bash
`completion-ui` with choices appropriate to Bash rather than exposing zsh-only fzf-tab.
Switching editor/completion backends requires a fresh explicit `exec bash -l`; ordinary
option/module reloads remain in place. Report both active and pending selections.

A Bash line-editor module loads ble.sh with deferred attachment before integrations and
attaches after registrations/keybindings. Acquire and build an immutable pin only in
explicit install/update tooling using the existing cache/pin model. Required build
tools are diagnosed; builds/downloads never run at startup. Selecting the exact pin and
verifying its startup/hook composition is an entry criterion for the editor unit, before
writing its integration. Missing or explicitly disabled ble.sh retains Readline.

### Remaining public modules and gaps

Cover declarative ls aliases and platform color behavior; ps helpers; pager/man/diff
helpers; editor selection; theme/vivid/bat/delta/fzf; command-not-found; titles and mux
refresh; ssh-agent and X11; greeting; brew helper; git-worktree public functions; herdr,
cwf and launch integration. Reuse a zsh executable where all effects can remain in a
child, and write native functions only for caller or editor state.

Do not load `zsh-options`, zsh plugins, `fzf-fish`, or Fish plugins in Bash. Shell grammar,
zsh array expansion/globbing, Fish abbreviations, and exact completion rendering remain
shell-native differences. Private zsh/Fish functions are not automatically portable.

## Delivery boundaries

This crosses the renderer, startup/reload lifecycle, caller-state protocol, many public
modules, plugin acquisition, completion and CI. DEV-61 delivers the design/docs PR.
Four implementation issues deliver the runtime behavior:

| Unit | Issue | Owned scope | Acceptance boundary |
| --- | --- | --- | --- |
| A — Bash runtime and caller state | [DEV-80](https://linear.app/psols/issue/DEV-80) | Core loader, rendered init plan/aliases/options, cache, hooks, reload, directive applier and wrappers, overlay contract | Eligible sessions initialize once; quiet env-only modes and 3.2 still pass; literal directives and caller-changing commands work; foreign state survives reload |
| B — Tool integrations and managers | [DEV-81](https://linear.app/psols/issue/DEV-81) | starship, Atuin/native history, zoxide, direnv, mise, nvm/gvm and Python adapters | Prompt status/history capture, history fallback, manager ownership/selection and reload/fallback tests pass with isolated tool stubs |
| C — Native modules and workflow parity | [DEV-82](https://linear.app/psols/issue/DEV-82) | Navigation/keybindings; ps/ls/pager/editor/theme; titles/mux/ssh/X11; brew/git-worktree/cwf/herdr/launch; sync notification/greeting parity | Named public behaviors work in Bash, disabled features clean up, launch argv is literal and one-shot, directory navigation is verified in a PTY |
| D — Completion, editor and acceptance | [DEV-83](https://linear.app/psols/issue/DEV-83) | ble.sh acquisition/loading; Carapace/bash-completion/fzf; framework completions; explicit Bash CI matrix; user docs and final acceptance | Fully equipped profile meets the matrix below; Readline and missing-tool modes are usable and accurately diagnosed |

Each unit extends specs/tests for its behavior and carries its own task plan. A is a
prerequisite for B and C; D integrates all three. Intermediate PRs do not claim DEV-61's
parity goal. At acceptance, update the parent plan's current capability statements and
cross-references; mark the full feature shipped only after D. DEV-61 completion means
the design/docs are delivered; it does not certify interactive Bash. Its conditional
single-PR phase-lite path does not apply to this decomposition, and no execution skill
or review exception is preselected for DEV-80–DEV-83.

## Verification and acceptance

- Contract matrix: login/non-login, interactive PTY, no-TTY `-ic`, batch, configured
  agent, `BASH_ENV`, child shells with inherited render ID, duplicate source, cold/stale
  cache, failed render, unwritable cache, spaces in HOME/config paths.
- Explicitly test Bash 3.2 env-only on macOS, actual Bash 4.4 for the supported lower
  bound, and a current 5.x on macOS/Linux. Compatibility flags on 5.x do not certify 4.4.
  Add a reproducible pinned 4.4 test interpreter in CI tooling; no runtime dependency on
  a container or Python. Keep existing zsh/Fish/install suites green.
- Protocol tests cover literal hostile text, empty values, typed variables, malformed
  directives, command/apply/remove failures and deferred exit. Hook tests include
  existing traps and scalar/array prompt commands, failed commands/pipelines, duplicate
  reload, feature disable and later user replacements.
- Tool tests use temporary HOME, stubs and disposable repositories only. Keep native
  history recording if Atuin init fails. Confirm hooks do not install tools or duplicate
  recordings; no per-prompt subprocess merely to discover whether `$PWD` changed.
- Final human-visible PTY inspection: prompt after failure; Ctrl-R and Up recall;
  suggestions/highlighting; completion menu and quoted filenames; `z`/`zi`; directory
  arrows and stack; a wrapper changing the caller's directory; launch handoff; reload.
  Perform this with real installed integrations in a disposable HOME with sync disabled.
- Measure warm startup against 500 ms and record cold setup separately. Report macOS
  and Linux evidence separately. A stubbed contract is not live integration acceptance.
- For each implementation PR run documented `tests/check` and install E2E; no review or
  publication exception is inferred for future implementation issues. For this design PR, inspect
  Markdown/diff and verify source references; runtime gates are baseline evidence only.

## Research and evidence

The local system has Bash 3.2.57 and Homebrew Bash 5.3.20; tool versions sampled were
starship 1.27.0, Atuin 18.25.1, zoxide 0.10.0, Carapace 1.8.5 and fzf 0.75.0.
In a temporary HOME, all four tools generated Bash init successfully and passed syntax
checks in both interpreters. Loading Carapace returned 1 on Bash 3.2 with “legacy bash
is not supported”; loading it on 5.3 succeeded and registered git completion. These are
generation/syntax/registration probes, not interactive integration certification.

- [GNU Bash 5.1 release](https://lists.gnu.org/archive/html/info-gnu/2020-12/msg00003.html)
  introduces array `PROMPT_COMMAND`; [Bash manual](https://www.gnu.org/software/bash/manual/bash.html)
  documents interactive startup and Readline. This helps composition rather than
  providing suggestions or syntax highlighting.
- [zoxide usage](https://github.com/ajeetdsouza/zoxide) explicitly limits its interactive
  Space-Tab completion to Bash 4.4+; the locally generated 0.10.0 script has that guard.
- [Carapace setup](https://carapace-sh.github.io/carapace-bin/setup.html) documents native
  Bash registration and cross-shell bridges. Its local 1.8.5 output rejects Bash 3.x;
  candidate generation does not establish parity of interactive menus.
- [bash-completion upstream](https://github.com/scop/bash-completion) requires guarding
  loading for Bash >= 4.2 and avoiding duplicate sourcing.
- [Atuin integration](https://docs.atuin.sh/latest/guide/installation/) recommends ble.sh
  >= 0.4; documents bash-preexec capture limitations and bundled bash-preexec starting
  at 18.18.0. Support older Atuin only with a verified backend; otherwise retain native
  history. Do not run `atuin setup` against managed dotfiles.
- [ble.sh upstream](https://github.com/akinomyoga/ble.sh) supplies syntax highlighting,
  suggestions and menu completion; supports 3.0+ but recommends 4.0+ and restricts some
  features to it. It replaces Readline and requires deliberate integration/acquisition.
- [Starship Bash integration](https://starship.rs/guide/) is native; its
  [Bash source](https://raw.githubusercontent.com/starship/starship/master/src/init/starship.bash)
  explicitly composes prompt and preexec machinery with supported backends.

## Approved scope and completion

The operator approved Bash 4.4+ full interaction, older-version environment-only
fallback, no automatic shell replacement, optional recommended ble.sh and the four-PR
decomposition on 2026-11-25. DEV-61 delivers specifications/planning plus the authorized
Fish test-runner isolation fix; it does not implement interactive Bash.
DEV-80 is blocked on DEV-61; DEV-81 and DEV-82 depend on DEV-80; DEV-83 depends on all
three. Completed implementation prerequisites are recorded in the program plan and
Linear. Each runtime issue requires its own task-level plan and verification evidence.
