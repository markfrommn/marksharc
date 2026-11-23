# Hook registries for cwf-new (see the function): other modules append to them.
# `cwf shell zsh` is shell integration (exports, aliases and helper functions), not a
# completion definition. Render owns its cached artifact; only interactive init sources it.
typeset -gaU cwf_new_post_create_hooks cwf_new_copy_exclude
if [[ -n ${COMMON_DEV_TOOLS-} && -d $COMMON_DEV_TOOLS ]]; then
    typeset -g _ms_cwf_shell="${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}/completions/zsh/_cwf"
    [[ ! -r $_ms_cwf_shell ]] || source "$_ms_cwf_shell"
    unset _ms_cwf_shell
fi
