# Writing a module

A module is a directory that adds one functional area to the shell. This page shows how to write
one, for the framework or privately in your overlay. Section 6.4 of the
[specification](../specs/MARKSHARC-SPEC.md) is the contract.

- [Anatomy](#anatomy)
- [module.conf](#moduleconf)
- [Environment or interactive?](#environment-or-interactive)
- [Native code per shell](#native-code-per-shell)
- [Commands](#commands)
- [Completions](#completions)
- [Plugins, packages, installers and updates](#plugins-packages-installers-and-updates)
- [Rules every module follows](#rules-every-module-follows)
- [Tests](#tests)
- [Private modules](#private-modules)
- [Checklist](#checklist)

## Anatomy

Only `module.conf` is required. Add a file only when you need it.

```text
modules/<name>/
  module.conf                    description, order, requirements, options, declarative lines
  env.zsh  env.bash  env.fish    native environment code, for what directives cannot express
  init.zsh  init.bash  init.fish interactive setup
  functions/zsh/<fn>             zsh functions, autoloaded
  functions/bash/<fn>.bash       Bash functions, one per file, sourced
  functions/fish/<fn>.fish       fish functions, autoloaded
  bin/<command>                  executables, on PATH in every shell
  completions/<cmd>.comp         declarative completion, rendered for every shell
  completions/zsh/_<cmd>         static native completions (also bash/<cmd>.bash, fish/<cmd>.fish)
  zsh.plugins  fish.plugins      pinned third-party plugins
  installers/<name>              scripts for `marksharc install <name>`
  tests/                         specs for this module
```

A module name uses letters, digits, `-` and `_`.

The smallest useful module is one file. This is the whole of `modules/zoxide/module.conf`:

```text
describe "zoxide smart cd (cached init)"
order 81
requires command zoxide
```

with a one-line `init.zsh`:

```zsh
(( ${_ms_reloading:-0} )) || _ms_init_cached zoxide zoxide init zsh || true
```

## module.conf

`module.conf` uses the line format described in
[CONFIGURATION.md](CONFIGURATION.md#line-format).

This example is for an imaginary tool called `mytool`. It shows each kind of line:

```text
describe "mytool: home directory, user-tier path and completion"
order 40
option theme dark "Colour theme passed to mytool"

env  MYTOOL_HOME ~/.mytool                 when dir ~/.mytool
path user ~/.mytool/bin                    when dir ~/.mytool/bin
alias mt mytool                            when command mytool
completion mytool mytool completions zsh   when command mytool
package brew mytool
update mytool mytool self-update
```

| Line | Notes |
| --- | --- |
| `describe` | Required. One line; it appears in `marksharc module list` and the module reference. |
| `order` | 0–99, default 50. See [order bands](#order-bands). |
| `requires command` | The module skips itself when the command is missing. Use it when the whole module is pointless without the tool. |
| `requires os` | `darwin` or `linux`. |
| `option <key> <default> <text>` | Declares an option. Read it in zsh and Bash as `$_ms_opt_<module>_<key>`, with every character that is not a letter or digit replaced by `_`. The overlay changes it with `set <module>.<key> <value>`. |
| `env`, `path`, `alias` | Rendered for zsh, Bash and fish. Prefer these to native code. |
| `completion`, `completion-bash` | Run a generator at render time and cache the result. |
| `package`, `update`, `installer` | Day 0 and Day 2 hooks; see [below](#plugins-packages-installers-and-updates). |

Prefer a `when command`, `when dir` or `when file` condition on individual lines to a
module-wide `requires`. The module then stays useful when only part of its tooling is installed,
and installing the tool later takes effect in the next shell.

### Order bands

| Band | For |
| --- | --- |
| 0–9 | Core (`path`) |
| 10–19 | Package managers (`brew`), so later modules can find their tools |
| 20–69 | General modules |
| 70–79 | Completion |
| 80–89 | Prompt, history and navigation tools |
| 90–94 | Modules that must see every earlier module's hooks (`titles`, `x11`, `ssh-agent`, `greeting`) |
| 95–99 | Line-editor plugins that wrap widgets and must load last |

`tests/spec/zsh/modules_spec.sh` checks that each module sits in its band. Within one order
value, modules load by name.

## Environment or interactive?

Decide which phase each piece belongs to.

| Put it in | When | Examples |
| --- | --- | --- |
| `module.conf` lines, or `env.<shell>` | Scripts and agents need it too | PATH entries, exported variables, a tool's home directory |
| `init.<shell>` | It only makes sense at a prompt | Key bindings, prompt, completion, hooks, aliases, `tool init` output |

The env phase runs in every shell, including each `zsh -c` an agent starts. It must print
nothing and should start no process. The init phase runs only for a person at a terminal.

For a tool's own shell integration, use the init cache so that a warm start runs nothing:

```zsh
_ms_init_cached starship starship init zsh
```

The helper runs the command once, stores the output under the cache, and sources the stored
file from then on. It refreshes when the tool's binary changes. Add `-k <text>` when an option
of yours changes the generated code, and `-x NAME` when the command prints a value for an
exported variable and not code. Bash has `_ms_bash_init_cached` and fish has
`_ms_fish_init_cached`.

## Native code per shell

Write interactive behaviour separately for each shell. Do not translate one shell's
implementation into another; use what each shell offers.

### zsh

- Files in `functions/zsh/` are autoloaded: one function per file, named for the function, with
  no extension.
- `env.zsh` and `init.zsh` run at top level at startup, and inside a function on
  `marksharc reload`. Declare file-scope variables with `-g`:

  ```zsh
  typeset -g  _ms_mymod_state=ready
  typeset -ga _ms_mymod_list=()
  ```

  A bare `typeset` would be local on reload and vanish. `tests/support/function-safe-check.py`
  rejects it. Declarations inside your own functions are unrestricted.
- Add PATH entries from native code with `_ms_path_add <tier> <dir>`.
- If `init.zsh` installs hooks, register a cleanup function in `_ms_init_cleanups` so a reload
  replaces them.

### Bash

- Bash 4.4 or later. `functions/bash/<fn>.bash` holds one function definition per file.
- Use `declare -g` for globals in sourced files.
- Register callbacks through the core, which composes them with any existing `PROMPT_COMMAND`:
  `_ms_bash_register_prompt`, `_ms_bash_register_chpwd` and `_ms_bash_register_preexec`.
- Track what you change so reload can undo it: `_ms_bash_set_env NAME VALUE` for an export, and
  `_ms_bash_register_cleanup FUNCTION` for anything else.

`templates/overlay/README.md` documents these helpers, and
[BASH-SPEC.md](../specs/BASH-SPEC.md) is the contract.

### fish

- `functions/fish/<fn>.fish` is autoloaded; `completions/fish/<cmd>.fish` goes on fish's
  completion path.
- Use `_ms_fish_init_cached` for tool integration.

[fish.md](fish.md#writing-fish-module-code) has the fish rules.

## Commands

Put real logic in an executable, not in a shell function. A zsh script in `bin/` is on PATH in
zsh, Bash, fish and every agent shell, and it cannot leak variables or options into the caller.

```text
modules/mymod/bin/my-command      #!/usr/bin/env zsh
```

A program cannot change its caller. If the command must change the calling shell's directory or
environment, add a thin wrapper function per shell with the same name. The executable writes
what it wants; the wrapper applies it.

In the executable:

```zsh
source "$MARKSHARC_HOME/core/zsh/lib/directives.zsh" || exit 1
…
_ms_directive_emit setenv MY_SESSION "$id"
_ms_directive_emit pushd "$workdir"
```

In `functions/zsh/my-command`:

```zsh
emulate -L zsh
_ms_run_with_directives command my-command "$@"
```

In `functions/fish/my-command.fish` and `functions/bash/my-command.bash`, call
`_ms_fish_run_with_directives my-command $argv` and
`_ms_bash_run_with_directives my-command "$@"`.

The available directives are `cd`, `pushd`, `setenv`, `unsetenv` and `exit`. The wrapper applies
them after the program exits and keeps the program's exit status. Called without a wrapper, for
example from an agent, `_ms_directive_emit` does nothing and the command still does its work.
If a command needs no change to the caller, write no wrapper at all.

Hooks for such commands are executables too, passed as newline-separated names in an environment
variable. [write-once.md](write-once.md) covers hooks and the directive details.

## Completions

In order of preference:

1. **A `.comp` spec** in `completions/<cmd>.comp`. One declarative file renders to zsh, Bash,
   fish and Carapace. Use this for commands the module owns. See
   [completions.md](completions.md).
2. **A generator line** when the tool prints its own completion:
   `completion <cmd> <tool> completion zsh`. The output is cached at render time.
3. **A static native file** in `completions/zsh/_<cmd>`, `completions/bash/<cmd>.bash` or
   `completions/fish/<cmd>.fish`.

Never generate a completion at startup.

## Plugins, packages, installers and updates

**Plugins.** To use a third-party zsh or fish plugin, pin it in `zsh.plugins` or `fish.plugins`:

```text
plugin zsh-autosuggestions https://github.com/zsh-users/zsh-autosuggestions e52ee8ca55bcc56a17c828767a3f98f22a68d4eb shell zsh kind source
```

Pin the full commit SHA, not a tag or branch. `kind source` sources the plugin's entry file; `kind fpath` adds
its directory to `fpath`. In `init.zsh`, call `_ms_plugins_load <module>`. The loader only reads
clones that already exist; the installer and `marksharc update` fetch them.

**Packages.** `package brew <name>`, `package cask <name>`, `package apt <name>` and
`package dnf <name>` tell `marksharc bootstrap` what the module works best with.

**Updates.** `update <label> <command> [args…]` adds a step to `marksharc update`. The label
must be unique. Arguments are data. A command that starts with `./` resolves from the module
directory.

**Installers.** `installer <name> <script>` registers an executable for
`marksharc install <name>`. Use one when a tool needs more than a package. Never install
anything from `env` or `init` files.

## Rules every module follows

| Rule | In practice |
| --- | --- |
| Optional means optional | A missing tool or directory never produces an error or output. Guard with `requires`, `when`, or a test in native code. |
| Quiet | Nothing is printed at startup. Use `_ms_trace` for diagnostics; it prints only under `MARKSHARC_VERBOSE`. |
| Offline | No network access and no installation at startup. |
| Safe to source twice | Reload re-runs your files. Replace hooks; do not append them again. |
| No personal values | No user, host, organisation or site names and no home paths in a public module. Take them as options. `tests/support/personal-values-check.py` looks for them. |
| Read-only framework | Write to the cache or state directory, never into the module directory. |
| Data stays data | Never `eval` configuration or generated text. Quote arguments; apply directives. |

[DESIGN-RULES.md](DESIGN-RULES.md) gives the reasoning.

## Tests

Every behaviour change ships with a spec. Tests run in a throwaway HOME with stubbed commands,
never against real tools or services.

- zsh and Bash behaviour: ShellSpec files named `modules/<name>/tests/<name>_spec.sh`.
- fish behaviour: fishtape files named `modules/<name>/tests/<name>_test.fish`.

Link the module's test directory into the zsh suite, which is how the runner finds it:

```sh
ln -s ../../../../modules/<name>/tests tests/spec/zsh/modules/<name>
```

`tests/spec/zsh/module_specs_spec.sh` fails when a module has tests that are not linked. Then
add a row for the module to the contract inventory in [tests/README.md](../tests/README.md);
`tests/spec/repo/inventory_spec.sh` fails when a module is not listed.

Run the module's own tests while you work, and everything before you share:

```sh
tests/run-tests --shell zsh spec/zsh/modules/<name>
tests/run-fish-units modules/<name>/tests/<name>_test.fish
tests/check
```

## Private modules

A private module lives in your overlay at `~/.config/marksharc/modules/<name>/` and follows the
same contract. It is the right home for anything that names your employer, your hosts or your
own tools.

- It is discovered and enabled like a public module, and appears in `marksharc module list`.
- A private module with the same name as a public one replaces it. Use that sparingly: you stop
  receiving updates to the public module.
- The personal-values rule does not apply. Everything else does, most of all "quiet" and
  "optional": a private module that prints at startup breaks scripts and agents on that host.
- Relative `installer` and `./` `update` paths resolve from the module directory.

For a few lines of setup, `local/post.zsh` in the overlay is simpler than a module.

## Checklist

Before sharing a new or changed public module:

1. `module.conf` has `describe` and an `order` inside the right band.
2. Environment-level behaviour is declared with `env`, `path` and `alias` lines where possible.
3. Each shell the module supports has native files, or the module is declarative only.
4. Nothing prints, fetches or installs at startup, and a missing tool is silent.
5. zsh file-scope declarations use `-g`.
6. Tests exist, are linked from `tests/spec/zsh/modules/<name>`, and the module has a row in
   the contract inventory.
7. The module is listed as a commented `# module <name> off` line in
   `templates/overlay/config.conf`.
8. `docs/MODULES.md` is regenerated: `tests/support/gen-module-reference`.
9. The Fish parity table in [fish.md](fish.md) has a row for the module.
10. `tests/check` passes, and `CHANGELOG.md` has a line under Unreleased.
