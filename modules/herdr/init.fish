# herdr module, init phase: the generated completion, once per shell. A herdr that cannot
# print it leaves no completion and no output.
if not set -q _ms_fish_reloading; and _ms_fish_command_available herdr
    _ms_fish_init_cached herdr herdr completion fish
end
true
