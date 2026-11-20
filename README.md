# marksharc

Mark's shell RC files, rebuilt for the modern, agentic era.

marksharc is a modular shell framework for **zsh** and **fish**, with the same
environment in **bash** for scripts and agents. Functional areas are modules.
Configuration lives in a separate overlay that you own, so the framework
checkout stays read-only on every host.

> **Status:** early development. This repository holds the scaffold, tests and
> CI. There is nothing to install yet; the installer arrives in a later release.

## Requirements

- macOS or Linux
- zsh 5.9 or later
- fish 4.x (optional)
- bash 5.x (environment only)
- git

Day-to-day shell use needs only the native shell. The `marksharc` command needs zsh.

## Layout

| Path | Contents |
| --- | --- |
| `core/` | Per-shell loaders (`zsh/`, `fish/`, `bash/`) and CLI commands (`cli/`) |
| `modules/` | Public modules, one directory each |
| `templates/overlay/` | Skeleton for a new `~/.config/marksharc` overlay |
| `tests/` | ShellSpec suites, lint and fixtures |
| `docs/` | User and developer documentation |
| `specs/` | Design specification and programme plan |
| `memory/` | Shared workflow memory notes |

## Documentation

- [Developing marksharc](docs/DEVELOPING.md)
- [Tests](tests/README.md)
- [Specification](specs/MARKSHARC-SPEC.md) and [plan](specs/MARKSHARC-PLAN.md)

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
