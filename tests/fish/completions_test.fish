source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
# fish loads a command's completions only once the command resolves.
ms_stub marksharc 'exit 0'
set -gp fish_complete_path "$MARKSHARC_ROOT/core/fish/completions"

set -l subcommands (complete -C 'marksharc ' | string replace -r '\t.*' '')
@test "marksharc completes its subcommands" (count $subcommands) -eq 11
@test "reload is offered" (contains -- reload $subcommands; and echo yes) = yes
@test "subcommands are not offered twice" (count (complete -C 'marksharc doctor ' | string match -r '^reload')) -eq 0
@test "module offers its actions" (complete -C 'marksharc module ' | string replace -r '\t.*' '' | string join ' ') = "disable enable list"
@test "module enable offers module names" (contains -- ps (complete -C 'marksharc module enable p' | string replace -r '\t.*' ''); and echo yes) = yes
command mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/my mod"
printf 'describe mine\n' >"$XDG_CONFIG_HOME/marksharc/modules/my mod/module.conf"
@test "module enable offers overlay modules" (contains -- "my mod" (complete -C 'marksharc module disable my' | string replace -r '\t.*' ''); and echo yes) = yes
@test "reload offers --verbose" (contains -- --verbose (complete -C 'marksharc reload --' | string replace -r '\t.*' ''); and echo yes) = yes

ms_cleanup
