# shellcheck shell=sh
# Loaded by ShellSpec (see tests/.shellspec) from the tests directory.
# shellcheck source=tests/spec/support/fixtures.sh
. ./spec/support/fixtures.sh
# zsh-only core-loader helpers (not POSIX; only the zsh suites may see them).
if [ -n "${ZSH_VERSION:-}" ]; then
  . ./spec/support/core.zsh
fi
spec_helper_configure() {
  before_each fixture_setup
  after_each fixture_teardown
}
