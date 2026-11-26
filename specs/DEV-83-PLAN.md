# DEV-83 Bash completion, line editor and acceptance

Deliver L2.4 from [BASH-SPEC.md](BASH-SPEC.md) under [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md)
sections 6.8 and 6.16. DEV-80 through DEV-82 supply the native runtime, tool adapters
and public modules. DEV-55 supplies the opt-in Carapace options.

## Editor and acquisition

- Verify the exact upstream commit in a disposable PTY before writing the editor
  integration. Check deferred source, hook delivery, bindings and final attach.
- Use the existing plugin cache and explicit install/update path. Publish the
  build only after it succeeds. Diagnose unavailable tools and missing builds.
- Decide editor and completion backend once per process. On reload, keep the
  active backends and report pending changes. Preserve framework, tool and
  user registrations across reload.

Pin [ble.sh 152942758f567e51fd17bdc7b3783d27b3c476aa](https://github.com/akinomyoga/ble.sh/commit/152942758f567e51fd17bdc7b3783d27b3c476aa)
with its contrib gitlink at d2109203480a7dfe1dead5f5f8f9f15a9146c90d. GNU Make
4.4.1 and GNU Awk 5.2.1 built 0.4.0-devel4 in a disposable Linux checkout.
A pre-integration PTY probe on Bash 4.4.0 and 5.3.0 sourced it with
`--attach=none`, registered PREEXEC/PRECMD and a bind -x widget, then attached.
Both shells delivered the command text, status 0 and pipeline statuses 1/0
after `false | true`, and ran the bound widget.

## Completion and navigation

- Load bash-completion once, then opt-in Carapace, then specialized tool and
  framework registrations. Honor bridges and exclusions. Use ble.sh's menu in
  the full profile and Bash's Readline completion when using Readline.
- Add Bash completion for public launch, cwf and Herdr commands. Exercise
  literal candidates with spaces and quotes. Use cached generation where the
  existing framework generates command completion.
- Install fzf file and directory keys with Atuin retaining history search.
  Verify navigation keys and stack behavior in both line editors.

## Verification and handoff

- Run the Bash contracts on actual 4.4 and 5.x. Preserve the macOS system Bash
  3.2 environment-only regression. Run tests/check and the install E2E.
- Inspect real-tool disposable PTYs on Linux and macOS. Record prompt status,
  history capture/search, editing and completion UI, zoxide, navigation, caller
  directives, launch and reload. Measure cold and warm startup separately
  against the documented 500 ms warm budget.
- Reconcile README and the capability statements with verified behavior. Record
  any acceptance gaps before handoff.

## Acceptance evidence

Linux PTYs exercised the real ble.sh, Starship, Atuin, zoxide, and Carapace
startup. Starship showed status 1 after a failed command, Atuin recorded that
status, and zoxide's own registration survived Carapace initialization. A
live launch-session completion menu showed two candidate paths containing
spaces and quotes and delivered the selected path as a single argument.
The full-profile smoke check also exercised Ctrl-R and Up, suggestions and
highlighting, `z` and `zi`, directory keys and stack, fzf file and directory
keys, the caller-changing `gwt-clean` wrapper, and a Bash tmux launch with
literal and empty arguments. The reload retained the editor and specialized
completions while reporting the pending Readline selection. A second shell
verified Readline with bash-completion.
Explicitly rendered completions completed `herdr workspace` and `cwf status`
with Herdr 0.9.5 and CWF 0.21.1. The installer E2E covers checkout, clone, and
legacy installations and both Bash startup files.

The CI matrix builds GNU Bash 4.4.0 on Linux and macOS and 5.3.0 on Linux.
The macOS 5.3 checks use Homebrew Bash, matching the user installation path.
The macOS job also uses `/bin/bash` 3.2 for the environment-only regression.
The real-tool PTY check prints platform-specific cold and five-sample warm
times to the first visible prompt.

| Platform | Profile | Cold tool cache | Warm median | Warm max |
| --- | --- | ---: | ---: | ---: |
| Linux | Bash 5.3.0, ble.sh, Starship, Atuin, bash-completion, Carapace, zoxide, fzf | 5,109 ms | 3,034 ms | 3,127 ms |
| macOS (local) | Homebrew Bash 5.3.20, same full profile | 2,965 ms | 1,415 ms | 1,582 ms |
| macOS | Same profile on hosted CI | Pending | Pending | Pending |

The Linux and local macOS warm results exceed the 500 ms budget. Startup profiling found
editor initialization and editor-compatible Atuin, directory and fzf binding
setup to be material costs. Full acceptance remains open while the warm
budget and macOS results are outstanding.
