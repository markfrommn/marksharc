# brew module, init phase: cached "brew shellenv" (HOMEBREW_* variables, fpath, MANPATH).
# Runs before completion (order 70) so brew's site-functions are on fpath for compinit.
setup-homebrew || true
true
