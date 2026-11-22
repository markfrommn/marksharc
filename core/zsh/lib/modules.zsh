# -*- mode: shell-script; sh-shell: zsh -*-
# Module loader (spec 6.4 and 6.5). Modules live in $MARKSHARC_HOME/modules/<name>/.
# The loader functions only read metadata and set up state; the env.zsh and
# init.zsh files themselves are sourced by the loops in phase.zsh (at top level at startup,
# from the marksharc function on reload), so module files declare with -g (spec 6.4).

# Tokenise one directive line (spec 6.5) into the global array `reply`. Returns 1
# for blank lines, comments and malformed quoting. Words are unquoted with (Q);
# nothing is ever evaluated.
_ms_words() {
    emulate -L zsh
    local tok
    local -a raw
    reply=()
    raw=( ${(Z:C:)1} ) 2>/dev/null || return 1
    (( $#raw )) || return 1
    for tok in $raw; do
        _ms_word "$tok" || { reply=(); return 1; }
        reply+=( "$REPLY" )
    done
    return 0
}

# Unquote one word into REPLY. A leading ~ or ~/ and $NAME / ${NAME} references
# expand outside single quotes; backslash quotes a reference. Command substitutions,
# backticks and every other metacharacter remain data and are never evaluated.
_ms_word() {
    emulate -L zsh
    local raw=$1 state=plain ch rest name
    integer i len=${#raw}
    REPLY=
    for (( i = 1; i <= len; i++ )); do
        ch=$raw[i]
        if [[ $state == single ]]; then
            if [[ $ch == \' ]]; then state=plain; else REPLY+=$ch; fi
            continue
        fi
        if [[ $state == double && $ch == \" ]]; then state=plain; continue; fi
        if [[ $state == plain && $ch == \' ]]; then state=single; continue; fi
        if [[ $state == plain && $ch == \" ]]; then state=double; continue; fi
        if [[ $ch == \\ ]]; then
            if (( i == len )); then REPLY+='\'; continue; fi
            if [[ $state == plain || $raw[i+1] == \" || $raw[i+1] == '$' || $raw[i+1] == '`' || $raw[i+1] == \\ ]]; then
                (( i++ )); REPLY+=$raw[i]
            else
                REPLY+='\'
            fi
            continue
        fi
        if [[ $state == plain && $ch == '~' && $i == 1 && ( $len == 1 || $raw[2] == / ) ]]; then
            REPLY+=$HOME
            continue
        fi
        if [[ $ch == '$' ]]; then
            rest=$raw[i,-1]
            if [[ $rest =~ '^\$\{([A-Za-z_][A-Za-z0-9_]*)\}' || $rest =~ '^\$([A-Za-z_][A-Za-z0-9_]*)' ]]; then
                name=$match[1]
                REPLY+=${(P)name-}
                (( i += MEND - 1 ))
                continue
            fi
        fi
        REPLY+=$ch
    done
    [[ $state == plain ]]
}

# config.conf: `module <name> [off]` and `set <module>.<key> <value>` lines. The
# list is explicit once any `module <name>` (not off) line exists; otherwise every
# module present is enabled except those switched off.
_ms_config_load() {
    emulate -L zsh
    typeset -gA _ms_cfg_set=() _ms_cfg_enabled=()
    typeset -gi _ms_cfg_explicit=0
    local line file config=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}
    for file in "$config/config.conf" "$config/hosts/${MARKSHARC_HOST:-${HOST%%.*}}.conf"; do
    [[ -r $file ]] || continue
    while IFS= read -r line || [[ -n $line ]]; do
        _ms_words "$line" || continue
        case ${reply[1]} in
            module)
                [[ -n ${reply[2]-} ]] || continue
                if [[ ${reply[3]-} == off ]]; then
                    _ms_cfg_enabled[${reply[2]}]=0
                else
                    _ms_cfg_enabled[${reply[2]}]=1
                    _ms_cfg_explicit=1
                fi
                ;;
            set)
                if [[ ${reply[2]-} == *.* && $#reply -ge 3 ]]; then _ms_cfg_set[${reply[2]}]=${(j: :)reply[3,-1]}; fi
                ;;
        esac
    done < "$file"
    done
    typeset -g _ms_opt_core_dot_in_path=${_ms_cfg_set[core.dot_in_path]-off}
    return 0
}

# Read every module.conf: describe, requires, order, option. Fills the _ms_mod_*
# tables and _ms_mod_names (enabled modules in load order: order, then name).
_ms_modules_discover() {
    emulate -L zsh
    typeset -gA _ms_mod_dir=() _ms_mod_describe=() _ms_mod_order=() _ms_mod_req_cmd=() _ms_mod_req_os=() _ms_mod_options=() _ms_mod_optdef=() _ms_mod_enabled=()
    typeset -ga _ms_mod_names=()
    _ms_config_load
    local conf dir name line order root
    local -a sortable=()
    typeset -ga _ms_module_roots=( "$MARKSHARC_HOME/modules" "${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}/modules" )
    local -A resolved=()
    for root in "${_ms_module_roots[@]}"; do
        for conf in "$root"/*/module.conf(N-.); do
            dir=${conf:h}; name=${dir:t}
            [[ -n $name && $name != *[^A-Za-z0-9_-]* ]] && resolved[$name]=$conf
        done
    done
    for conf in "${(@v)resolved}"; do
        dir=${conf:h}
        name=${dir:t}
        [[ -n $name && $name != *[^A-Za-z0-9_-]* ]] || continue
        # _ms_discover_all (set by the marksharc module command) keeps disabled modules in
        # the tables, flagged in _ms_mod_enabled, so they can be listed.
        _ms_mod_enabled[$name]=1
        if (( _ms_cfg_explicit )); then
            [[ ${_ms_cfg_enabled[$name]-0} == 1 ]] || { _ms_trace "module $name: skipped (not enabled in config.conf)"; _ms_mod_enabled[$name]=0; }
        else
            [[ ${_ms_cfg_enabled[$name]-1} == 1 ]] || { _ms_trace "module $name: skipped (off in config.conf)"; _ms_mod_enabled[$name]=0; }
        fi
        [[ ${_ms_mod_enabled[$name]} == 1 ]] || (( ${_ms_discover_all:-0} )) || continue
        _ms_mod_dir[$name]=$dir
        order=50
        while IFS= read -r line || [[ -n $line ]]; do
            _ms_words "$line" || continue
            case ${reply[1]} in
                describe) _ms_mod_describe[$name]=${reply[2]-} ;;
                order) if [[ ${reply[2]-} == <0-99> ]]; then order=$(( 10#${reply[2]} )); fi ;;
                requires)
                    case ${reply[2]-} in
                        command) _ms_mod_req_cmd[$name]=${(j: :)reply[3,-1]} ;;
                        os) _ms_mod_req_os[$name]=${(j: :)reply[3,-1]} ;;
                    esac
                    ;;
                option)
                    if [[ -n ${reply[2]-} ]]; then
                        _ms_mod_options[$name]+="${reply[2]} "
                        _ms_mod_optdef[$name.${reply[2]}]=${reply[3]-}
                    fi
                    ;;
            esac
        done < "$conf"
        _ms_mod_order[$name]=$order
        sortable+=( "${(l:2::0:)order}:$name" )
    done
    _ms_mod_names=( ${${(o)sortable}#*:} )
    return 0
}

# Declared options become $_ms_opt_<module>_<key> (non-alphanumerics -> _).
_ms_module_options() {
    emulate -L zsh
    local name=$1 key var
    for key in ${=_ms_mod_options[$name]-}; do
        var=_ms_opt_${name//[^A-Za-z0-9]/_}_${key//[^A-Za-z0-9]/_}
        typeset -g "$var=${_ms_cfg_set[$name.$key]-${_ms_mod_optdef[$name.$key]-}}"
    done
}

# Select the modules that load in a phase (env or init), in load order, honouring
# `requires`. The env phase re-reads all metadata; the init phase reuses it.
_ms_modules_plan() {
    emulate -L zsh
    local phase=$1 name cmd ok
    [[ $phase == env ]] && _ms_modules_discover
    typeset -ga _ms_plan=()
    for name in $_ms_mod_names; do
        ok=1
        # In the env phase PATH is not final until the finalizers run (brew and the
        # managers contribute directories as they load), so phase.zsh checks
        # "requires command" at the module's own turn (_ms_module_requires_command).
        if [[ $phase != env ]]; then
            for cmd in ${=_ms_mod_req_cmd[$name]-}; do
                if ! _ms_command_available "$cmd"; then
                    _ms_trace "module $name: skipped (requires command $cmd)"
                    ok=0
                    break
                fi
            done
        fi
        (( ok )) || continue
        if [[ -n ${_ms_mod_req_os[$name]-} ]] && (( ! ${${=_ms_mod_req_os[$name]}[(Ie)$MARKSHARC_OS]} )); then
            _ms_trace "module $name: skipped (requires os ${_ms_mod_req_os[$name]})"
            continue
        fi
        _ms_module_options "$name"
        _ms_plan+=( $name )
    done
    return 0
}

# Is a command available now? On PATH, or (env phase) in a directory a module has
# already contributed to a PATH tier.
_ms_command_available() {
    whence -p -- "$1" >/dev/null 2>&1 && return 0
    (( $+functions[_ms_command_pending] )) && _ms_command_pending "$1"
}

# Runtime guards left in rendered env.zsh. Use the path module's filesystem seam
# when it is loaded; the fallback keeps directive-only fixtures independent of it.
_ms_render_dir() {
    if (( $+functions[_ms_isdir] )); then _ms_isdir "$1"; else [[ -d $1 ]]; fi
}
_ms_render_file() {
    local REPLY
    if (( $+functions[_ms_fs_path] )); then
        _ms_fs_path "$1"
    elif [[ -n ${_ms_fs_root-} && $1 != "$HOME" && $1 != "$HOME"/* ]]; then
        REPLY=${_ms_fs_root}$1
    else
        REPLY=$1
    fi
    [[ -f $REPLY ]]
}

# Env phase: the "requires command" check of one module, made when its turn comes,
# after the modules before it (brew at 10-19) have contributed their directories.
_ms_module_requires_command() {
    emulate -L zsh
    local cmd
    for cmd in ${=_ms_mod_req_cmd[$1]-}; do
        if ! _ms_command_available "$cmd"; then
            _ms_trace "module $1: skipped (requires command $cmd)"
            return 1
        fi
    done
    return 0
}

# Bracket the sourcing of one module phase file: trace and per-module timing.
_ms_module_begin() {
    [[ -r ${_ms_mod_dir[$2]}/$1.zsh ]] || return 1
    if (( _ms_verbose )); then _ms_now; _ms_mod_t0=$REPLY; fi
    _ms_trace "module $2: $1.zsh"
    return 0
}
_ms_module_end() {
    (( _ms_verbose )) || return 0
    local elapsed
    _ms_now
    printf -v elapsed '%.1f' $(( REPLY - _ms_mod_t0 ))
    _ms_trace "module $2: $1 done in $elapsed ms"
}

# Init phase: module functions/zsh dirs go on fpath and are autoloaded; module
# completions/zsh dirs go on fpath before the completion system initialises.
_ms_modules_setup_paths() {
    emulate -L zsh
    local name dir fn source_path
    local -a fns
    local old
    for old in "${_ms_module_fpaths[@]}"; do fpath=( "${(@)fpath:#$old}" ); done
    for old in "${(@k)_ms_module_function_sources}"; do
        source_path=${functions_source[$old]-}
        [[ -n $source_path && ${source_path:A} == ${_ms_module_function_sources[$old]:A} ]] && unfunction "$old" 2>/dev/null
    done
    typeset -ga _ms_module_fpaths=()
    typeset -gA _ms_module_function_sources=()
    typeset -gU fpath
    for name in $_ms_plan; do
        dir=${_ms_mod_dir[$name]}
        if [[ -d $dir/functions/zsh ]]; then
            fpath=( "$dir/functions/zsh" $fpath )
            _ms_module_fpaths+=( "$dir/functions/zsh" )
            fns=( "$dir"/functions/zsh/*(N-.:t) )
            if (( $#fns )); then
                for fn in $fns; do
                    _ms_module_function_sources[$fn]=$dir/functions/zsh/$fn
                    unfunction "$fn" 2>/dev/null
                    autoload -Uz "$dir/functions/zsh/$fn"
                done
            fi
        fi
        if [[ -d $dir/completions/zsh ]]; then fpath=( "$dir/completions/zsh" $fpath ); _ms_module_fpaths+=( "$dir/completions/zsh" ); fi
    done
    return 0
}

# Non-interactive shells exit on a fatal expansion (${x:?}), which nothing inside the
# shell can catch. Prove a module file survives by running it once in a subshell
# (module files must be safe to source twice). The verdict is keyed on the file
# path, the phase, whether this shell rebuilds, and the env id (which folds in the
# mtime and size of every core, module, function and config file, so an edit to a
# file the module sources invalidates it). It is cached in a stamp file; if the
# stamp cannot be written it is remembered in the exported MARKSHARC_GUARD_MEMO so
# warm child shells do not fork again. A reload re-validates. The check subshell
# must reach its own `exit 77`; the module calling `exit` (or dying) is a failure.
# MARKSHARC_MODULE_GUARD=0 turns the validation pass off.
_ms_module_guard() {
    [[ ${MARKSHARC_MODULE_GUARD-1} == 0 ]] && return 0
    local phase=$1 name=$2 file=$3 stampdir stamp want state rc gkey
    gkey="$name.$phase|${_ms_env_rebuild:-0}|${_ms_env_id_value}|$file"
    gkey=${gkey// /_}
    stampdir=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}/guard
    stamp=$stampdir/$name.$phase
    if (( ! ${_ms_reloading:-0} )); then
        if [[ -r $stamp ]]; then
            state=$(<"$stamp")
            [[ $state == "ok|$gkey" ]] && return 0
            [[ $state == "bad|$gkey" ]] && return 1
        fi
        [[ ${MARKSHARC_GUARD_MEMO-} == *" $gkey=ok"* ]] && return 0
        [[ ${MARKSHARC_GUARD_MEMO-} == *" $gkey=bad"* ]] && return 1
    fi
    ( source "$file"; exit 77 ) >/dev/null 2>&1 </dev/null
    rc=$?
    if (( rc == 77 )); then state=ok; else state=bad; fi
    [[ -d $stampdir ]] || command mkdir -p -- "$stampdir" 2>/dev/null
    if ! { print -r -- "$state|$gkey" > "$stamp" } 2>/dev/null; then
        export MARKSHARC_GUARD_MEMO="${MARKSHARC_GUARD_MEMO-} $gkey=$state"
    fi
    [[ $state == ok ]]
}
