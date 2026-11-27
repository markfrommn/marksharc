# DEV-86 Declarative completion specs for `marksharc`, `launch`, and `cwf-new`

Deliver L8.2 from [COMPLETION-PLAN.md](COMPLETION-PLAN.md) under [MARKSHARC-SPEC.md](MARKSHARC-SPEC.md)
and [COMPLETION-SPEC.md](COMPLETION-SPEC.md) (sections 5.2, 5.3, 7, and 8).

## Scope

1. **Declarative `.comp` specifications (section 7)**
   - `core/completions/marksharc.comp`: complete `marksharc` root flags (`-h,--help`, `-V,--version`), subcommands (`reload`, `render`, `sync`, `sync/timer`, `push`, `hosts`, `hosts/list`, `hosts/populate`, `hosts/add`, `hosts/remove`, `hosts/help`, `bootstrap`, `update`, `install`, `doctor`, `module`, `module/list`, `module/enable`, `module/disable`, `uninstall`, `version`, `help`), options, and dynamic kinds (`ms:modules`, `ms:hosts`, `ms:installers`, `ms:update-steps`).
   - `modules/launch/completions/launch-session.comp`: `flag-form-locks-positional` mode, all flags, `ms:launch-session-target`, positional command/args, and `--` command/args fallback.
   - `modules/launch/completions/launch-repo.comp`: `flag-form-locks-positional` mode, all flags including `--host`, `--repo`, `--worktree`, `--rescan`, `--base-only`, `ms:launch-repo-target`, positional command/args, and `--` command/args fallback.
   - `modules/cwf/completions/cwf-new.comp`: `--repo`, `--host`, `--mux`, `--mux-id`, `--place`, `--launch`, `--pick`, and positional `ms:git-branches`.

2. **Native Bash 4.4+ and Fish loading + renderer parity polish (section 5.2)**
   - Add `core/bash/complete.bash` extracting the Readline unquoting, host validation, directory completion, helper invocation, and target completion helpers from `modules/launch/completions/bash/lib/workflow.bash`.
   - Source `core/bash/complete.bash` in `core/bash/interactive.bash` and load rendered `$cache/completions/bash/*.bash` in `_ms_bash_load_completions` with effect tracking so reload cleans up removed completions and preserves user overrides.
   - Wire `$cache/completions/fish` onto `fish_complete_path` (tracked in `_ms_fish_completion_paths` for clean reload removal) in `core/fish/marksharc.fish`, replacing the retired `core/fish/completions` path.
   - Ensure rendered zsh, Bash, and Fish helpers forward shell-local `MARKSHARC_HOST` / `MARKSHARC_CONFIG` to `core/cli/complete`, unquote zsh `--host` / `--repo` scan values, and support `host:/...` local directory completion in Fish `launch-repo-target`.

3. **Retire replaced hand-written completion files (section 5.3)**
   - Remove `core/fish/completions/marksharc.fish`.
   - Remove `modules/launch/completions/zsh/{_launch-session,_launch-repo}`, `modules/launch/completions/fish/{launch-session.fish,launch-repo.fish}`, and `modules/launch/completions/bash/{launch-session.bash,launch-repo.bash,lib/workflow.bash}`.
   - Remove `modules/cwf/completions/zsh/_cwf-new`, `modules/cwf/completions/fish/cwf-new.fish`, and `modules/cwf/completions/bash/cwf-new.bash`.
   - Preserve `modules/cwf/completions/bash/cwf.bash`, `modules/herdr/completions/bash/herdr.bash`, and `completion` / `completion-bash` directives.

## Verification

- Zsh PTY specs: `tests/spec/zsh/launch_completions_spec.sh` and `tests/spec/zsh/marksharc_completions_spec.sh`, plus `modules/launch/tests/launch_repo_spec.sh` and `tests/spec/zsh/render_spec.sh`.
- Bash 4.4+ unit and PTY specs: `tests/spec/contract/bash_static_completion_spec.sh` (quoted paths/repos/worktrees/branches, `:` reassembly, rendered `marksharc` hierarchy, interactive load/reload, and Bash 3.2 env-only check).
- Fish unit specs: `tests/fish/completions_test.fish` covering all four commands from rendered `$cache/completions/fish`, reload path cleanup, `launch-repo --host`/`--base-only`, `cwf-new --host`, and `marksharc install`/`update --only`.
- Full `tests/check` green (lint, zsh, contract, install, repo, and fish suites).
