# -*- mode: shell-script; sh-shell: zsh -*-
# Warm-start rendered-environment loading. Generator code stays in render.zsh and
# is parsed only when an input fingerprint is stale.

# Validate artifacts needed by an inheriting shell. Missing env or an explicitly
# rendered completion set requires recovery; an env-only render has no completion
# id and correctly imposes no generator work on the child.
_ms_render_cache_valid() {
    emulate -L zsh
    local require_completions=${1:-0}
    local cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}
    local current= completed= file
    [[ -r $cache/render-id && -r $cache/env.zsh && -r $cache/env.bash && -r $cache/bash-context ]] || return 1
    current=$(<"$cache/render-id")
    [[ $current == "$_ms_env_id_value" ]] || return 1
    (( require_completions )) && [[ ! -r $cache/completion-id ]] && return 1
    if [[ -r $cache/completion-id ]]; then
        completed=$(<"$cache/completion-id")
        [[ $completed == "$_ms_env_id_value" && -d $cache/completions/zsh && -r $cache/completion-files ]] || return 1
        for file in "${(@f)$(<"$cache/completion-files")}"; do
            [[ -z $file || -r $cache/completions/zsh/$file ]] || return 1
        done
    fi
    (( require_completions )) && [[ ! -r $cache/shim-id ]] && return 1
    if [[ -r $cache/shim-id ]]; then
        completed=$(<"$cache/shim-id")
        [[ $completed == "$_ms_env_id_value" && -d $cache/bin && -r $cache/shim-files ]] || return 1
        for file in "${(@f)$(<"$cache/shim-files")}"; do
            [[ -z $file || -x $cache/bin/$file ]] || return 1
        done
    fi
    return 0
}

# Refresh stale rendered inputs. The ordinary startup path (full=0) never runs a
# completion generator; install, explicit render, update and reload use full=1.
_ms_render_refresh() {
    emulate -L zsh
    local full=${1:-0} cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}
    local current= need=0 generate=0
    [[ -r $cache/render-id ]] && current=$(<"$cache/render-id")
    [[ -n $_ms_env_id_value && -r $cache/env.zsh && -r $cache/env.bash && -r $cache/bash-context && $current == "$_ms_env_id_value" ]] || need=1
    [[ -z ${MARKSHARC_FORCE_BASH_RENDER-} ]] || need=1
    if (( full )); then
        _ms_render_cache_valid 1 || need=1
        (( need )) && generate=1
    fi
    (( need )) || return 0
    source "$MARKSHARC_HOME/core/zsh/lib/render.zsh"
    _ms_render $generate
}

# Snapshot the active plan before a render. Activation is transactional: the old
# rendered function and aliases stay live until a replacement render succeeds.
_ms_render_reset() {
    emulate -L zsh
    if (( ${+_ms_mod_names} )); then typeset -ga _ms_render_saved_mod_names=( "${_ms_mod_names[@]}" ); else typeset -ga _ms_render_saved_mod_names=(); fi
    if (( ${+_ms_mod_dir} )); then typeset -gA _ms_render_saved_mod_dir=( "${(@kv)_ms_mod_dir}" ); else typeset -gA _ms_render_saved_mod_dir=(); fi
    if (( ${+_ms_mod_describe} )); then typeset -gA _ms_render_saved_mod_describe=( "${(@kv)_ms_mod_describe}" ); else typeset -gA _ms_render_saved_mod_describe=(); fi
    if (( ${+_ms_mod_order} )); then typeset -gA _ms_render_saved_mod_order=( "${(@kv)_ms_mod_order}" ); else typeset -gA _ms_render_saved_mod_order=(); fi
    if (( ${+_ms_mod_req_cmd} )); then typeset -gA _ms_render_saved_mod_req_cmd=( "${(@kv)_ms_mod_req_cmd}" ); else typeset -gA _ms_render_saved_mod_req_cmd=(); fi
    if (( ${+_ms_mod_req_os} )); then typeset -gA _ms_render_saved_mod_req_os=( "${(@kv)_ms_mod_req_os}" ); else typeset -gA _ms_render_saved_mod_req_os=(); fi
    if (( ${+_ms_mod_options} )); then typeset -gA _ms_render_saved_mod_options=( "${(@kv)_ms_mod_options}" ); else typeset -gA _ms_render_saved_mod_options=(); fi
    if (( ${+_ms_mod_optdef} )); then typeset -gA _ms_render_saved_mod_optdef=( "${(@kv)_ms_mod_optdef}" ); else typeset -gA _ms_render_saved_mod_optdef=(); fi
    if (( ${+_ms_mod_enabled} )); then typeset -gA _ms_render_saved_mod_enabled=( "${(@kv)_ms_mod_enabled}" ); else typeset -gA _ms_render_saved_mod_enabled=(); fi
    if (( ${+_ms_cfg_set} )); then typeset -gA _ms_render_saved_cfg_set=( "${(@kv)_ms_cfg_set}" ); else typeset -gA _ms_render_saved_cfg_set=(); fi
    if (( ${+_ms_cfg_enabled} )); then typeset -gA _ms_render_saved_cfg_enabled=( "${(@kv)_ms_cfg_enabled}" ); else typeset -gA _ms_render_saved_cfg_enabled=(); fi
    typeset -g _ms_render_saved_cfg_explicit=${_ms_cfg_explicit:-0}
    typeset -g _ms_render_saved_core_dot=${_ms_opt_core_dot_in_path-off}
    typeset -g _ms_render_saved_metadata_loaded=${_ms_render_metadata_loaded:-0}
    typeset -g _ms_render_metadata_loaded=0
    return 0
}

