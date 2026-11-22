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

# Print the native statements for the env/path/alias lines in one conf file.
_ms_render_conf() {
    emulate -L zsh
    local file=$1 line kind name value guard out
    local -a generator=()
    integer i end
    [[ -r $file ]] || return 0
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
                ;;
            path)
                name=${reply[2]-} value=${reply[3]-}
                [[ $name =~ '^[A-Za-z0-9_-]+$' && -n $value ]] || continue
                _ms_render_guard_expression 4 || continue
                guard="(( \${_ms_env_rebuild:-1} ))"
                [[ -z $REPLY ]] || guard+=" && $REPLY"
                print -r -- "            $guard && _ms_path_add $name ${(qq)value}"
                ;;
            alias)
                name=${reply[2]-} value=${reply[3]-}
                [[ -n $name && $name != *=* && $#reply -ge 3 ]] || continue
                _ms_render_guard_expression 4 || continue
                guard="[[ \$MARKSHARC_SESSION == interactive ]]"
                [[ -z $REPLY ]] || guard+=" && $REPLY"
                print -r -- "            $guard && alias $name=${(qq)value}"
                print -r -- "            $guard && _ms_rendered_aliases+=( ${(q)name} )"
                ;;
            completion)
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
                out=$_ms_render_stage/zsh/_$name
                if ! command "${generator[@]}" > "$out" 2>/dev/null; then
                    _ms_render_failed=1
                    _ms_trace "completion $name: generator failed"
                fi
                ;;
        esac
    done < "$file"
    return 0
}

# Render the current module plan and overlay. The caller has computed the input id.
_ms_render() {
    emulate -L zsh
    local cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}
    local config=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}
    local tmp=$cache/env.zsh.tmp.$$ name old
    local -a entries=()
    local _ms_render_generate=${1:-1} _ms_render_stage=$cache/completions.tmp.$$
    integer _ms_render_failed=0
    _ms_modules_plan env
    for name in "${_ms_plan[@]}"; do entries+=( "$name" 1 ); done
    [[ -d $cache ]] || command mkdir -p -- "$cache" 2>/dev/null || return 1
    if (( _ms_render_generate )); then
        command mkdir -p -- "$_ms_render_stage/zsh" || return 1
    fi
    {
        print -r -- '# Generated by marksharc render; do not edit.'
        print -r -- "# render id: $_ms_env_id_value"
        print -r -- "typeset -gA _ms_rendered_modules=( ${(j: :)entries} )"
        print -r -- 'typeset -ga _ms_rendered_aliases=()'
        print -r -- '_ms_rendered_env() {'
        print -r -- '    emulate -L zsh'
        print -r -- '    case $1 in'
        for name in "${_ms_plan[@]}"; do
            print -r -- "        $name)"
            _ms_render_conf "${_ms_mod_dir[$name]}/module.conf"
            print -r -- '            ;;'
        done
        print -r -- '        overlay)'
        _ms_render_conf "$config/config.conf"
        _ms_render_conf "$config/hosts/$MARKSHARC_HOST.conf"
        print -r -- '            ;;'
        print -r -- '    esac'
        print -r -- '}'
    } > "$tmp" || { command rm -rf -- "$tmp" "$_ms_render_stage"; return 1; }
    if (( _ms_render_failed )); then
        command rm -rf -- "$tmp" "$_ms_render_stage"
        return 1
    fi
    command mv -f -- "$tmp" "$cache/env.zsh" || { command rm -rf -- "$tmp" "$_ms_render_stage"; return 1; }
    print -r -- "$_ms_env_id_value" > "$cache/render-id.tmp.$$" && \
        command mv -f -- "$cache/render-id.tmp.$$" "$cache/render-id" || {
        command rm -rf -- "$cache/render-id.tmp.$$" "$_ms_render_stage"
        return 1
    }
    if (( _ms_render_generate )); then
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
        print -r -- "$_ms_env_id_value" > "$cache/completion-id.tmp.$$" && \
            command mv -f -- "$cache/completion-id.tmp.$$" "$cache/completion-id" || {
            command rm -f -- "$cache/completion-id.tmp.$$"
            return 1
        }
    fi
    return 0
}

# Refresh stale rendered inputs. The ordinary startup path (full=0) never runs a
# completion generator; install, explicit render, update and reload use full=1.
_ms_render_refresh() {
    emulate -L zsh
    local full=${1:-0} cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}
    local current= completed= need=0 generate=0
    [[ -r $cache/render-id ]] && current=$(<"$cache/render-id")
    [[ -r $cache/env.zsh && $current == "$_ms_env_id_value" ]] || need=1
    if (( full )); then
        [[ -r $cache/completion-id ]] && completed=$(<"$cache/completion-id")
        [[ $completed == "$_ms_env_id_value" ]] || need=1
        (( need )) && generate=1
    fi
    (( need )) || return 0
    _ms_render $generate
}

# Remove aliases owned by the previous render before a reload applies a new plan.
_ms_render_reset() {
    emulate -L zsh
    local name
    for name in "${_ms_rendered_aliases[@]}"; do unalias "$name" 2>/dev/null; done
    unfunction _ms_rendered_env 2>/dev/null
    unset _ms_rendered_modules _ms_rendered_aliases
    return 0
}

# Load only the artifact stamped for the inputs just fingerprinted by _ms_env_id.
_ms_render_load() {
    emulate -L zsh
    local cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}} current=
    [[ -r $cache/render-id ]] && current=$(<"$cache/render-id")
    [[ $current == "$_ms_env_id_value" && -r $cache/env.zsh ]] || return 0
    unfunction _ms_rendered_env 2>/dev/null
    source "$cache/env.zsh"
}
