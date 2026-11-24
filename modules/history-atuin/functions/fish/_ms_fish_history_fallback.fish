# Fish's own history function when init saved a copy, else the builtin.
function _ms_fish_history_fallback
    if functions -q _ms_fish_history_native
        _ms_fish_history_native $argv
    else
        builtin history $argv
    end
end