# Discard the snapshot after a successful render, then retire the old owned state
# before _ms_render_load activates the new artifact.
_ms_render_activate() {
    emulate -L zsh
    local name
    for name in "${_ms_rendered_aliases[@]}"; do unalias "$name" 2>/dev/null; done
    for name in "${_ms_rendered_exports[@]}"; do [[ -n $name ]] && unset "$name"; done
    unfunction _ms_rendered_env 2>/dev/null
    unset _ms_rendered_modules _ms_rendered_aliases _ms_rendered_exports
    unset _ms_render_saved_mod_names _ms_render_saved_mod_dir _ms_render_saved_mod_describe
    unset _ms_render_saved_mod_order _ms_render_saved_mod_req_cmd _ms_render_saved_mod_req_os
    unset _ms_render_saved_mod_options _ms_render_saved_mod_optdef _ms_render_saved_mod_enabled
    unset _ms_render_saved_cfg_set _ms_render_saved_cfg_enabled _ms_render_saved_cfg_explicit
    unset _ms_render_saved_core_dot _ms_render_saved_metadata_loaded
    return 0
}

# Restore the last good active plan after a failed render. Its env.zsh was not
# replaced, so the still-live rendered function matches these tables again.
_ms_render_restore() {
    emulate -L zsh
    typeset -ga _ms_mod_names=( "${_ms_render_saved_mod_names[@]}" )
    typeset -gA _ms_mod_dir=( "${(@kv)_ms_render_saved_mod_dir}" )
    typeset -gA _ms_mod_describe=( "${(@kv)_ms_render_saved_mod_describe}" )
    typeset -gA _ms_mod_order=( "${(@kv)_ms_render_saved_mod_order}" )
    typeset -gA _ms_mod_req_cmd=( "${(@kv)_ms_render_saved_mod_req_cmd}" )
    typeset -gA _ms_mod_req_os=( "${(@kv)_ms_render_saved_mod_req_os}" )
    typeset -gA _ms_mod_options=( "${(@kv)_ms_render_saved_mod_options}" )
    typeset -gA _ms_mod_optdef=( "${(@kv)_ms_render_saved_mod_optdef}" )
    typeset -gA _ms_mod_enabled=( "${(@kv)_ms_render_saved_mod_enabled}" )
    typeset -gA _ms_cfg_set=( "${(@kv)_ms_render_saved_cfg_set}" )
    typeset -gA _ms_cfg_enabled=( "${(@kv)_ms_render_saved_cfg_enabled}" )
    typeset -g _ms_cfg_explicit=$_ms_render_saved_cfg_explicit
    typeset -g _ms_opt_core_dot_in_path=$_ms_render_saved_core_dot
    typeset -g _ms_render_metadata_loaded=$_ms_render_saved_metadata_loaded
    unset _ms_render_saved_mod_names _ms_render_saved_mod_dir _ms_render_saved_mod_describe
    unset _ms_render_saved_mod_order _ms_render_saved_mod_req_cmd _ms_render_saved_mod_req_os
    unset _ms_render_saved_mod_options _ms_render_saved_mod_optdef _ms_render_saved_mod_enabled
    unset _ms_render_saved_cfg_set _ms_render_saved_cfg_enabled _ms_render_saved_cfg_explicit
    unset _ms_render_saved_core_dot _ms_render_saved_metadata_loaded
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
