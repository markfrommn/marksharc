# Hook registries for cwf-new (see the function): other modules append to them.
# `cwf shell fish` is shell integration (exports, aliases and helper functions), keyed on the
# directory that holds the tool; it is sourced once per shell, not on reload.
set -q cwf_new_post_create_hooks; or set -g cwf_new_post_create_hooks
set -q cwf_new_copy_exclude; or set -g cwf_new_copy_exclude
if test -n "$COMMON_DEV_TOOLS"; and test -d "$COMMON_DEV_TOOLS"; and not set -q _ms_fish_reloading
    _ms_fish_init_cached -k "$COMMON_DEV_TOOLS" cwf cwf shell fish
end
true
