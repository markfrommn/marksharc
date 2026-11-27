source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

# Prepare overlay modules, hosts, installers, update steps, repo caches, and a git repo.
command mkdir -p "$XDG_CONFIG_HOME/marksharc/modules/my-mod" \
    "$XDG_CONFIG_HOME/marksharc/modules/custom-mod" \
    "$XDG_CACHE_HOME/marksharc/fixture/repos" \
    "$TEST_ROOT/project"
printf 'module launch\nmodule cwf\nmodule custom-mod\n' >"$XDG_CONFIG_HOME/marksharc/config.conf"
printf 'describe mine\n' >"$XDG_CONFIG_HOME/marksharc/modules/my-mod/module.conf"
printf 'describe "Custom overlay module"\ninstaller demo-tool ./install.sh\nupdate custom-step echo ok\n' >"$XDG_CONFIG_HOME/marksharc/modules/custom-mod/module.conf"
printf '#!/bin/sh\nexit 0\n' >"$XDG_CONFIG_HOME/marksharc/modules/custom-mod/install.sh"
command chmod +x "$XDG_CONFIG_HOME/marksharc/modules/custom-mod/install.sh"
printf 'host alpha\nhost beta ops@beta\nhost\tgamma\tops@gamma\n' >"$XDG_CONFIG_HOME/marksharc/hosts.conf"
printf 'alpha\t/tmp/alpha\tbase\t/tmp/alpha\tmain\nwt1\t/tmp/alpha-wt/wt1\tworktree\t/tmp/alpha\tfeat-one\n' >"$XDG_CACHE_HOME/marksharc/fixture/repos/local.tsv"
printf 'remote-app\t/srv/remote-app\tbase\t/srv/remote-app\tmain\nwt-rem\t/srv/remote-app-wt/wt-rem\tworktree\t/srv/remote-app\trem/branch\nother-wt\t/srv/other-wt\tworktree\t/srv/unrelated\tother/branch\n' >"$XDG_CACHE_HOME/marksharc/fixture/repos/gamma.tsv"
command git -C "$TEST_ROOT/project" init -q
command git -C "$TEST_ROOT/project" -c user.name=Test -c user.email=test@example.invalid commit -qm initial --allow-empty
command git -C "$TEST_ROOT/project" branch feature/fish-branch

# Render declarative completions into the host cache.
env HOST=fixture MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_HOST=fixture "$MARKSHARC_ROOT/bin/marksharc" render >/dev/null

# fish loads a command's completions only once the command resolves.
ms_stub marksharc 'exit 0'
ms_stub launch-session 'exit 0'
ms_stub launch-repo 'exit 0'
ms_stub cwf-new 'exit 0'
set -l rendered_fish "$XDG_CACHE_HOME/marksharc/fixture/completions/fish"
set -gp fish_complete_path "$rendered_fish"
set -ga _ms_fish_completion_paths "$rendered_fish"

# marksharc subcommands, flags, choices, and dynamic kinds
set -l subcommands (complete -C 'marksharc ' | string replace -r '\t.*' '')
@test "marksharc completes its subcommands" (count $subcommands) -eq 13
@test "reload is offered" (contains -- reload $subcommands; and echo yes) = yes
@test "push is offered" (contains -- push $subcommands; and echo yes) = yes
@test "hosts is offered" (contains -- hosts $subcommands; and echo yes) = yes
@test "subcommands are not offered twice" (count (complete -C 'marksharc doctor ' | string match -r '^reload')) -eq 0
@test "module offers its actions" (complete -C 'marksharc module ' | string replace -r '\t.*' '' | string join ' ') = "disable enable list"
@test "hosts offers its actions" (complete -C 'marksharc hosts ' | string replace -r '\t.*' '' | string join ' ') = "add help list populate remove"
@test "hosts populate --source offers choices" (complete -C 'marksharc hosts populate --source ' | string replace -r '\t.*' '' | string join ' ') = "all hc ssh"
@test "sync timer offers on off status" (complete -C 'marksharc sync timer ' | string replace -r '\t.*' '' | string join ' ') = "off on status"
@test "module enable offers module names" (contains -- ps (complete -C 'marksharc module enable p' | string replace -r '\t.*' ''); and echo yes) = yes
@test "module enable offers overlay modules" (contains -- my-mod (complete -C 'marksharc module disable my' | string replace -r '\t.*' ''); and echo yes) = yes
@test "push offers hosts from hosts.conf" (contains -- alpha (complete -C 'marksharc push al' | string replace -r '\t.*' ''); and echo yes) = yes
@test "reload offers --verbose" (contains -- --verbose (complete -C 'marksharc reload --' | string replace -r '\t.*' ''); and echo yes) = yes
@test "install offers registered installers" (contains -- demo-tool (complete -C 'marksharc install de' | string replace -r '\t.*' ''); and echo yes) = yes
@test "update --only offers built-in and registered steps" (contains -- custom-step (complete -C 'marksharc update --only cu' | string replace -r '\t.*' ''); and echo yes) = yes

