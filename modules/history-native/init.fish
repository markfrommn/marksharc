# history-native module, init phase (spec 6.12): the fallback for hosts without atuin. Fish's
# own history file (fish_history under the data directory) is the store; only h is added.
# When atuin is installed the history-atuin module owns history and this file does nothing.
if not command -q atuin
    function h --description 'The last 35 history entries'
        builtin history search --max 35 --reverse
    end
end
true
