# Completions for the marksharc command (core/fish/marksharc.fish adds this directory).
function __ms_complete_modules
    set -l config "$HOME/.config/marksharc"
    if set -q MARKSHARC_CONFIG; and test -n "$MARKSHARC_CONFIG"
        set config "$MARKSHARC_CONFIG"
    else if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        set config "$XDG_CONFIG_HOME/marksharc"
    end
    for conf in "$MARKSHARC_HOME"/modules/*/module.conf "$config"/modules/*/module.conf
        path basename (path dirname "$conf")
    end | sort -u
end

function __ms_complete_hosts
    set -l config "$HOME/.config/marksharc"
    if set -q MARKSHARC_CONFIG; and test -n "$MARKSHARC_CONFIG"
        set config "$MARKSHARC_CONFIG"
    else if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
        set config "$XDG_CONFIG_HOME/marksharc"
    end
    set -l hosts_file "$config/hosts.conf"
    test -r "$hosts_file"; or return 0
    while read -l line
        set line (string trim -- "$line")
        test -n "$line"; or continue
        string match -qr '^#' -- "$line"; and continue
        set -l parts (string split -n ' ' -- "$line")
        if test "$parts[1]" = host; and test (count $parts) -ge 2
            echo $parts[2]
        else if test (count $parts) -eq 1
            echo $parts[1]
        end
    end <"$hosts_file"
end

set -l __ms_commands reload render sync push hosts bootstrap update install doctor module uninstall version help
complete -c marksharc -f
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a reload -d 'Reload the current shell'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a render -d 'Render env and completions to the cache'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a sync -d 'Fast-forward checkouts and refresh pins'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a push -d 'Run sync over SSH across hosts in parallel'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a hosts -d 'Manage the hosts.conf push inventory'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a bootstrap -d 'Install declared packages'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a update -d 'Sync, refresh pins and run module updates'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a install -d 'Run a registered installer'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a doctor -d 'Report installation health'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a module -d 'List, enable or disable modules'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a uninstall -d 'Restore dotfiles and remove the stubs'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a version -d 'Print the version'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a help -d 'Print the help'
complete -c marksharc -n '__fish_seen_subcommand_from reload' -s v -l verbose -d 'Print the module trace'
complete -c marksharc -n '__fish_seen_subcommand_from sync; and not __fish_seen_subcommand_from timer' -l auto -d 'Quiet, locked background sync skipping dirty trees'
complete -c marksharc -n '__fish_seen_subcommand_from sync; and not __fish_seen_subcommand_from timer' -l update -d 'Run the full marksharc update'
complete -c marksharc -n '__fish_seen_subcommand_from sync; and not __fish_seen_subcommand_from timer' -l system -d 'With --update, include native OS package updates'
complete -c marksharc -n '__fish_seen_subcommand_from sync; and not __fish_seen_subcommand_from timer' -s y -l yes -d 'With --update, pass -y to supported commands'
complete -c marksharc -n '__fish_seen_subcommand_from sync; and not __fish_seen_subcommand_from timer' -a timer -d 'Manage the automatic sync timer'
complete -c marksharc -n '__fish_seen_subcommand_from sync; and __fish_seen_subcommand_from timer; and not __fish_seen_subcommand_from on off status' -a 'on off status' -d 'Enable, disable or inspect the sync timer'
complete -c marksharc -n '__fish_seen_subcommand_from push' -l update -d 'Run marksharc sync --update on remote hosts'
complete -c marksharc -n '__fish_seen_subcommand_from push' -l system -d 'Include native OS package updates on remote hosts'
complete -c marksharc -n '__fish_seen_subcommand_from push' -s y -l yes -d 'Pass -y to supported remote update commands'
complete -c marksharc -n '__fish_seen_subcommand_from push' -l timeout -r -d 'Per-host timeout in seconds'
complete -c marksharc -n '__fish_seen_subcommand_from push' -l max-parallel -r -d 'Maximum concurrent SSH jobs'
complete -c marksharc -n '__fish_seen_subcommand_from push' -l dry-run -d 'Show matched hosts and SSH commands'
complete -c marksharc -n '__fish_seen_subcommand_from push' -s v -l verbose -d 'Print full per-host output'
complete -c marksharc -n '__fish_seen_subcommand_from push' -l populate -d 'Populate hosts.conf interactively'
complete -c marksharc -n '__fish_seen_subcommand_from push' -a '(__ms_complete_hosts)'
complete -c marksharc -n '__fish_seen_subcommand_from hosts; and not __fish_seen_subcommand_from list populate add remove' -a list -d 'List configured hosts'
complete -c marksharc -n '__fish_seen_subcommand_from hosts; and not __fish_seen_subcommand_from list populate add remove' -a populate -d 'Discover hosts from ssh config and hc'
complete -c marksharc -n '__fish_seen_subcommand_from hosts; and not __fish_seen_subcommand_from list populate add remove' -a add -d 'Add a host to hosts.conf'
complete -c marksharc -n '__fish_seen_subcommand_from hosts; and not __fish_seen_subcommand_from list populate add remove' -a remove -d 'Remove a host from hosts.conf'
complete -c marksharc -n '__fish_seen_subcommand_from hosts; and __fish_seen_subcommand_from populate' -l all -d 'Add all discovered hosts without a picker'
complete -c marksharc -n '__fish_seen_subcommand_from hosts; and __fish_seen_subcommand_from populate' -l source -r -a 'ssh hc all' -d 'Limit discovery to one source'
complete -c marksharc -n '__fish_seen_subcommand_from hosts; and __fish_seen_subcommand_from remove' -a '(__ms_complete_hosts)'
complete -c marksharc -n '__fish_seen_subcommand_from update' -l list -d 'List the update steps'
complete -c marksharc -n '__fish_seen_subcommand_from update' -l dry-run -d 'Show what would run'
complete -c marksharc -n '__fish_seen_subcommand_from update' -l only -r -d 'Run one labelled step'
complete -c marksharc -n '__fish_seen_subcommand_from update' -l system -d 'Also run native OS package updates'
complete -c marksharc -n '__fish_seen_subcommand_from update' -s y -l yes -d 'Pass -y to supported update commands'
complete -c marksharc -n '__fish_seen_subcommand_from uninstall' -l purge -d 'Also delete cache and state'
complete -c marksharc -n '__fish_seen_subcommand_from uninstall' -l yes -d 'Answer yes to the purge prompt'
complete -c marksharc -n '__fish_seen_subcommand_from module; and not __fish_seen_subcommand_from list enable disable' -a list -d 'List modules with their status'
complete -c marksharc -n '__fish_seen_subcommand_from module; and not __fish_seen_subcommand_from list enable disable' -a enable -d 'Enable a module'
complete -c marksharc -n '__fish_seen_subcommand_from module; and not __fish_seen_subcommand_from list enable disable' -a disable -d 'Disable a module'
complete -c marksharc -n '__fish_seen_subcommand_from module; and __fish_seen_subcommand_from enable disable' -a '(__ms_complete_modules)'
