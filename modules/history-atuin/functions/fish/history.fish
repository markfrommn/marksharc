# history          every atuin entry, oldest first, "<time>  <command>"
# history -N       the last N of those lines
# history <other>  fish's own history function (search, delete, merge, clear)
# When atuin init did not run, ATUIN_SESSION is unset and atuin refuses to list; a fresh
# session id then goes to that one call only.
function history --description 'List the atuin history, or use the fish history'
    if not command -q atuin
        _ms_fish_history_fallback $argv
        return
    end
    set -l fmt '{time}  {command}'
    if test (count $argv) -eq 0
        or begin
            test (count $argv) -eq 1; and string match -qr '^-[0-9]+$' -- "$argv[1]"
        end
        set -lx ATUIN_SESSION "$ATUIN_SESSION"
        test -n "$ATUIN_SESSION"; or set ATUIN_SESSION (command atuin uuid 2>/dev/null)
        if test (count $argv) -eq 0
            command atuin history list --format "$fmt"
        else
            command atuin history list --format "$fmt" | command tail -n (string replace -- - '' "$argv[1]")
        end
    else
        _ms_fish_history_fallback $argv
    end
end

# Fish's own history function when init saved a copy, else the builtin.
function _ms_fish_history_fallback
    if functions -q _ms_fish_history_native
        _ms_fish_history_native $argv
    else
        builtin history $argv
    end
end
