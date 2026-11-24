# command-not-found module, init phase: Homebrew's handler when it is installed. Otherwise
# fish's own fish_command_not_found stays in charge; it already asks /usr/lib/command-not-found
# (apt) and the other distribution providers, and prints fish's usual message.
set -l brew_bin (command -s brew)
if test -n "$brew_bin"
    set -l handler (path dirname (path dirname (path resolve -- "$brew_bin")))/Library/Homebrew/command-not-found/handler.fish
    if test -r "$handler"
        source "$handler"
    end
end
true
