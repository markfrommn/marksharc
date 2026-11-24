# prompt-starship module, init phase: cached init, once per shell.
if not set -q _ms_fish_reloading
    _ms_fish_init_cached starship starship init fish
end
true
