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
literal dollar signs, and use `$NAME` or `${NAME}` to read an exported environment
variable. Provider files are parsed as data, never sourced. Run `marksharc
render` after adding, removing, or renaming a provider. The resulting `claude`
and `models` commands read the file on each invocation, so value changes need
no render. `models` requires `MODELS_URL`, `curl`, and `jq`.

For an existing installation, `setup-cc-providers` has been replaced by the
render step. Name each new `.conf` file for the desired command suffix. The
old `demo-description.provider` produced `claudedemo`, so use `demo.conf`
to retain that command. Express each required assignment as an `env` directive.
Replace shell file reads and substitutions with exported environment references.
Move the old files outside that directory after conversion, then run `marksharc
render` and open a new shell or run `marksharc reload`. The cache bin directory
is added to PATH by the shell environment. `marksharc doctor` reports legacy
files and an explicitly configured provider directory with no `.conf` files.
Treat old files as shell code when reviewing them and translate the needed
values and environment references into data directives.

Herdr and Collie session commands are generated from the session list during
render. Run `marksharc render` to refresh them after sessions change.

Hooks for write-once commands are executable programs rather than shell
functions. The zsh arrays `gwt_clean_pre_remove_hooks` and
`cwf_new_post_create_hooks` contain executable names or paths. For direct
executable calls, set `MARKSHARC_GWT_CLEAN_HOOKS` or
`MARKSHARC_CWF_NEW_HOOKS` to newline-separated executable names or paths.
Hooks run in separate processes and cannot modify the caller's shell state.

Zsh wrappers apply caller-state directives after the command exits, including completed changes
before a later command failure. The command's failure status is preserved. Environment directives
accept writable scalar targets, including `PATH`; numeric, array and readonly targets are rejected
before assignment so directive data cannot be evaluated as arithmetic. Bash invokes the same
executables directly; applying directives to the calling bash shell remains later work.
