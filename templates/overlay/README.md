# MarkSharc overlay

This directory is your marksharc configuration (`$MARKSHARC_CONFIG`, by default
`~/.config/marksharc`). The framework checkout is read-only; everything personal
lives here.

| Path | Purpose |
| --- | --- |
| `config.conf` | Module selection (`module <name> [off]`) and options (`set <module>.<key> <value>`) |
| `hosts/<short-host-name>.conf` | Per-host additions and overrides, read after `config.conf` |
| `modules/<name>/` | Private modules, same contract as the public ones |
| `local/post.zsh` | Native zsh run at the end of interactive startup |

Useful commands:

```sh
marksharc module list              # which modules are enabled, disabled or skipped
marksharc module disable <name>    # edits config.conf
marksharc reload                   # apply changes in the current shell
```

Native zsh in `local/post.zsh` and in private modules runs both at startup and inside the
`marksharc` function on `marksharc reload`. Declare file-scope variables with `-g`
(`typeset -g name=value`); a bare `typeset` would be function-local on reload. Declarations
inside your own functions are unaffected.

Keep this directory in your own git repository to sync it between hosts.
