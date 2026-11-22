# pnpm module: PNPM_HOME is the existing one of ~/.local/share/pnpm and ~/Library/pnpm
# (the macOS location wins when both exist, as before). It joins the user tier.
if (( ${_ms_env_rebuild:-1} )); then
    typeset -g _ms_pd
    for _ms_pd in "$HOME/.local/share/pnpm" "$HOME/Library/pnpm"; do
        [[ -d $_ms_pd ]] && export PNPM_HOME=$_ms_pd
    done
    unset _ms_pd
    if [[ -n ${PNPM_HOME-} && ${_ms_opt_pnpm_path-on} == (on|1|yes|true) ]] && (( ${+functions[_ms_path_add]} )); then
        _ms_path_add user "$PNPM_HOME"
    fi
fi
true
