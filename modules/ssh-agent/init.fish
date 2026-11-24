# Once per shell (not on reload); runs late because ssh-add may prompt for a passphrase.
# A failed setup never breaks startup.
if not set -q _ms_fish_reloading
    setup-ssh-agent
end
true
