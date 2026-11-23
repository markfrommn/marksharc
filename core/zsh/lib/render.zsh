# -*- mode: shell-script; sh-shell: zsh -*-
# Declarative module and overlay renderer (spec 6.5). Values are tokenised by
# _ms_words and quoted into native zsh; directive text is never evaluated.

# Build the runtime guard expression for reply[start,-1]. OS and host guards are
# settled now; command, dir and file guards stay in the rendered file. Returns 1
# when a render-time guard excludes the line, 2 for malformed guard syntax.
_ms_render_guard_expression() {
    emulate -L zsh
    integer i=$1
    local type value
    local -a runtime=()
    REPLY=
    while (( i <= $#reply )); do
        [[ ${reply[i]-} == when ]] || return 2
        type=${reply[i+1]-} value=${reply[i+2]-}
        [[ -n $value ]] || return 2
        case $type in
            os) [[ $value == "$MARKSHARC_OS" ]] || return 1 ;;
            host) [[ $value == "$MARKSHARC_HOST" ]] || return 1 ;;
            command) runtime+=( "_ms_command_available ${(qq)value}" ) ;;
            dir) runtime+=( "_ms_render_dir ${(qq)value}" ) ;;
            file) runtime+=( "_ms_render_file ${(qq)value}" ) ;;
            *) return 2 ;;
        esac
        (( i += 3 ))
    done
    REPLY=${(j: && :)runtime}
    return 0
}

# Evaluate completion guards while rendering. A completion is an artifact, so unlike
# env/path/alias guards these decide whether its generator runs now.
_ms_render_completion_guards() {
    emulate -L zsh
    integer i=$1
    local type value
    while (( i <= $#reply )); do
        [[ ${reply[i]-} == when ]] || return 1
        type=${reply[i+1]-} value=${reply[i+2]-}
        [[ -n $value ]] || return 1
        case $type in
            os) [[ $value == "$MARKSHARC_OS" ]] || return 1 ;;
            host) [[ $value == "$MARKSHARC_HOST" ]] || return 1 ;;
            command) _ms_command_available "$value" || return 1 ;;
            dir) _ms_render_dir "$value" || return 1 ;;
            file) _ms_render_file "$value" || return 1 ;;
            *) return 1 ;;
        esac
        (( i += 3 ))
    done
    return 0
}

# Resolve a command in declarative paths contributed earlier in this render. The
# caller's inherited PATH is checked first by _ms_command_available; no native
# module code or external probe is run for the pending entries.
_ms_render_pending_command() {
    emulate -L zsh
    local name=$1 dir candidate
    [[ -n $name && $name != */* ]] || return 1
    for dir in "${_ms_render_pending_paths[@]}"; do
        if (( $+functions[_ms_fs_path] )); then
            _ms_fs_path "$dir/$name"
            candidate=$REPLY
        elif [[ -n ${_ms_fs_root-} && $dir != "$HOME" && $dir != "$HOME"/* ]]; then
            candidate=${_ms_fs_root}$dir/$name
        else
            candidate=$dir/$name
        fi
        [[ -x $candidate && ! -d $candidate ]] && { REPLY=$candidate; return 0; }
    done
    return 1
}
_ms_command_pending() { _ms_render_pending_command "$1"; }

# Print the native statements for the env/path/alias lines in one conf file.
_ms_render_conf() {
    emulate -L zsh
    local file=$1 module=$2 line kind name value guard out
    local -a generator=()
    integer i end module_ready=1
    [[ -r $file ]] || return 0
    if [[ -n $module ]]; then _ms_module_requires_command "$module" || module_ready=0; fi
    while IFS= read -r line || [[ -n $line ]]; do
        _ms_words "$line" || continue
        kind=${reply[1]}
        case $kind in
            env)
                name=${reply[2]-} value=${reply[3]-}
                [[ $name =~ '^[A-Za-z_][A-Za-z0-9_]*$' && $#reply -ge 3 ]] || continue
                _ms_render_guard_expression 4 || continue
                guard="(( \${_ms_env_rebuild:-1} ))"
                [[ -z $REPLY ]] || guard+=" && $REPLY"
                print -r -- "            $guard && export $name=${(qq)value}"
                print -r -- "            $guard && _ms_rendered_exports+=( ${(q)name} )"
                print -r -- "            (( \${_ms_env_rebuild:-1} )) || { [[ \${$name+x} && \${$name-} == ${(qq)value} ]] && _ms_rendered_exports+=( ${(q)name} ); }"
                ;;
            path)
                name=${reply[2]-} value=${reply[3]-}
                [[ $name =~ '^[A-Za-z0-9_-]+$' && -n $value ]] || continue
                _ms_render_guard_expression 4 || continue
                guard="(( \${+functions[_ms_path_add]} )) && (( \${_ms_env_rebuild:-1} ))"
                [[ -z $REPLY ]] || guard+=" && $REPLY"
                print -r -- "            $guard && _ms_path_add $name ${(qq)value}"
                if (( module_ready )) && _ms_render_completion_guards 4 && _ms_render_dir "$value"; then
                    (( ${_ms_render_pending_paths[(Ie)$value]} )) || _ms_render_pending_paths+=( "$value" )
                fi
                ;;
            alias)
                name=${reply[2]-} value=${reply[3]-}
                [[ -n $name && $name != *=* && $#reply -ge 3 ]] || continue
                _ms_render_guard_expression 4 || continue
                guard="[[ \$MARKSHARC_SESSION == interactive ]]"
                [[ -z $REPLY ]] || guard+=" && $REPLY"
                print -r -- "            $guard && alias ${(qq)name}=${(qq)value}"
                print -r -- "            $guard && _ms_rendered_aliases+=( ${(q)name} )"
                ;;
            completion)
                (( module_ready )) || continue
                name=${reply[2]-}
                [[ $name =~ '^[A-Za-z0-9_][A-Za-z0-9+_.-]*$' && $#reply -ge 3 ]] || continue
                end=$(( $#reply + 1 ))
                for (( i = 3; i <= $#reply; i++ )); do
                    if [[ ${reply[i]} == when ]]; then end=$i; break; fi
                done
                (( end > 3 )) || continue
                generator=( "${(@)reply[3,end-1]}" )
                _ms_render_completion_guards $end || continue
                (( _ms_render_generate )) || continue
                if [[ ${generator[1]} != */* ]] && ! whence -p -- "${generator[1]}" >/dev/null 2>&1; then
                    _ms_render_pending_command "${generator[1]}" && generator[1]=$REPLY
                fi
                out=$_ms_render_stage/zsh/_$name
                if command "${generator[@]}" > "$out" 2>/dev/null; then
                    _ms_render_completion_files+=( "_$name" )
                else
                    _ms_render_failed=1
                    _ms_trace "completion $name: generator failed"
                fi
                ;;
        esac
    done < "$file"
    return 0
}