# launch-session completions
set -l launch_hosts (complete -C 'launch-session --host ' | string replace -r '\t.*' '')
@test "launch completes configured and reserved hosts" (string join ' ' $launch_hosts) = 'alpha beta fixture gamma local localhost remote'
@test "launch completes positional hosts with a colon" (complete -C 'launch-session --place tab ga' | string replace -r '\t.*' '') = gamma:
@test "launch flag form does not offer positional hosts" (count (complete -C 'launch-session --pwd / ga' | string match -r '^gamma:')) -eq 0
@test "launch offers multiplexer kinds and the Core alias" (complete -C 'launch-session --mux ' | string replace -r '\t.*' '' | string join ' ') = 'hc herdr herdr-core tmux'
@test "launch offers all placements" (complete -C 'launch-session --place ' | string replace -r '\t.*' '' | string join ' ') = 'hidden tab workspace'
@test "launch offers run-after-init" (complete -C 'launch-session --in-' | string replace -r '\t.*' '') = --in-shell

# launch-repo completions (--host, --base-only, positional host:, repo-scoped --worktree, flag-form lock)
@test "launch-repo completes --host values" (contains -- gamma (complete -C 'launch-repo --host ga' | string replace -r '\t.*' ''); and echo yes) = yes
@test "launch-repo offers --base-only flag" (complete -C 'launch-repo --base-' | string replace -r '\t.*' '') = --base-only
set -l base_only_cands (complete -C 'launch-repo --base-only al' | string replace -r '\t.*' '')
@test "launch-repo --base-only includes base repo" (contains -- alpha $base_only_cands; and echo yes) = yes
@test "launch-repo --base-only omits worktree entries" (contains -- alpha/wt1 $base_only_cands; and echo yes; or echo no) = no
@test "launch-repo completes positional host:repo targets" (contains -- gamma:remote-app (complete -C 'launch-repo gamma:rem' | string replace -r '\t.*' ''); and echo yes) = yes
@test "launch-repo --worktree filters to --repo and includes branch" (complete -C 'launch-repo --host gamma --repo remote-app --worktree ' | string replace -r '\t.*' '' | string join ' ') = 'rem/branch wt-rem'
@test "launch-repo flag form suppresses positional target" (count (complete -C 'launch-repo --host gamma rem')) -eq 0

# cwf-new completions (--host, --repo, git branches)
@test "cwf-new completes --host values" (contains -- gamma (complete -C 'cwf-new --host ga' | string replace -r '\t.*' ''); and echo yes) = yes
@test "cwf-new completes remote base repos for --host" (complete -C 'cwf-new --host gamma --repo rem' | string replace -r '\t.*' '') = remote-app
builtin cd "$TEST_ROOT/project"
@test "cwf-new completes local git branches" (contains -- feature/fish-branch (complete -C 'cwf-new feat' | string replace -r '\t.*' ''); and echo yes) = yes
builtin cd "$HOME"

# core/fish/marksharc.fish wires $cache/completions/fish and cleans it up on reload
set -l real_host (string split -m 1 . -- "$hostname")[1]
env MARKSHARC_HOME="$MARKSHARC_ROOT" MARKSHARC_HOST="$real_host" "$MARKSHARC_ROOT/bin/marksharc" render >/dev/null
set -l expected_dir "$XDG_CACHE_HOME/marksharc/$real_host/completions/fish"
set -l fish_bin (status fish-path)
set -l reload_check (env HOME="$HOME" XDG_CONFIG_HOME="$XDG_CONFIG_HOME" XDG_CACHE_HOME="$XDG_CACHE_HOME" \
    XDG_DATA_HOME="$XDG_DATA_HOME" XDG_STATE_HOME="$XDG_STATE_HOME" MARKSHARC_HOME="$MARKSHARC_ROOT" \
    "$fish_bin" --no-config -c '
        set -g MARKSHARC_SESSION interactive
        set -g _ms_fish_reloading 1
        source "$MARKSHARC_HOME/core/fish/marksharc.fish"
        set -e -g _ms_fish_reloading
        set -l before (contains -- "'"$expected_dir"'" $fish_complete_path; and echo yes; or echo no)
        set -l tracked (contains -- "'"$expected_dir"'" $_ms_fish_completion_paths; and echo yes; or echo no)
        set -l legacy (contains -- "$MARKSHARC_HOME/core/fish/completions" $fish_complete_path; and echo yes; or echo no)
        marksharc reload >/dev/null; or exit 2
        set -l count_after (count (string match -e -- "'"$expected_dir"'" $fish_complete_path))
        printf "%s|%s|%s|%s\n" "$before" "$tracked" "$legacy" "$count_after"
    ')
@test "marksharc.fish prepends rendered fish completions, drops legacy path, and deduplicates on reload" "$reload_check" = "yes|yes|no|1"

ms_cleanup
