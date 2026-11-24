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

set -l __ms_commands reload render sync bootstrap update install doctor module uninstall version help
complete -c marksharc -f
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a reload -d 'Reload the current shell'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a render -d 'Render env and completions to the cache'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a sync -d 'Fast-forward checkouts and refresh pins'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a bootstrap -d 'Install declared packages'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a update -d 'Sync, refresh pins and run module updates'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a install -d 'Run a registered installer'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a doctor -d 'Report installation health'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a module -d 'List, enable or disable modules'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a uninstall -d 'Restore dotfiles and remove the stubs'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a version -d 'Print the version'
complete -c marksharc -n "not __fish_seen_subcommand_from $__ms_commands" -a help -d 'Print the help'
complete -c marksharc -n '__fish_seen_subcommand_from reload' -s v -l verbose -d 'Print the module trace'
complete -c marksharc -n '__fish_seen_subcommand_from update' -l list -d 'List the update steps'
complete -c marksharc -n '__fish_seen_subcommand_from update' -l dry-run -d 'Show what would run'
complete -c marksharc -n '__fish_seen_subcommand_from update' -l only -r -d 'Run one labelled step'
complete -c marksharc -n '__fish_seen_subcommand_from uninstall' -l purge -d 'Also delete cache and state'
complete -c marksharc -n '__fish_seen_subcommand_from uninstall' -l yes -d 'Answer yes to the purge prompt'
complete -c marksharc -n '__fish_seen_subcommand_from module; and not __fish_seen_subcommand_from list enable disable' -a list -d 'List modules with their status'
complete -c marksharc -n '__fish_seen_subcommand_from module; and not __fish_seen_subcommand_from list enable disable' -a enable -d 'Enable a module'
complete -c marksharc -n '__fish_seen_subcommand_from module; and not __fish_seen_subcommand_from list enable disable' -a disable -d 'Disable a module'
complete -c marksharc -n '__fish_seen_subcommand_from module; and __fish_seen_subcommand_from enable disable' -a '(__ms_complete_modules)'