# Does a conf file carry env-phase directives? Completion-only modules do not need
# a runtime case or a per-module call in every shell.
_ms_render_has_env_conf() {
    emulate -L zsh
    local file=$1 line
    [[ -r $file ]] || return 1
    while IFS= read -r line || [[ -n $line ]]; do
        _ms_words "$line" || continue
        [[ ${reply[1]} == (env|path|alias) ]] && return 0
    done < "$file"
    return 1
}

# Render the current module plan and overlay. The caller has computed the input id.
_ms_render() {
    emulate -L zsh
    local cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}
    local config=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}
    local tmp=$cache/env.zsh.tmp.$$ bash_tmp=$cache/env.bash.tmp.$$ name old key file
    local -a entries=() envplan=() dirs=() reqcmds=() reqos=() options=() optdefs=() _ms_render_pending_paths=() _ms_render_completion_files=() _ms_render_shim_files=()
    local _ms_render_generate=${1:-1} _ms_render_stage=$cache/completions.tmp.$$ _ms_shims_stage=$cache/bin.tmp.$$
    integer _ms_render_failed=0
    _ms_modules_plan env
    for name in "${_ms_plan[@]}"; do
        dirs+=( "$name" "${_ms_mod_dir[$name]}" )
        [[ -z ${_ms_mod_req_cmd[$name]-} ]] || reqcmds+=( "$name" "${_ms_mod_req_cmd[$name]}" )
        [[ -z ${_ms_mod_req_os[$name]-} ]] || reqos+=( "$name" "${_ms_mod_req_os[$name]}" )
        [[ -z ${_ms_mod_options[$name]-} ]] || options+=( "$name" "${_ms_mod_options[$name]}" )
        for key in ${=_ms_mod_options[$name]-}; do
            optdefs+=( "$name.$key" "${_ms_mod_optdef[$name.$key]-}" )
        done
        if _ms_render_has_env_conf "${_ms_mod_dir[$name]}/module.conf"; then
            envplan+=( "$name" )
            entries+=( "$name" 1 )
        fi
    done
    [[ -d $cache ]] || command mkdir -p -- "$cache" 2>/dev/null || return 1
    if (( _ms_render_generate )); then
        command mkdir -p -- "$_ms_render_stage/zsh" || return 1
        command mkdir -m 700 -- "$_ms_shims_stage" || { command rm -rf -- "$_ms_render_stage"; return 1; }
        if [[ -r $MARKSHARC_HOME/core/zsh/lib/shims.zsh ]]; then
            source "$MARKSHARC_HOME/core/zsh/lib/shims.zsh"
            _ms_shims_render "$_ms_shims_stage" || {
                command rm -rf -- "$_ms_render_stage" "$_ms_shims_stage"
                return 1
            }
        fi
        for file in "$_ms_shims_stage"/*(N); do _ms_render_shim_files+=( "${file:t}" ); done
    fi
    {
        print -r -- '# Generated by marksharc render; do not edit.'
        print -r -- "# render id: $_ms_env_id_value"
        print -r -- "typeset -gA _ms_rendered_modules=( ${(j: :)entries} )"
        print -r -- "typeset -ga _ms_mod_names=( ${(j: :)${(@qq)_ms_plan}} )"
        print -r -- "typeset -gA _ms_mod_dir=( ${(j: :)${(@qq)dirs}} )"
        print -r -- "typeset -gA _ms_mod_req_cmd=( ${(j: :)${(@qq)reqcmds}} )"
        print -r -- "typeset -gA _ms_mod_req_os=( ${(j: :)${(@qq)reqos}} )"
        print -r -- "typeset -gA _ms_mod_options=( ${(j: :)${(@qq)options}} )"
        print -r -- "typeset -gA _ms_mod_optdef=( ${(j: :)${(@qq)optdefs}} )"
        print -r -- 'typeset -g _ms_render_metadata_loaded=1'
        print -r -- 'typeset -gaU _ms_rendered_aliases=() _ms_rendered_exports=()'
        print -r -- '_ms_rendered_env() {'
        print -r -- '    emulate -L zsh'
        print -r -- '    case $1 in'
        for name in "${_ms_plan[@]}"; do
            (( ${envplan[(Ie)$name]} )) && print -r -- "        $name)"
            _ms_render_conf "${_ms_mod_dir[$name]}/module.conf" "$name"
            (( ${envplan[(Ie)$name]} )) && print -r -- '            ;;'
        done
        print -r -- '        overlay)'
        _ms_render_conf "$config/config.conf"
        _ms_render_conf "$config/hosts/$MARKSHARC_HOST.conf"
        print -r -- '            ;;'
        print -r -- '    esac'
        print -r -- '}'
    } > "$tmp" || { command rm -rf -- "$tmp" "$_ms_render_stage" "$_ms_shims_stage"; return 1; }
    source "$MARKSHARC_HOME/core/zsh/lib/render-bash.zsh"
    _ms_render_bash > "$bash_tmp" || { command rm -rf -- "$tmp" "$bash_tmp" "$_ms_render_stage" "$_ms_shims_stage"; return 1; }
    if (( _ms_render_failed )); then
        command rm -rf -- "$tmp" "$bash_tmp" "$_ms_render_stage" "$_ms_shims_stage"
        return 1
    fi
    command mv -f -- "$bash_tmp" "$cache/env.bash" || { command rm -rf -- "$tmp" "$bash_tmp" "$_ms_render_stage" "$_ms_shims_stage"; return 1; }
    { printf '%s\n' "$HOME" "$MARKSHARC_HOME" "$config" "$_ms_env_id_value"; } > "$cache/bash-context.tmp.$$" && \
        command mv -f -- "$cache/bash-context.tmp.$$" "$cache/bash-context" || return 1
    command mv -f -- "$tmp" "$cache/env.zsh" || { command rm -rf -- "$tmp" "$_ms_render_stage" "$_ms_shims_stage"; return 1; }
    print -r -- "$_ms_env_id_value" > "$cache/render-id.tmp.$$" && \
        command mv -f -- "$cache/render-id.tmp.$$" "$cache/render-id" || {
        command rm -rf -- "$cache/render-id.tmp.$$" "$_ms_render_stage" "$_ms_shims_stage"
        return 1
    }
    if (( _ms_render_generate )); then
        old=$cache/bin.old.$$
        command rm -rf -- "$old"
        [[ ! -d $cache/bin ]] || command mv -f -- "$cache/bin" "$old" || {
            command rm -rf -- "$_ms_render_stage" "$_ms_shims_stage"
            return 1
        }
        command mv -f -- "$_ms_shims_stage" "$cache/bin" || {
            [[ ! -d $old ]] || command mv -f -- "$old" "$cache/bin"
            command rm -rf -- "$_ms_render_stage" "$_ms_shims_stage"
            return 1
        }
        command rm -rf -- "$old"
        for name in "${_ms_render_shim_files[@]}"; do print -r -- "$name"; done > "$cache/shim-files.tmp.$$" && \
            command mv -f -- "$cache/shim-files.tmp.$$" "$cache/shim-files" || return 1
        print -r -- "$_ms_env_id_value" > "$cache/shim-id.tmp.$$" && \
            command mv -f -- "$cache/shim-id.tmp.$$" "$cache/shim-id" || return 1
        old=$cache/completions.old.$$
        command rm -rf -- "$old"
        [[ ! -d $cache/completions ]] || command mv -f -- "$cache/completions" "$old" || {
            command rm -rf -- "$_ms_render_stage" "$old"
            return 1
        }
        command mv -f -- "$_ms_render_stage" "$cache/completions" || {
            [[ ! -d $old ]] || command mv -f -- "$old" "$cache/completions"
            return 1
        }
        command rm -rf -- "$old"
        for name in "${_ms_render_completion_files[@]}"; do print -r -- "$name"; done > "$cache/completion-files.tmp.$$" && \
            command mv -f -- "$cache/completion-files.tmp.$$" "$cache/completion-files" || {
            command rm -f -- "$cache/completion-files.tmp.$$"
            return 1
        }
        print -r -- "$_ms_env_id_value" > "$cache/completion-id.tmp.$$" && \
            command mv -f -- "$cache/completion-id.tmp.$$" "$cache/completion-id" || {
            command rm -f -- "$cache/completion-id.tmp.$$"
            return 1
        }
    fi
    return 0
}
