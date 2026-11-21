# bun module, init phase: bun's completion file is found through fpath, so compinit
# (order 70) registers it; the old startup sourced it before compinit existed.
if [[ -n ${BUN_INSTALL-} && -s $BUN_INSTALL/_bun ]]; then
    typeset -gU fpath
    fpath=( "$BUN_INSTALL" "${fpath[@]}" )
fi
true
