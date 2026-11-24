# prompt-starship module, init phase: the config selection, then the cached init, once per
# shell. prompt-starship.config names a file or a preset in presets/<name>.toml; a name or
# path that does not resolve to a readable file leaves STARSHIP_CONFIG as it was. A reload
# removes the value this module set before choosing again.
if set -q _ms_fish_starship_config; and test "$STARSHIP_CONFIG" = "$_ms_fish_starship_config"
    set -e STARSHIP_CONFIG
end
set -e _ms_fish_starship_config
if test -n "$_ms_opt_prompt_starship_config"
    set -l file "$_ms_opt_prompt_starship_config"
    if not string match -q '*/*' -- "$file"
        set file "$MARKSHARC_HOME/modules/prompt-starship/presets/$file.toml"
    else if string match -q '~/*' -- "$file"
        set file "$HOME/"(string sub -s 3 -- "$file")
    end
    if test -r "$file"; and not test -d "$file"
        set -g _ms_fish_starship_config "$file"
        set -gx STARSHIP_CONFIG "$file"
    end
end
if not set -q _ms_fish_reloading
    _ms_fish_init_cached starship starship init fish
end
true
