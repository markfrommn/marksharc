# DEV-71 installer cleanup

DEV-71 extends the Day 0 workflow from P2.4. The requirements are in
[DEV-71](https://linear.app/psols/issue/DEV-71/marksharc-p241-enhance-installer)
and [MARKSHARC-SPEC](MARKSHARC-SPEC.md) §§6.6, 6.15 and 10. It builds on the
merged installer, Bash environment and Fish startup work.

## Bash backups

- Add `.profile`, `.bash_login` and `.login` to the manifest-backed regular
  file and symlink handling. Keep writing the existing `.bashrc` and
  `.bash_profile` stubs. Keep their current conflict checks.
- On an upgrade, append newly covered files to the original backup without
  replacing any original record. An interrupted cleanup can retry removal
  only when the live file still matches its recorded original.
- In the install and uninstall specs, check a regular `.profile`, a relative
  `.bash_login` symlink and a dangling `.login` symlink. Verify removal on
  install and restoration on uninstall. Exercise an existing manifest and
  compare it across an unchanged rerun.

## Fish cleanup

- Offer to back up the Fish configuration tree when it contains legacy
  configuration. Read confirmation from the terminal so that the piped
  README invocation works. Default to no on Enter or without a terminal.
  `--clobber` supplies yes and `--dry-run` previews the decision without
  reading confirmation or writing. When declined, retain the existing Fish
  tree and add the managed stub when its slot is available. If a custom
  file occupies the slot, warn and continue with zsh and Bash.
- Move the confirmed tree as a unit so that variables, functions, plugin
  files, hidden entries and symlinks are preserved. Put the backup in a
  private directory beside the Fish tree so the move stays on the same
  filesystem. Record it in the existing install manifest. Validate the
  destinations before moving the tree. Install only
  `conf.d/00-marksharc.fish` in the replacement tree.
- Preserve the original backup on rerun. On uninstall, restore it after
  validating the current XDG configuration path and backup. Keep any new Fish
  configuration that would otherwise be overwritten. An earlier managed
  Fish stub must not be reactivated on restore. Keep reading manifests
  created before this change.
- Serialize install and uninstall against the same state directory. On retry,
  recognize unchanged dotfiles and Fish trees a previous uninstall already
  restored. Refuse to move a Fish tree that contains the overlay, framework,
  or backup paths.
- Cover terminal yes and default no, clobber, dry run, a foreign file in the
  stub slot, and restoration with new Fish files. Exercise an upgrade with
  a managed Fish stub as well as an existing unmanaged tree.

## Verification

- Keep the existing CLI and load-failure fallback specs green. Run
  `shellcheck -s sh install.sh` and `tests/check`.
- Run `tests/e2e/install-e2e.sh "$PWD"` for the README checkout and piped
  entry points. Exercise zsh, Bash and Fish with the template overlay. Use
  an additional simulated existing home to verify full cleanup and rollback.
- Update the README and specification with the prompt, backup and restore
  behavior.
