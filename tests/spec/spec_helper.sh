# shellcheck shell=sh
# Loaded by ShellSpec (see tests/.shellspec) from the tests directory.
# shellcheck source=tests/spec/support/fixtures.sh
. ./spec/support/fixtures.sh
spec_helper_configure() {
  before_each fixture_setup
  after_each fixture_teardown
}
