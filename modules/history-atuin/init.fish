# history-atuin module, init phase (spec 6.12): cached atuin init (Ctrl-R, Up, hooks), once per
# shell. Fish keeps its own history file: its autosuggestions read it, and atuin records beside it.
# The history and h functions are autoloaded from functions/fish. Fish's own history function
# (search, delete, merge, clear with its confirmation) stays reachable as
# _ms_fish_history_native for every form the atuin listing does not take.
# An erased name never autoloads again, so the module's history is sourced over fish's.
if not functions -q _ms_fish_history_native; and test -r "$__fish_data_dir/functions/history.fish"
    source "$__fish_data_dir/functions/history.fish"
    functions -c history _ms_fish_history_native
end
source (status dirname)/functions/fish/history.fish
_ms_fish_track_functions history
if not set -q _ms_fish_reloading
    _ms_fish_init_cached atuin atuin init fish
end
true
