# direnv module, init phase: the cached hook, only when the enable option is on.
if contains -- "$_ms_opt_direnv_enable" on 1 yes true; and not set -q _ms_fish_reloading
    _ms_fish_init_cached direnv direnv hook fish
end
true
