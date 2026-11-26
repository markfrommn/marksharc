# MarkSharc overlay

This directory is your marksharc configuration (`$MARKSHARC_CONFIG`, by default
`~/.config/marksharc`). The framework checkout is read-only; everything personal
lives here.

| Path | Purpose |
| --- | --- |
| `config.conf` | Module selection and options plus declarative `env`, `path`, `alias` and `tiers` lines |
| `hosts/<short-host-name>.conf` | Per-host additions and overrides, read after `config.conf` |
| `modules/<name>/` | Private modules, same contract as the public ones |
| `packages/` | Optional Brewfile fragments and apt/dnf package lists |
| `hosts.conf` | Host inventory for `marksharc push` and `launch-session` (`host <name> [<ssh-target>]`) |
| `local/post.zsh` | Native zsh run at the end of interactive startup |
| `local/post.bash` | Native Bash run at the end of interactive startup on Bash 4.4+ |

Useful commands:

```sh
marksharc module list              # which modules are enabled, disabled or skipped
marksharc module disable <name>    # edits config.conf
marksharc render                   # refresh cached env and generated completions
marksharc reload                   # apply changes in the current shell
```

Native zsh in `local/post.zsh` and in private modules runs both at startup and inside the
`marksharc` function on `marksharc reload`. Declare file-scope variables with `-g`
(`typeset -g name=value`); a bare `typeset` would be function-local on reload. Declarations
inside your own functions are unaffected.

Set `agent.bash_env` to `on` in `config.conf` to export the Bash startup hook to
noninteractive child shells. Start a new zsh session or run `marksharc reload` after
changing it.

### Native Bash modules

An interactive Bash 4.4+ sources each enabled module's `functions/bash/*.bash`
and then its `init.bash`. Put one named function definition in each function file.
Use `completions/bash/<command>.bash` to register a static completion for that command.
Static registrations run after module init and before `local/post.bash`. Use
`declare -g` for globals in sourced files, including arrays. Module options are
available as `_ms_opt_<module>_<option>` with punctuation replaced by underscores.

Native files can register a function with `_ms_bash_register_prompt FUNCTION` to
receive the previous command's status followed by the individual pipeline statuses.
`_ms_bash_register_chpwd FUNCTION` runs without arguments before the first prompt
and the next prompt after a directory change. A command on the same line as `cd`
can run before that callback. `_ms_bash_register_preexec FUNCTION` receives the
command line when ble.sh or bash-preexec supplies it.

Use `_ms_bash_init_cached [-k CONTEXT] TOOL EXECUTABLE [ARG ...]` for a tool's
documented Bash init output. Include options and the backend in `CONTEXT` when
they affect generated code. Use `_ms_bash_set_env NAME VALUE` for a tracked export.
Register a function with `_ms_bash_register_cleanup FUNCTION` to undo other effects
when reloading. That function should remove only effects still owned by the module.
Reload restores tracked declarations and preserves later user replacements.

Keep this directory in your own git repository to sync it between hosts.
