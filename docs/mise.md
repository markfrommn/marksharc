# Optional mise version manager

The public `mise` module lets each host assign Node, Go, Python, and Ruby to
[mise](https://mise.jdx.dev/) without changing the default nvm, gvm, and pyenv setup.
Install it explicitly with `marksharc install mise`, or include the declared Homebrew
package through `marksharc bootstrap`.

Enable ownership in the overlay's global `config.conf` or one host's
`hosts/<hostname>.conf`:

```text
set mise.tools "node go python ruby"
```

The default empty list changes nothing. Ownership also requires the `mise` executable:
if it is absent, nvm, gvm, and pyenv continue to run as before. Python ownership replaces
only the pyenv fallback; uv remains preferred.

## Options

| Option | Default | Behavior |
| --- | --- | --- |
| `mise.tools` | `""` | Space-separated owned tools: `node`, `go`, `python`, `ruby`. |
| `mise.version_files` | `on` | Export the owned tools in `MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS`, enabling files such as `.nvmrc`, `go.mod`, `.python-version`, and `.ruby-version`. |
| `mise.compat` | `on` | Provide thin `nvm` and `gvm` translation functions for owned tools. |
| `mise.auto_install` | `off` | Set `MISE_NOT_FOUND_AUTO_INSTALL`; the default does not install a tool merely because a command is missing. |
| `mise.set_gobin` | `off` | Set `MISE_GO_SET_GOBIN=false`, so `go install` keeps using `${GOPATH:-$HOME/go}/bin`. |
| `mise.hook` | `chpwd` | `chpwd` refreshes on directory changes, `prompt` retains mise's per-prompt hook, and `off` uses shims without activation. |

The module also reads mise's standard `MISE_DATA_DIR` and `MISE_SHIMS_DIR` overrides.
Otherwise it uses `${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims`.

## Shell behavior

Every zsh, fish, and Bash session class receives the shim directory in the `manager` PATH
tier, ahead of Homebrew. Agent and batch shells use those shims without shell activation,
so a script or agent running in a worktree gets the version requested by that directory.
Inherited nvm and gvm PATH entries are removed only for tools mise owns.

Interactive zsh, fish and Bash 4.4+ source cached `mise activate` output. With the default
`chpwd` mode, one environment refresh runs per directory change. Bash observes the
change at the next prompt, so `cd project; node ...` on a single line may run before
activation. Mise shims and explicit manager commands can select the version on the same
line. `mise shell`, `mise use`, and the compatibility functions refresh immediately.
After editing a version file in place, run `marksharc reload` in Bash or `cd .` in zsh
and fish to refresh.

The compatibility functions translate `use`, `install`, `ls`, `current`, and
`alias default`. For example, `nvm use 22` becomes `mise shell node@22`, and
`gvm install go1.27.2` becomes `mise install go@1.27.2`. `nvm alias default 24` and
`gvm alias default go1.27.2` use `mise use --global`. Other verbs print the mise forms
rather than emulating the legacy manager.

Run `marksharc update --only mise-tools` to upgrade tools installed by mise. Update a
Homebrew-installed mise through the normal brew update steps; an installation from
`mise.run` can be updated explicitly with `mise self-update`.

## Migration

Inspect mise's current view before switching a host:

```sh
mise current
mise ls
```

Reuse existing Node and pyenv installations:

```sh
mise sync node --nvm
mise sync python --pyenv
```

Then enable `node` and `python` in `mise.tools` and verify them in a new agent shell and an
interactive shell. The sync commands preserve the legacy installations, so removing the
option restores the fallback.

Install Go with mise rather than linking gvm's Go directories. A linked gvm path can resolve
behind Homebrew and leave `GOROOT` inconsistent with the first `go` on PATH:

```sh
mise install go@1.27.2
mise use --global go@1.27.2
```

Choose the version appropriate for the host, then verify `go version` and `go env GOROOT`.
Keep `~/go/bin` on PATH for commands installed with `go install`; the default
`mise.set_gobin off` preserves that behavior.

A uv global pin such as `cpython-3.13-any-any-any` in `~/.python-version` is not a valid
mise Python request. Replace it with the portable version `3.13` (or the version you use)
before enabling Python ownership. `marksharc doctor` reports this mismatch.

After enabling ownership, run `marksharc doctor`. To roll back, remove `mise.tools` or
uninstall mise and reload; nvm, gvm, and pyenv need no configuration change.
