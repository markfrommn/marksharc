source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
# fish loads a command's completions only once the command resolves.
ms_stub marksharc 'exit 0'
set -gp fish_complete_path "$MARKSHARC_ROOT/core/fish/completions"

set -l subcommands (complete -C 'marksharc ' | string replace -r '\t.*' '')
@test "marksharc completes its subcommands" (count $subcommands) -eq 13
@test "reload is offered" (contains -- reload $subcommands; and echo yes) = yes
@test "push is offered" (contains -- push $subcommands; and echo yes) = yes
@test "hosts is offered" (contains -- hosts $subcommands; and echo yes) = yes
@test "subcommands are not offered twice" (count (complete -C 'marksharc doctor ' | string match -r '^reload')) -eq 0
@test "module offers its actions" (complete -C 'marksharc module ' | string replace -r '\t.*' '' | string join ' ') = "disable enable list"
@test "hosts offers its actions" (complete -C 'marksharc hosts ' | string replace -r '\t.*' '' | string join ' ') = "add list populate remove"
@test "module enable offers module names" (contains -- ps (complete -C 'marksharc module enable p' | string replace -r '\t.*' ''); and echo yes) = yes
command mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/my mod"
printf 'describe mine\n' >"$XDG_CONFIG_HOME/marksharc/modules/my mod/module.conf"
@test "module enable offers overlay modules" (contains -- "my mod" (complete -C 'marksharc module disable my' | string replace -r '\t.*' ''); and echo yes) = yes
command mkdir -p "$XDG_CONFIG_HOME/marksharc"
printf 'host alpha\nhost beta ops@beta\n' >"$XDG_CONFIG_HOME/marksharc/hosts.conf"
@test "push offers hosts from hosts.conf" (contains -- alpha (complete -C 'marksharc push al' | string replace -r '\t.*' ''); and echo yes) = yes
@test "reload offers --verbose" (contains -- --verbose (complete -C 'marksharc reload --' | string replace -r '\t.*' ''); and echo yes) = yes

ms_stub launch-session 'exit 0'
ms_module launch
printf 'host\tgamma\tops@gamma\n' >>"$XDG_CONFIG_HOME/marksharc/hosts.conf"
set -l launch_hosts (complete -C 'launch-session --host ' | string replace -r '\t.*' '')
@test "launch completes configured and reserved hosts" (string join ' ' $launch_hosts) = 'alpha beta fixture gamma local localhost remote'
@test "launch completes positional hosts with a colon" (complete -C 'launch-session --place tab ga' | string replace -r '\t.*' '') = gamma:
@test "launch flag form does not offer positional hosts" (count (complete -C 'launch-session --pwd / ga' | string match -r '^gamma:')) -eq 0
@test "launch offers multiplexer kinds and the Core alias" (complete -C 'launch-session --mux ' | string replace -r '\t.*' '' | string join ' ') = 'hc herdr herdr-core tmux'
@test "launch offers all placements" (complete -C 'launch-session --place ' | string replace -r '\t.*' '' | string join ' ') = 'hidden tab workspace'
@test "launch offers run-after-init" (complete -C 'launch-session --in-' | string replace -r '\t.*' '') = --in-shell

ms_cleanup
