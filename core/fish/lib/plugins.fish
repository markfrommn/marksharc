# Load only cached pins. Network operations belong to install and update.
function _ms_fish_plugin_load
    set -l cache "$HOME/.cache"
    set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"; and set cache "$XDG_CACHE_HOME"
    set -l root "$cache/marksharc/plugins/$argv[1]@$argv[2]"
    test -d "$root"; or return 0
    contains -- "$root" $_ms_fish_plugins_loaded; and return 0
    if test -d "$root/functions"; and not contains -- "$root/functions" $fish_function_path
        set -gp fish_function_path "$root/functions"
        set -ga _ms_fish_function_paths "$root/functions"
    end
    if test -d "$root/completions"; and not contains -- "$root/completions" $fish_complete_path
        set -gp fish_complete_path "$root/completions"
        set -ga _ms_fish_completion_paths "$root/completions"
    end
    for file in "$root"/conf.d/*.fish
        test -r "$file"; and source "$file"
    end
    set -ga _ms_fish_plugins_loaded "$root"
    return 0
end
