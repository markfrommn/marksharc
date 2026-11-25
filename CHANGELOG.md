# Changelog

All notable changes to this project are recorded here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

<!-- Agent guidance: Keep entries newest first.  Lead with one intent-focused sentence per merged PR under Unreleased, including Linear keys.
Fill in additional details on more major changes includeing in the additional (optional) sections like ### Added, ### Fixed, etc.
Leave implementation details and file inventories to git and GitHub. Move pending entries into a real version at release.
The 0.<PR>.0 versions below are historical backfills, not a versioning rule for future releases. -->

## [Unreleased]

Added `launch-repo` and `repo-list` to discover configured repositories and open existing local or remote worktrees. (DEV-75)

Added `launch-session` to open terminals in a chosen directory on this host or a Herdr machine, with automation flags, zsh and fish completions, and reuse of local SSH agent and X11 forwarding. (DEV-74)

## [0.23.0]

Added an opt-in Carapace completion module for zsh with bridges and excludes options, mutual exclusion with fzf-tab unless forced, and `completion-ui` switching across fresh shells. (DEV-55)

## [0.22.0]

Added push sync over parallel SSH with regex host filtering, a `hosts.conf` inventory with `gum`/`fzf` discovery from `.ssh/config` and `hc machine ls`, poll-pull `sync --auto` and launchd/systemd timers, `sync --update`, and `update -y` / `--system` native OS package updates. (DEV-56)

## [0.21.0]

Tweak github actions, redo CHANGELOG.md.

## [0.20.0] - 2026-11-24

Improved interactive shells with suggestions, syntax highlighting, consistent themes, richer prompts, and optional procs-based process display. (DEV-54)

## [0.19.0] - 2026-11-24

Made installer cleanup reversible across Bash and Fish while preserving user changes and supporting safe reruns. (DEV-71)

## [0.18.0] - 2026-11-24

Added opt-in mise management for Node, Go, Python, and Ruby with legacy fallback and migration guidance. (DEV-72)

## [0.17.0] - 2026-11-24

Documented how to measure live shell startup without agent markers or output redirection changing the session being measured. (DEV-62)

## [0.16.0] - 2026-11-24

Linked the planned mise module to its tracked issue and synchronized generated workflow ignore rules. (DEV-72)

## [0.15.0] - 2026-11-24

Evaluated mise and recorded the decision to adopt it as an opt-in version manager alongside legacy fallbacks. (DEV-62)

## [0.14.0] - 2026-11-24

Unified multiplexer integration and added reliable refresh and recovery of forwarded shell state. (DEV-53)

## [0.13.0] - 2026-11-24

Made Fish a daily-driver shell with native modules and a migration path away from the legacy configuration. (DEV-58)

## [0.12.0] - 2026-11-23

Improved doctor diagnostics for managed Bash startup files and provider configurations needing migration. (DEV-68)

## [0.11.0] - 2026-11-23

Added bootstrap, coordinated updates, and explicit tool installers for repeatable day-two setup and maintenance. (DEV-52)

## [0.10.0] - 2026-11-23

Brought Fish startup and environment behavior into parity with zsh, including managed startup and reload support. (DEV-57)

## [0.9.0] - 2026-11-23

Brought Bash login, inherited, and opted-in agent environments into parity with zsh. (DEV-50)

## [0.8.0] - 2026-11-23

Moved complex workflow and shell helpers to write-once executables with safe generated provider and session commands. (DEV-51)

## [0.7.0] - 2026-11-23

Added declarative environment rendering so module and overlay configuration produce consistent, recoverable shell state. (DEV-49)

## [0.6.0] - 2026-11-22

Fixed Mac cutover diagnostics and reduced interactive startup latency through lazy version-manager loading and reliable plugin installation. (DEV-46)

## [0.5.0] - 2026-11-22

Added safe repository synchronization, update notifications, and doctor health checks. (DEV-45)

## [0.4.0] - 2026-11-22

Added the initial installer, managed shell startup stubs, overlay template, and marksharc CLI. (DEV-44)

## [0.3.0] - 2026-11-21

Added the system and workflow modules with portable tests and private-overlay separation. (DEV-43)

## [0.2.0] - 2026-11-21

Added the zsh core loader and environment/tool modules with cross-platform startup coverage. (DEV-42)

## [0.1.0] - 2026-11-20

Established the MarkSharc repository scaffold, development conventions, test harness, and macOS/Linux CI. (DEV-41)
