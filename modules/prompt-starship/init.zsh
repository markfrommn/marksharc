# prompt-starship module, init phase: the config selection, then the cached init, once per
# shell. prompt-starship.config names a file or a preset in presets/<name>.toml; a name or
# path that does not resolve to a readable file leaves STARSHIP_CONFIG as it was. A reload
# removes the value this module set before choosing again.
if [[ -n ${_ms_starship_config-} && ${STARSHIP_CONFIG-} == "$_ms_starship_config" ]]; then
    unset STARSHIP_CONFIG
fi
unset _ms_starship_config
if [[ -n ${_ms_opt_prompt_starship_config-} ]]; then
    typeset -g _ms_starship_file=$_ms_opt_prompt_starship_config
    if [[ $_ms_starship_file != */* ]]; then
        _ms_starship_file=${_ms_mod_dir[prompt-starship]:-$MARKSHARC_HOME/modules/prompt-starship}/presets/$_ms_starship_file.toml
    elif [[ $_ms_starship_file == '~/'* ]]; then
        _ms_starship_file=$HOME/${_ms_starship_file#'~/'}
    fi
    if [[ -r $_ms_starship_file && ! -d $_ms_starship_file ]]; then
        typeset -g _ms_starship_config=$_ms_starship_file
        export STARSHIP_CONFIG=$_ms_starship_file
    fi
    unset _ms_starship_file
fi
(( ${_ms_reloading:-0} )) || _ms_init_cached starship starship init zsh || true
true
