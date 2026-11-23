# Write-once commands

Provider definitions now live in the overlay's `providers/*.conf` directory (or
the directory selected by `set cc-providers.dir`). Convert each old shell
`.provider` file to a `.conf` file named for the desired suffix. Use one `env`
directive per variable:

```text
env ANTHROPIC_AUTH_TOKEN "$MY_PROVIDER_TOKEN"
env MODELS_URL https://example.invalid/v1/models
```

Values use the configuration word syntax: quote spaces, use single quotes for
literal dollar signs, and use `$NAME` or `${NAME}` to read an environment
variable. Provider files are parsed as data, never sourced. Run `marksharc
render` after adding, removing, or renaming a provider. The resulting `claude`
and `models` commands read the file on each invocation, so value changes need
no render. `models` requires `MODELS_URL`, `curl`, and `jq`.

Herdr and Collie session commands are generated from the session list during
render. Run `marksharc render` to refresh them after sessions change.

Hooks for write-once commands are executable programs rather than shell function
arrays. Configure the corresponding command's executable hooks as documented in
its module; a hook runs in a separate process and cannot modify the caller's
shell state.
