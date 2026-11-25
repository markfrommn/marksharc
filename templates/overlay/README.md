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

Keep this directory in your own git repository to sync it between hosts.
