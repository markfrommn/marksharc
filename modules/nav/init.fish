# nav module, init phase. fish already has dirh, prevd, nextd and cdh, and binds Alt-Left and
# Alt-Right to prevd-or-backward-word and nextd-or-forward-word. Alt-Up and Alt-Down add the
# remaining zsh dirhistory moves (parent, first child) on an empty command line.
# zsh setopt equivalents: autocd needs no option (fish runs a bare directory name as cd),
# pushdtohome, pushdsilent and pushdminus are not applicable (fish pushd takes no home default
# and is already quiet), cdablevars is covered by CDPATH.
for mode in default insert
    bind -M $mode alt-up _ms_nav_up
    bind -M $mode alt-down _ms_nav_down
end
true
