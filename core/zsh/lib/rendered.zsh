# -*- mode: shell-script; sh-shell: zsh -*-
# Warm-start rendered-environment loading. Generator code stays in render.zsh and
# is parsed only when an input fingerprint is stale.

# Refresh stale rendered inputs. The ordinary startup path (full=0) never runs a
# completion generator; install, explicit render, update and reload use full=1.
_ms_render_refresh() {
    emulate -L zsh
    local full=${1:-0} cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}
    local current= completed= need=0 generate=0
    [[ -r $cache/render-id ]] && current=$(<"$cache/render-id")
    [[ -n $_ms_env_id_value && -r $cache/env.zsh && $current == "$_ms_env_id_value" ]] || need=1
    if (( full )); then
        [[ -r $cache/completion-id ]] && completed=$(<"$cache/completion-id")
        [[ $completed == "$_ms_env_id_value" ]] || need=1
        (( need )) && generate=1
    fi
    (( need )) || return 0
    source "$MARKSHARC_HOME/core/zsh/lib/render.zsh"
    _ms_render $generate
}

# Remove aliases owned by the previous render before a reload applies a new plan.
_ms_render_reset() {
    emulate -L zsh
    local name
    for name in "${_ms_rendered_aliases[@]}"; do unalias "$name" 2>/dev/null; done
    unfunction _ms_rendered_env 2>/dev/null
    unset _ms_rendered_modules _ms_rendered_aliases
    typeset -g _ms_render_metadata_loaded=0
    return 0
}

# Load only the artifact stamped for the inputs just fingerprinted by _ms_env_id.
_ms_render_load() {
    emulate -L zsh
    local cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}} current=
    [[ -r $cache/render-id ]] && current=$(<"$cache/render-id")
    [[ -n $_ms_env_id_value && $current == "$_ms_env_id_value" && -r $cache/env.zsh ]] || return 0
    unfunction _ms_rendered_env 2>/dev/null
    source "$cache/env.zsh"
}
