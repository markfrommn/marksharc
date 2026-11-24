# greeting module, init phase: fortune, once per shell (never on marksharc reload), opt-in
# with "set greeting.fortune on".
if not set -q _ms_fish_reloading; and contains -- "$_ms_opt_greeting_fortune" on 1 yes true
    fortune
end
true
