# Cobra's generated completion requires the bash-completion word helpers.
if declare -F _get_comp_words_by_ref >/dev/null; then
    _ms_bash_load_generated_completion cwf
fi
