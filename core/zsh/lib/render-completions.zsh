# -*- mode: shell-script; sh-shell: zsh -*-
# Declarative .comp completion spec parser and four-target renderer
# (COMPLETION-SPEC sections 3, 5.1, 5.2).
# All declarations stay inside functions so this file is safe to source from a function.

# Escape a string for POSIX single-quoted embedding: ' -> '\''
_ms_rc_sh_sq() {
    local q="'\\''"
    REPLY="'${1//\'/$q}'"
}

# Escape a string for Fish single-quoted embedding: \ -> \\ and ' -> \'
_ms_rc_fish_sq() {
    local s=${1//\\/\\\\}
    s=${s//\'/\\\'}
    REPLY="'$s'"
}

# Escape a string for YAML double-quoted scalar.
_ms_rc_yaml_dq() {
    local s=${1//[[:cntrl:]]/}
    s=${s//\\/\\\\}
    s=${s//\"/\\\"}
    REPLY="\"$s\""
}

# Escape a description for zsh _arguments bracketed text [...]
_ms_rc_zsh_desc() {
    local s=${1//[[:cntrl:]]/}
    s=${s//\\/\\\\}
    s=${s//\[/\\\[}
    s=${s//\]/\\\]}
    s=${s//:/\\:}
    REPLY=$s
}

# Sanitize a command or scope identifier to [A-Za-z0-9_].
_ms_rc_slug() {
    REPLY=${1//[^A-Za-z0-9]/_}
}

# Validate a closed value <kind> per COMPLETION-SPEC section 3.3.
_ms_rc_valid_kind() {
    local kind=$1 item
    local -a items=()
    case $kind in
        string|dir|file|command) return 0 ;;
        ms:modules|ms:hosts|ms:installers|ms:update-steps|ms:launch-hosts|\
        ms:repos|ms:base-repos|ms:base-repos-or-dir|ms:worktrees|\
        ms:git-branches|ms:launch-session-target|ms:launch-repo-target)
            return 0 ;;
        choices:*)
            local body=${kind#choices:}
            [[ -n $body ]] || return 1
            items=( "${(@ps:,:)body}" )
            (( $#items >= 1 )) || return 1
            for item in "${items[@]}"; do
                [[ -n $item && $item != *[[:cntrl:]]* ]] || return 1
            done
            return 0 ;;
    esac
    return 1
}

# Validate a subcommand path: /-separated segments matching [A-Za-z0-9][A-Za-z0-9_.-]*
_ms_rc_valid_subcmd_path() {
    local p=$1 seg
    [[ -n $p && $p != /* && $p != */ && $p != *//* ]] || return 1
    local -a segs=( "${(@ps:/:)p}" )
    for seg in "${segs[@]}"; do
        [[ $seg =~ '^[A-Za-z0-9][A-Za-z0-9_.-]*$' ]] || return 1
    done
    return 0
}

# Validate balanced single/double quotes on a directive line (outside comments).
_ms_rc_valid_quoting() {
    local line=$1 state=plain ch
    integer i len=${#line}
    for (( i = 1; i <= len; i++ )); do
        ch=$line[i]
        if [[ $state == single ]]; then
            [[ $ch == \' ]] && state=plain
        elif [[ $state == double ]]; then
            if [[ $ch == \\ && i < len ]]; then
                (( ++i ))
            elif [[ $ch == \" ]]; then
                state=plain
            fi
        else
            if [[ $ch == \\ && i < len ]]; then
                (( ++i ))
            elif [[ $ch == \' ]]; then
                state=single
            elif [[ $ch == \" ]]; then
                state=double
            elif [[ $ch == '#' ]] && (( i == 1 )) || [[ $ch == '#' && ${line[i-1]} == [[:space:]] ]]; then
                break
            fi
        fi
    done
    [[ $state == plain ]]
}

# Parse and validate one .comp file into caller-scoped spec_* / flag_* / arg_* variables.
# Returns 0 on success, 1 on validation error (diagnostic printed to stderr).
_ms_rc_parse() {
    local file=$1 line trimmed directive
    local name desc path_val parent child scope names_raw tok kind slot mode_name
    local -a names=()
    local -A seen_flags=()
    integer line_no=0 i repeat locks has_val idx

    spec_cmd=''
    spec_desc=''
    spec_scopes=( '_' )
    spec_scope_exists=( '_' 1 )
    spec_scope_desc=()
    spec_scope_children=()
    spec_scope_mode=()
    spec_scope_flags=()
    spec_scope_max_pos=( '_' 0 )
    flag_scope=()
    flag_names=()
    flag_kind=()
    flag_repeat=()
    flag_locks=()
    flag_desc=()
    arg_kind=()
    arg_desc=()

    [[ -r $file ]] || { print -ru2 -- "render-completions: unreadable spec: $file"; return 1; }

    while IFS= read -r line || [[ -n $line ]]; do
        (( ++line_no ))
        trimmed=${line#"${line%%[![:space:]]*}"}
        [[ -z $trimmed || $trimmed == '#'* ]] && continue
        if ! _ms_rc_valid_quoting "$line" || ! _ms_words "$line"; then
            print -ru2 -- "$file:$line_no: malformed quoting"
            return 1
        fi
        directive=${reply[1]}
        case $directive in
            command)
                if [[ -n $spec_cmd ]]; then
                    print -ru2 -- "$file:$line_no: duplicate command directive"
                    return 1
                fi
                if (( $#reply < 2 || $#reply > 3 )); then
                    print -ru2 -- "$file:$line_no: command expects <name> [description]"
                    return 1
                fi
                name=${reply[2]}
                desc=${reply[3]-}
                if [[ ! $name =~ '^[A-Za-z0-9][A-Za-z0-9_.-]*$' ]]; then
                    print -ru2 -- "$file:$line_no: invalid command name: $name"
                    return 1
                fi
                spec_cmd=$name
                spec_desc=$desc
                ;;
            subcommand)
                if (( $#reply < 2 || $#reply > 3 )); then
                    print -ru2 -- "$file:$line_no: subcommand expects <path> [description]"
                    return 1
                fi
                path_val=${reply[2]}
                desc=${reply[3]-}
                if ! _ms_rc_valid_subcmd_path "$path_val"; then
                    print -ru2 -- "$file:$line_no: invalid subcommand path: $path_val"
                    return 1
                fi
                if [[ -n ${spec_scope_exists[$path_val]-} ]]; then
                    print -ru2 -- "$file:$line_no: duplicate subcommand: $path_val"
                    return 1
                fi
                if [[ $path_val == */* ]]; then
                    parent=${path_val%/*}
                    child=${path_val##*/}
                else
                    parent='_'
                    child=$path_val
                fi
                if [[ -z ${spec_scope_exists[$parent]-} ]]; then
                    print -ru2 -- "$file:$line_no: parent subcommand not declared before $path_val: $parent"
                    return 1
                fi
                spec_scope_exists[$path_val]=1
                spec_scopes+=( "$path_val" )
                spec_scope_desc[$path_val]=$desc
                spec_scope_max_pos[$path_val]=0
                if [[ -n ${spec_scope_children[$parent]-} ]]; then
                    spec_scope_children[$parent]+=$'\n'"$child"
                else
                    spec_scope_children[$parent]=$child
                fi
                ;;
            flag)
                if (( $#reply < 3 )); then
                    print -ru2 -- "$file:$line_no: flag expects <scope> <names> ..."
                    return 1
                fi
                scope=${reply[2]}
                names_raw=${reply[3]}
                if [[ -z ${spec_scope_exists[$scope]-} ]]; then
                    print -ru2 -- "$file:$line_no: unknown scope for flag: $scope"
                    return 1
                fi
                names=( "${(@ps:,:)names_raw}" )
                if (( ! $#names )); then
                    print -ru2 -- "$file:$line_no: empty flag names"
                    return 1
                fi
                for name in "${names[@]}"; do
                    if [[ ! $name =~ '^(-[A-Za-z0-9]|--[A-Za-z0-9][A-Za-z0-9_-]*)$' ]]; then
                        print -ru2 -- "$file:$line_no: invalid flag name: $name"
                        return 1
                    fi
                    if [[ -n ${seen_flags[${scope}:$name]-} ]]; then
                        print -ru2 -- "$file:$line_no: duplicate flag $name in scope $scope"
                        return 1
                    fi
                    seen_flags[${scope}:$name]=1
                done
                kind=''
                repeat=0
                locks=0
                has_val=0
                desc=''
                i=4
                while (( i <= $#reply )); do
                    tok=${reply[i]}
                    case $tok in
                        value)
                            if (( has_val )); then
                                print -ru2 -- "$file:$line_no: duplicate value keyword on flag"
                                return 1
                            fi
                            if (( i + 1 > $#reply )); then
                                print -ru2 -- "$file:$line_no: value keyword requires a kind"
                                return 1
                            fi
                            kind=${reply[i+1]}
                            if ! _ms_rc_valid_kind "$kind"; then
                                print -ru2 -- "$file:$line_no: unknown value kind: $kind"
                                return 1
                            fi
                            has_val=1
                            (( i += 2 ))
                            ;;
                        repeatable)
                            if (( repeat )); then
                                print -ru2 -- "$file:$line_no: duplicate repeatable keyword on flag"
                                return 1
                            fi
                            repeat=1
                            (( ++i ))
                            ;;
                        locks-positional)
                            if (( locks )); then
                                print -ru2 -- "$file:$line_no: duplicate locks-positional keyword on flag"
                                return 1
                            fi
                            locks=1
                            (( ++i ))
                            ;;
                        *)
                            if (( i != $#reply )); then
                                print -ru2 -- "$file:$line_no: unexpected extra token after flag description: ${reply[i+1]}"
                                return 1
                            fi
                            desc=$tok
                            (( ++i ))
                            ;;
                    esac
                done
                flag_scope+=( "$scope" )
                flag_names+=( "$names_raw" )
                flag_kind+=( "$kind" )
                flag_repeat+=( "$repeat" )
                flag_locks+=( "$locks" )
                flag_desc+=( "$desc" )
                idx=$#flag_scope
                if [[ -n ${spec_scope_flags[$scope]-} ]]; then
                    spec_scope_flags[$scope]+=" $idx"
                else
                    spec_scope_flags[$scope]="$idx"
                fi
                ;;
            arg)
                if (( $#reply < 4 || $#reply > 5 )); then
                    print -ru2 -- "$file:$line_no: arg expects <scope> <slot> <kind> [description]"
                    return 1
                fi
                scope=${reply[2]}
                slot=${reply[3]}
                kind=${reply[4]}
                desc=${reply[5]-}
                if [[ -z ${spec_scope_exists[$scope]-} ]]; then
                    print -ru2 -- "$file:$line_no: unknown scope for arg: $scope"
                    return 1
                fi
                case $slot in
                    rest|dash1|dash-rest) ;;
                    *)
                        if [[ ! $slot =~ '^[1-9][0-9]*$' ]]; then
                            print -ru2 -- "$file:$line_no: invalid arg slot: $slot"
                            return 1
                        fi
                        if (( slot > ${spec_scope_max_pos[$scope]:-0} )); then
                            spec_scope_max_pos[$scope]=$slot
                        fi
                        ;;
                esac
                if [[ -n ${arg_kind[${scope}:$slot]-} ]]; then
                    print -ru2 -- "$file:$line_no: duplicate arg slot $slot in scope $scope"
                    return 1
                fi
                if ! _ms_rc_valid_kind "$kind"; then
                    print -ru2 -- "$file:$line_no: unknown arg kind: $kind"
                    return 1
                fi
                arg_kind[${scope}:$slot]=$kind
                arg_desc[${scope}:$slot]=$desc
                ;;
            mode)
                if (( $#reply != 3 )); then
                    print -ru2 -- "$file:$line_no: mode expects <scope> <mode-name>"
                    return 1
                fi
                scope=${reply[2]}
                mode_name=${reply[3]}
                if [[ -z ${spec_scope_exists[$scope]-} ]]; then
                    print -ru2 -- "$file:$line_no: unknown scope for mode: $scope"
                    return 1
                fi
                case $mode_name in
                    flag-form-locks-positional) ;;
                    *)
                        print -ru2 -- "$file:$line_no: unknown mode: $mode_name"
                        return 1
                        ;;
                esac
                if [[ -n ${spec_scope_mode[$scope]-} ]]; then
                    print -ru2 -- "$file:$line_no: duplicate mode in scope $scope"
                    return 1
                fi
                spec_scope_mode[$scope]=$mode_name
                ;;
            *)
                print -ru2 -- "$file:$line_no: unknown directive: $directive"
                return 1
                ;;
        esac
    done < "$file"

    if [[ -z $spec_cmd ]]; then
        print -ru2 -- "$file: missing required command directive"
        return 1
    fi
    return 0
}

# --- ZSH EMITTER -------------------------------------------------------------

# Return the zsh action invocation string (without leading colon) for a <kind>.
_ms_rc_zsh_action_for_kind() {
    local slug=$1 kind=$2
    local -a items=() quoted=()
    local item
    case $kind in
        string) REPLY='' ;;
        dir) REPLY='_files -/' ;;
        file) REPLY='_files' ;;
        command) REPLY='_command_names' ;;
        choices:*)
            items=( "${(@ps:,:)${kind#choices:}}" )
            for item in "${items[@]}"; do
                _ms_rc_sh_sq "$item"
                quoted+=( "$REPLY" )
            done
            REPLY="_ms_comp_${slug}_choices ${(j: :)quoted}"
            ;;
        ms:modules)              REPLY="_ms_comp_${slug}_kind modules" ;;
        ms:hosts)                REPLY="_ms_comp_${slug}_kind hosts" ;;
        ms:installers)           REPLY="_ms_comp_${slug}_kind installers" ;;
        ms:update-steps)         REPLY="_ms_comp_${slug}_kind update-steps" ;;
        ms:launch-hosts)         REPLY="_ms_comp_${slug}_kind launch-hosts" ;;
        ms:repos)                REPLY="_ms_comp_${slug}_kind repos" ;;
        ms:base-repos)           REPLY="_ms_comp_${slug}_kind base-repos" ;;
        ms:base-repos-or-dir)    REPLY="_ms_comp_${slug}_kind base-repos-or-dir" ;;
        ms:worktrees)            REPLY="_ms_comp_${slug}_kind worktrees" ;;
        ms:git-branches)         REPLY="_ms_comp_${slug}_kind git-branches" ;;
        ms:launch-session-target) REPLY="_ms_comp_${slug}_kind launch-session-target" ;;
        ms:launch-repo-target)   REPLY="_ms_comp_${slug}_kind launch-repo-target" ;;
    esac
}

# Emit a zsh completion file to stdout for the currently parsed spec.
_ms_rc_emit_zsh() {
    emulate -L zsh
    local helper=$1 slug home_sq scope sslug child full_child idx f_raw f_kind f_desc f_rep
    local f_spec f_names_joined f_brace f_desc_esc action label slot max_pos mode_val
    local valued_pat lock_pat args_opts tail excl_sq prefix cdesc cval child_slug
    local -a f_names=() children=() valued_list=() lock_list=()
    integer pos

    _ms_rc_slug "$spec_cmd"; slug=$REPLY
    _ms_rc_sh_sq "$MARKSHARC_HOME"; home_sq=$REPLY

    print -r -- "#compdef $spec_cmd"
    print -r -- '# Generated by marksharc render; do not edit.'
    print -r -- ''
    print -r -- "_ms_comp_${slug}_run() {"
    print -r -- "    local helper=\${MARKSHARC_HOME:-$home_sq}/core/cli/complete"
    print -r -- '    [[ -r $helper ]] || return 0'
    print -r -- '    local -a env_vars=( "MARKSHARC_HOST=${MARKSHARC_HOST:-${HOST%%.*}}" )'
    print -r -- '    [[ -n ${MARKSHARC_CONFIG-} ]] && env_vars+=( "MARKSHARC_CONFIG=$MARKSHARC_CONFIG" )'
    print -r -- '    command env "${env_vars[@]}" zsh -f "$helper" "$@" 2>/dev/null'
    print -r -- '}'
    print -r -- ''
    print -r -- "_ms_comp_${slug}_choices() {"
    print -r -- '    local expl'
    print -r -- '    _wanted choices expl '\''value'\'' compadd -- "$@"'
    print -r -- '}'
    print -r -- ''
    print -r -- "_ms_comp_${slug}_emit_tsv() {"
    print -r -- '    local tag=$1 title=$2; shift 2'
    print -r -- '    local line val desc expl'
    print -r -- '    local -a vals=() items=()'
    print -r -- '    integer has_desc=0'
    print -r -- "    while IFS= read -r line; do"
    print -r -- '        [[ -n $line ]] || continue'
    print -r -- '        if [[ $line == *$'\''\t'\''* ]]; then'
    print -r -- '            val=${line%%$'\''\t'\''*}'
    print -r -- '            desc=${line#*$'\''\t'\''}'
    print -r -- '            has_desc=1'
    print -r -- '            items+=( "${${val//\\/\\\\}//:/\\:}:$desc" )'
    print -r -- '        else'
    print -r -- '            val=$line'
    print -r -- '            items+=( "${${val//\\/\\\\}//:/\\:}" )'
    print -r -- '        fi'
    print -r -- '        vals+=( "$val" )'
    print -r -- '    done < <(_ms_comp_'"${slug}"'_run "$@")'
    print -r -- '    (( $#vals )) || return 1'
    print -r -- '    if (( has_desc )); then'
    print -r -- '        _describe -t "$tag" "$title" items'
    print -r -- '    else'
    print -r -- '        _wanted "$tag" expl "$title" compadd -a vals'
    print -r -- '    fi'
    print -r -- '}'
    print -r -- ''
    print -r -- "_ms_comp_${slug}_launch_hosts_colon() {"
    print -r -- '    local line val expl'
    print -r -- '    local -a vals=()'
    print -r -- "    while IFS= read -r line; do"
    print -r -- '        [[ -n $line ]] || continue'
    print -r -- '        val=${line%%$'\''\t'\''*}'
    print -r -- '        val=${val%:}'
    print -r -- '        [[ -n $val ]] && vals+=( "$val" )'
    print -r -- '    done < <(_ms_comp_'"${slug}"'_run launch-hosts --colon)'
    print -r -- '    (( $#vals )) || return 1'
    print -r -- '    _wanted hosts expl '\''launch host'\'' compadd -r : -S : -a vals'
    print -r -- '}'
    print -r -- ''
    print -r -- "_ms_comp_${slug}_kind() {"
    print -r -- '    local kind=$1'
    print -r -- '    local cur=${words[CURRENT]-}'
    print -r -- '    local host=${(Q)${opt_args[--host]-${_ms_scan_host-}}}'
    print -r -- '    local repo=${(Q)${opt_args[--repo]-${_ms_scan_repo-}}}'
    print -r -- '    local -a extra=()'
    print -r -- '    local line val h rest expl'
    print -r -- '    local -a repos=() hosts=()'
    print -r -- '    case $kind in'
    print -r -- "        modules)      _ms_comp_${slug}_emit_tsv modules 'module' modules ;;"
    print -r -- "        hosts)        _ms_comp_${slug}_emit_tsv hosts 'host' hosts ;;"
    print -r -- "        installers)   _ms_comp_${slug}_emit_tsv installers 'installer' installers ;;"
    print -r -- "        update-steps) _ms_comp_${slug}_emit_tsv steps 'update step' update-steps ;;"
    print -r -- "        launch-hosts) _ms_comp_${slug}_emit_tsv hosts 'launch host' launch-hosts ;;"
    print -r -- "        git-branches) _ms_comp_${slug}_emit_tsv branches 'git branch' git-branches ;;"
    print -r -- '        repos)'
    print -r -- '            [[ -n $host ]] && extra+=( --host "$host" )'
    print -r -- '            (( $+opt_args[--base-only] || ${_ms_scan_base_only:-0} )) && extra+=( --base-only )'
    print -r -- "            _ms_comp_${slug}_emit_tsv repos 'repository' repos \"\${extra[@]}\" ;;"
    print -r -- '        base-repos)'
    print -r -- '            [[ -n $host ]] && extra+=( --host "$host" )'
    print -r -- "            _ms_comp_${slug}_emit_tsv repos 'repository' base-repos \"\${extra[@]}\" ;;"
    print -r -- '        base-repos-or-dir)'
    print -r -- '            if [[ ( -z $host || $host == (local|localhost|${MARKSHARC_HOST:-${HOST%%.*}}) ) && ( $cur == /* || $cur == '\''~'\''* ) ]]; then'
    print -r -- '                _files -/'
    print -r -- '            else'
    print -r -- '                [[ -n $host ]] && extra+=( --host "$host" )'
    print -r -- "                _ms_comp_${slug}_emit_tsv repos 'repository' base-repos \"\${extra[@]}\""
    print -r -- '            fi ;;'
    print -r -- '        worktrees)'
    print -r -- '            [[ -n $host ]] && extra+=( --host "$host" )'
    print -r -- '            [[ -n $repo ]] && extra+=( --repo "$repo" )'
    print -r -- "            _ms_comp_${slug}_emit_tsv worktrees 'worktree' worktrees \"\${extra[@]}\" ;;"
    print -r -- '        launch-session-target)'
    print -r -- '            if [[ $cur == *:* ]]; then'
    print -r -- '                h=${cur%%:*}'
    print -r -- '                if [[ -z $h || $h == (local|localhost|${MARKSHARC_HOST:-${HOST%%.*}}) ]]; then'
    print -r -- '                    compset -P '\''*:'\'' && _files -/'
    print -r -- '                fi'
    print -r -- '            else'
    print -r -- "                _alternative 'hosts:launch host:_ms_comp_${slug}_launch_hosts_colon' 'directories:directory:_files -/'"
    print -r -- '            fi ;;'
    print -r -- '        launch-repo-target)'
    print -r -- '            if [[ $cur == /* || $cur == '\''~'\''* ]]; then'
    print -r -- '                _files -/'
    print -r -- '                return'
    print -r -- '            fi'
    print -r -- '            (( $+opt_args[--base-only] || ${_ms_scan_base_only:-0} )) && extra+=( --base-only )'
    print -r -- '            if [[ $cur == *:* ]]; then'
    print -r -- '                h=${cur%%:*}; rest=${cur#*:}'
    print -r -- '                if [[ ( -z $h || $h == (local|localhost|${MARKSHARC_HOST:-${HOST%%.*}}) ) && ( $rest == /* || $rest == '\''~'\''* ) ]]; then'
    print -r -- '                    compset -P '\''*:'\'' && _files -/'
    print -r -- '                    return'
    print -r -- '                fi'
    print -r -- "                while IFS= read -r line; do"
    print -r -- '                    [[ -n $line ]] || continue'
    print -r -- '                    val=${line%%$'\''\t'\''*}'
    print -r -- '                    repos+=( "${val#${h}:}" )'
    print -r -- "                done < <(_ms_comp_${slug}_run launch-repo-target \"\${extra[@]}\" --current \"\$cur\")"
    print -r -- '                (( $#repos )) && compset -P '\''*:'\'' && _wanted repos expl '\''repository'\'' compadd -a repos'
    print -r -- '            else'
    print -r -- '                [[ -n $host ]] && extra+=( --host "$host" )'
    print -r -- "                while IFS= read -r line; do"
    print -r -- '                    [[ -n $line ]] || continue'
    print -r -- '                    val=${line%%$'\''\t'\''*}'
    print -r -- '                    if [[ $val == *: ]]; then hosts+=( "${val%:}" ); else repos+=( "$val" ); fi'
    print -r -- "                done < <(_ms_comp_${slug}_run launch-repo-target \"\${extra[@]}\" --current \"\$cur\")"
    print -r -- '                (( $#repos )) && _wanted repos expl '\''repository'\'' compadd -a repos'
    print -r -- '                (( $#hosts )) && _wanted hosts expl '\''launch host'\'' compadd -r : -S : -a hosts'
    print -r -- '            fi ;;'
    print -r -- '    esac'
    print -r -- '}'
    print -r -- ''

    for scope in "${spec_scopes[@]}"; do
        _ms_rc_slug "$scope"; sslug=$REPLY
        mode_val=${spec_scope_mode[$scope]-}
        children=()
        [[ -n ${spec_scope_children[$scope]-} ]] && children=( "${(@f)spec_scope_children[$scope]}" )
        max_pos=${spec_scope_max_pos[$scope]:-0}

        valued_list=()
        lock_list=()
        for idx in ${=spec_scope_flags[$scope]-}; do
            f_names=( "${(@ps:,:)flag_names[idx]}" )
            if [[ -n ${flag_kind[idx]} ]]; then
                valued_list+=( "${f_names[@]}" )
            fi
            if (( flag_locks[idx] )); then
                lock_list+=( "${f_names[@]}" )
            fi
        done

        print -r -- "_ms_comp_${slug}_scope_${sslug}() {"
        print -r -- '    local context state state_descr line'
        print -r -- '    local -A opt_args'
        print -r -- '    local _ms_scan_host='\'''\'' _ms_scan_repo='\'''\'' _ms_tok _ms_pending='\'''\'''
        print -r -- '    integer _ms_scan_base_only=0 _ms_scan_has_cmd=0 _ms_scan_locked=0 _ms_scan_dash=0 _ms_scan_dash_pos=0 _ms_i'
        print -r -- '    for (( _ms_i = 2; _ms_i < CURRENT; _ms_i++ )); do'
        print -r -- '        _ms_tok=${words[_ms_i]}'
        print -r -- '        if [[ -n $_ms_pending ]]; then'
        print -r -- '            case $_ms_pending in'
        print -r -- '                --host) _ms_scan_host=${(Q)_ms_tok} ;;'
        print -r -- '                --repo) _ms_scan_repo=${(Q)_ms_tok} ;;'
        print -r -- '                --command) _ms_scan_has_cmd=1 ;;'
        print -r -- '            esac'
        if (( $#lock_list )); then
            lock_pat=${(j:|:)lock_list}
            print -r -- "            case \$_ms_pending in $lock_pat) _ms_scan_locked=1 ;; esac"
        fi
        print -r -- '            _ms_pending='\'''\'''
        print -r -- '        elif (( _ms_scan_dash )); then'
        print -r -- '            (( ++_ms_scan_dash_pos ))'
        print -r -- '        elif [[ $_ms_tok == -- ]]; then'
        print -r -- '            _ms_scan_dash=1'
        print -r -- '        else'
        print -r -- '            case $_ms_tok in'
        print -r -- '                --base-only) _ms_scan_base_only=1 ;;'
        if (( $#valued_list )); then
            valued_pat=${(j:|:)valued_list}
            print -r -- "                $valued_pat) _ms_pending=\$_ms_tok ;;"
        fi
        if (( $#lock_list )); then
            lock_pat=${(j:|:)lock_list}
            print -r -- "                $lock_pat) _ms_scan_locked=1 ;;"
        fi
        print -r -- '            esac'
        print -r -- '        fi'
        print -r -- '    done'

        if [[ -n ${arg_kind[${scope}:dash1]-} || -n ${arg_kind[${scope}:dash-rest]-} ]]; then
            print -r -- '    if (( _ms_scan_dash )); then'
            print -r -- '        if (( _ms_scan_dash_pos == 0 )); then'
            if [[ $mode_val == flag-form-locks-positional && -n ${arg_kind[${scope}:dash-rest]-} ]]; then
                _ms_rc_zsh_action_for_kind "$slug" "${arg_kind[${scope}:dash-rest]}"
                print -r -- '            if (( _ms_scan_has_cmd )); then'
                print -r -- "                ${REPLY:-:}"
                print -r -- '                return'
                print -r -- '            fi'
            fi
            if [[ -n ${arg_kind[${scope}:dash1]-} ]]; then
                _ms_rc_zsh_action_for_kind "$slug" "${arg_kind[${scope}:dash1]}"
                print -r -- "            ${REPLY:-:}"
            elif [[ -n ${arg_kind[${scope}:dash-rest]-} ]]; then
                _ms_rc_zsh_action_for_kind "$slug" "${arg_kind[${scope}:dash-rest]}"
                print -r -- "            ${REPLY:-:}"
            fi
            print -r -- '        else'
            if [[ -n ${arg_kind[${scope}:dash-rest]-} ]]; then
                _ms_rc_zsh_action_for_kind "$slug" "${arg_kind[${scope}:dash-rest]}"
                print -r -- "            ${REPLY:-:}"
            fi
            print -r -- '        fi'
            print -r -- '        return'
            print -r -- '    fi'
        fi

        args_opts='-S'
        (( $#children )) && args_opts+=' -C'
        [[ $mode_val == flag-form-locks-positional ]] && args_opts+=" -A '-*'"
        print -rn -- "    _arguments $args_opts"

        for idx in ${=spec_scope_flags[$scope]-}; do
            f_names=( "${(@ps:,:)flag_names[idx]}" )
            f_kind=${flag_kind[idx]}
            f_rep=${flag_repeat[idx]}
            _ms_rc_zsh_desc "${flag_desc[idx]}"
            f_desc_esc=$REPLY
            tail=''
            [[ -n $f_desc_esc ]] && tail="[$f_desc_esc]"
            if [[ -n $f_kind ]]; then
                _ms_rc_zsh_action_for_kind "$slug" "$f_kind"
                [[ $REPLY == _ms_comp_* ]] && REPLY=" $REPLY"
                tail+=":value:$REPLY"
            fi
            if (( $#f_names > 1 )); then
                f_brace="{${(j:,:)f_names}}"
                if (( f_rep )); then
                    _ms_rc_sh_sq "$tail"
                    f_spec="'*'${f_brace}${REPLY}"
                else
                    f_names_joined="(${(j: :)f_names})"
                    _ms_rc_sh_sq "$f_names_joined"
                    excl_sq=$REPLY
                    _ms_rc_sh_sq "$tail"
                    f_spec="${excl_sq}${f_brace}${REPLY}"
                fi
            else
                prefix=''
                (( f_rep )) && prefix='*'
                _ms_rc_sh_sq "${prefix}${f_names[1]}${tail}"
                f_spec=$REPLY
            fi
            print -r -- ' \'
            print -rn -- "        $f_spec"
        done

        if (( $#children )); then
            print -r -- ' \'
            print -rn -- "        '1:subcommand:->subcmd'"
            print -r -- ' \'
            print -rn -- "        '*::arg:->subargs'"
        else
            for (( pos = 1; pos <= max_pos; pos++ )); do
                if [[ -n ${arg_kind[${scope}:$pos]-} ]]; then
                    _ms_rc_zsh_desc "${arg_desc[${scope}:$pos]:-argument}"
                    label=$REPLY
                    if (( pos == 1 )) && [[ $mode_val == flag-form-locks-positional ]]; then
                        _ms_rc_sh_sq "${pos}:${label}:->pos1"
                    else
                        _ms_rc_zsh_action_for_kind "$slug" "${arg_kind[${scope}:$pos]}"
                        [[ $REPLY == _ms_comp_* ]] && REPLY=" $REPLY"
                        _ms_rc_sh_sq "${pos}:${label}:${REPLY}"
                    fi
                    print -r -- ' \'
                    print -rn -- "        $REPLY"
                fi
            done
            if [[ -n ${arg_kind[${scope}:rest]-} ]]; then
                _ms_rc_zsh_desc "${arg_desc[${scope}:rest]:-argument}"
                label=$REPLY
                _ms_rc_zsh_action_for_kind "$slug" "${arg_kind[${scope}:rest]}"
                [[ $REPLY == _ms_comp_* ]] && REPLY=" $REPLY"
                _ms_rc_sh_sq "*:${label}:${REPLY}"
                print -r -- ' \'
                print -rn -- "        $REPLY"
            fi
        fi
        print -r -- ' && return 0'

        if (( $#children )); then
            print -r -- '    case $state in'
            print -r -- '        subcmd)'
            print -r -- '            local -a subcmds'
            print -r -- '            subcmds=('
            for child in "${children[@]}"; do
                if [[ $scope == '_' ]]; then full_child=$child; else full_child="$scope/$child"; fi
                cdesc=${spec_scope_desc[$full_child]-}
                cdesc=${cdesc//[[:cntrl:]]/}
                cval=${${child//\\/\\\\}//:/\\:}
                if [[ -n $cdesc ]]; then
                    _ms_rc_sh_sq "$cval:$cdesc"
                else
                    _ms_rc_sh_sq "$cval"
                fi
                print -r -- "                $REPLY"
            done
            print -r -- '            )'
            print -r -- '            _describe -t commands '\''subcommand'\'' subcmds'
            print -r -- '            ;;'
            print -r -- '        subargs)'
            print -r -- '            case ${line[1]-} in'
            for child in "${children[@]}"; do
                if [[ $scope == '_' ]]; then full_child=$child; else full_child="$scope/$child"; fi
                _ms_rc_slug "$full_child"; child_slug=$REPLY
                _ms_rc_sh_sq "$child"
                print -r -- "                $REPLY) _ms_comp_${slug}_scope_${child_slug} ;;"
            done
            print -r -- '            esac'
            print -r -- '            ;;'
            print -r -- '    esac'
        elif [[ $mode_val == flag-form-locks-positional && -n ${arg_kind[${scope}:1]-} ]]; then
            _ms_rc_zsh_action_for_kind "$slug" "${arg_kind[${scope}:1]}"
            print -r -- '    if [[ $state == pos1 ]]; then'
            print -r -- '        (( _ms_scan_locked )) && return 0'
            print -r -- "        ${REPLY:-:}"
            print -r -- '    fi'
        fi
        print -r -- '}'
        print -r -- ''
    done

    print -r -- "_ms_comp_${slug}_scope__"
}

# --- BASH 4.4+ EMITTER -------------------------------------------------------

# Emit bash statements to populate COMPREPLY for a <kind> (using $word, $opt_host, $opt_repo, $opt_base_only, $trim).
_ms_rc_bash_emit_kind() {
    local indent=$1 kind=$2
    local -a items=() quoted=()
    local item
    case $kind in
        string)
            print -r -- "${indent}:" ;;
        dir)
            print -r -- "${indent}_ms_bash_comp_dirs \"\$word\" ''" ;;
        file)
            print -r -- "${indent}compopt -o default 2>/dev/null || :" ;;
        command)
            print -r -- "${indent}mapfile -t COMPREPLY < <(compgen -c -- \"\$word\")" ;;
        choices:*)
            items=( "${(@ps:,:)${kind#choices:}}" )
            for item in "${items[@]}"; do
                _ms_rc_sh_sq "$item"
                quoted+=( "$REPLY" )
            done
            print -r -- "${indent}_ms_bash_comp_choices \"\$word\" ${(j: :)quoted}" ;;
        ms:modules)      print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' modules" ;;
        ms:hosts)        print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' hosts" ;;
        ms:installers)   print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' installers" ;;
        ms:update-steps) print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' update-steps" ;;
        ms:launch-hosts) print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' launch-hosts" ;;
        ms:git-branches) print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' git-branches" ;;
        ms:repos)
            print -r -- "${indent}local -a _args=(repos)"
            print -r -- "${indent}[[ -n \$opt_host ]] && _args+=(--host \"\$opt_host\")"
            print -r -- "${indent}(( opt_base_only )) && _args+=(--base-only)"
            print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' \"\${_args[@]}\"" ;;
        ms:base-repos)
            print -r -- "${indent}local -a _args=(base-repos)"
            print -r -- "${indent}[[ -n \$opt_host ]] && _args+=(--host \"\$opt_host\")"
            print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' \"\${_args[@]}\"" ;;
        ms:base-repos-or-dir)
            print -r -- "${indent}if _ms_bash_comp_local_host \"\$opt_host\" && [[ \$word == /* || \$word == '~'* ]]; then"
            print -r -- "${indent}    _ms_bash_comp_dirs \"\$word\" ''"
            print -r -- "${indent}else"
            print -r -- "${indent}    local -a _args=(base-repos)"
            print -r -- "${indent}    [[ -n \$opt_host ]] && _args+=(--host \"\$opt_host\")"
            print -r -- "${indent}    _ms_bash_comp_helper \"\$word\" '' \"\${_args[@]}\""
            print -r -- "${indent}fi" ;;
        ms:worktrees)
            print -r -- "${indent}local -a _args=(worktrees)"
            print -r -- "${indent}[[ -n \$opt_host ]] && _args+=(--host \"\$opt_host\")"
            print -r -- "${indent}[[ -n \$opt_repo ]] && _args+=(--repo \"\$opt_repo\")"
            print -r -- "${indent}_ms_bash_comp_helper \"\$word\" '' \"\${_args[@]}\"" ;;
        ms:launch-session-target)
            print -r -- "${indent}_ms_bash_comp_launch_session_target \"\$word\" \"\$trim\"" ;;
        ms:launch-repo-target)
            print -r -- "${indent}_ms_bash_comp_launch_repo_target \"\$word\" \"\$opt_host\" \"\$opt_base_only\" \"\$trim\"" ;;
    esac
}

# Emit a Bash 4.4+ completion file to stdout for the currently parsed spec.
_ms_rc_emit_bash() {
    emulate -L zsh
    local helper=$1 slug home_sq scope child full_child idx f_kind mode_val match_sq
    local -a f_names=() children=() all_flags=() valued_flags=() lock_flags=() quoted=()
    local f item
    integer pos max_pos

    _ms_rc_slug "$spec_cmd"; slug=$REPLY
    _ms_rc_sh_sq "$MARKSHARC_HOME"; home_sq=$REPLY

    print -r -- '# Generated by marksharc render; do not edit.'
    print -r -- "if [[ -r \"\${MARKSHARC_HOME:-$home_sq}/core/bash/complete.bash\" ]] && ! declare -F _ms_bash_comp_unquote >/dev/null 2>&1; then"
    print -r -- '    # shellcheck disable=SC1091'
    print -r -- "    source \"\${MARKSHARC_HOME:-$home_sq}/core/bash/complete.bash\""
    print -r -- 'fi'
    print -r -- 'if ! declare -F _ms_bash_comp_unquote >/dev/null 2>&1; then'
    print -r -- '    _ms_bash_comp_unquote() {'
    print -r -- '        local text=$1 quote='\'''\'' char next i double_escapes='\''"\\$`'\'''
    print -r -- '        REPLY='\'''\'''
    print -r -- '        for ((i=0; i<${#text}; i++)); do'
    print -r -- '            char=${text:i:1}'
    print -r -- '            next=${text:i+1:1}'
    print -r -- '            case $char in'
    print -r -- '                "$quote") quote='\'''\'' ;;'
    print -r -- '                \'\''|'\''"'\'')'
    print -r -- '                    if [[ $quote ]]; then REPLY+=$char; else quote=$char; fi ;;'
    print -r -- '                \\)'
    print -r -- '                    if [[ $next && ( ! $quote || ( $quote == '\''"'\'' && $double_escapes == *"$next"* ) ) ]]; then'
    print -r -- '                        REPLY+=$next'
    print -r -- '                        ((i+=1))'
    print -r -- '                    else'
    print -r -- '                        REPLY+=$char'
    print -r -- '                    fi ;;'
    print -r -- '                *) REPLY+=$char ;;'
    print -r -- '            esac'
    print -r -- '        done'
    print -r -- '    }'
    print -r -- '    _ms_bash_comp_local_host() {'
    print -r -- '        case $1 in '\'''\''|local|localhost|"${MARKSHARC_HOST:-${HOSTNAME%%.*}}") return 0 ;; esac'
    print -r -- '        return 1'
    print -r -- '    }'
    print -r -- '    _ms_bash_comp_valid_host() {'
    print -r -- '        [[ $1 != -* && $1 != . && $1 != .. && $1 =~ ^[A-Za-z0-9._@:-]+$ ]]'
    print -r -- '    }'
    print -r -- '    _ms_bash_comp_choices() {'
    print -r -- '        local word=$1 item; shift'
    print -r -- '        for item in "$@"; do'
    print -r -- '            [[ $item == "$word"* ]] && COMPREPLY+=("$item")'
    print -r -- '        done'
    print -r -- '    }'
    print -r -- '    _ms_bash_comp_dirs() {'
    print -r -- '        local word=$1 prefix=$2 path candidate'
    print -r -- '        case $word in'
    print -r -- '            \~) path=$HOME/ ;;'
    print -r -- '            \~/*) path=$HOME/${word#\~/} ;;'
    print -r -- '            *) path=$word ;;'
    print -r -- '        esac'
    print -r -- '        while IFS= read -r candidate; do'
    print -r -- '            if [[ $word == \~ || $word == \~/* ]]; then'
    print -r -- '                candidate=\~/${candidate#"$HOME"/}'
    print -r -- '            fi'
    print -r -- '            if [[ $prefix && ! ${trim-} ]]; then'
    print -r -- '                candidate+=/'
    print -r -- '                compopt -o nospace 2>/dev/null || :'
    print -r -- '            fi'
    print -r -- '            COMPREPLY+=("$prefix$candidate")'
    print -r -- '        done < <(compgen -d -- "$path")'
    print -r -- '    }'
    print -r -- '    _ms_bash_comp_helper() {'
    print -r -- '        local word=$1 prefix=$2 line val; shift 2'
    print -r -- "        local helper=\${MARKSHARC_HOME:-$home_sq}/core/cli/complete"
    print -r -- '        [[ -r $helper ]] || return 0'
    print -r -- '        local -a env_vars=("MARKSHARC_HOST=${MARKSHARC_HOST:-${HOSTNAME%%.*}}")'
    print -r -- '        [[ -n ${MARKSHARC_CONFIG-} ]] && env_vars+=("MARKSHARC_CONFIG=$MARKSHARC_CONFIG")'
    print -r -- '        while IFS= read -r line; do'
    print -r -- '            [[ -n $line ]] || continue'
    print -r -- '            val=${line%%$'\''\t'\''*}'
    print -r -- '            [[ $val == "$word"* ]] || continue'
    print -r -- '            COMPREPLY+=("$prefix$val")'
    print -r -- '            [[ $val == *: ]] && compopt -o nospace 2>/dev/null || :'
    print -r -- '        done < <(command env "${env_vars[@]}" zsh -f "$helper" "$@" 2>/dev/null)'
    print -r -- '    }'
    print -r -- '    _ms_bash_comp_launch_session_target() {'
    print -r -- '        local word=$1 trim=$2 host='\'''\'' prefix='\'''\'''
    print -r -- '        if [[ $word == *:* && ( ${word#*:} == '\'''\'' || ${word#*:} == /* || ${word#*:} == \~* ) ]] && _ms_bash_comp_valid_host "${word%%:*}"; then'
    print -r -- '            host=${word%%:*}'
    print -r -- '            prefix=$host:'
    print -r -- '            word=${word#*:}'
    print -r -- '        fi'
    print -r -- '        if _ms_bash_comp_local_host "$host"; then _ms_bash_comp_dirs "$word" "$prefix"; fi'
    print -r -- '        if [[ ! $host ]]; then'
    print -r -- '            _ms_bash_comp_helper "$word" '\'''\'' launch-hosts --colon'
    print -r -- '        fi'
    print -r -- '    }'
    print -r -- '    _ms_bash_comp_launch_repo_target() {'
    print -r -- '        local word=$1 opt_host=$2 opt_base_only=$3 trim=$4 host='\'''\'' prefix='\'''\'' rest'
    print -r -- '        if [[ $word == *:* ]] && _ms_bash_comp_valid_host "${word%%:*}"; then'
    print -r -- '            host=${word%%:*}'
    print -r -- '            rest=${word#*:}'
    print -r -- '            if _ms_bash_comp_local_host "$host" && [[ $rest == /* || $rest == \~* ]]; then'
    print -r -- '                _ms_bash_comp_dirs "$rest" "$host:"'
    print -r -- '                return 0'
    print -r -- '            fi'
    print -r -- '        elif _ms_bash_comp_local_host "$opt_host" && [[ $word == /* || $word == \~* ]]; then'
    print -r -- '            _ms_bash_comp_dirs "$word" '\'''\'''
    print -r -- '            return 0'
    print -r -- '        fi'
    print -r -- '        local -a _args=(launch-repo-target --current "$word")'
    print -r -- '        [[ -n $opt_host ]] && _args+=(--host "$opt_host")'
    print -r -- '        (( opt_base_only )) && _args+=(--base-only)'
    print -r -- '        _ms_bash_comp_helper "$word" '\'''\'' "${_args[@]}"'
    print -r -- '    }'
    print -r -- 'fi'
    print -r -- ''

    print -r -- "_ms_complete_${slug}() {"
    print -r -- '    local index current=${COMP_CWORD:-1} word token trim='\'''\'' REPLY'
    print -r -- '    local -a arguments=()'
    print -r -- '    word=${COMP_WORDS[current]-$2}'
    print -r -- '    if [[ $word == [:@=] ]]; then word='\'''\''; ((current+=1)); fi'
    print -r -- '    while (( current > 2 )) && [[ ${COMP_WORDS[current-1]} == [:@=] ]]; do'
    print -r -- '        trim=${COMP_WORDS[current-2]}${COMP_WORDS[current-1]}$trim'
    print -r -- '        ((current-=2))'
    print -r -- '    done'
    print -r -- '    _ms_bash_comp_unquote "$trim$word"'
    print -r -- '    word=$REPLY'
    print -r -- '    _ms_bash_comp_unquote "$trim"'
    print -r -- '    trim=$REPLY'
    print -r -- '    for ((index=1; index<current; index++)); do'
    print -r -- '        token=${COMP_WORDS[index]}'
    print -r -- '        while (( index+2 < current )) && [[ ${COMP_WORDS[index+1]} == [:@=] ]]; do'
    print -r -- '            token+=${COMP_WORDS[index+1]}${COMP_WORDS[index+2]}'
    print -r -- '            ((index+=2))'
    print -r -- '        done'
    print -r -- '        _ms_bash_comp_unquote "$token"'
    print -r -- '        arguments+=("$REPLY")'
    print -r -- '    done'
    print -r -- ''
    print -r -- '    local scope='\''_'\'' pending='\'''\'' opt_host='\'''\'' opt_repo='\'''\'''
    print -r -- '    local -i seen_dash=0 pos_count=0 dash_count=0 flag_form=0 has_command=0 opt_base_only=0'
    print -r -- '    for token in "${arguments[@]}"; do'
    print -r -- '        if [[ -n $pending ]]; then'
    print -r -- '            case $pending in'
    print -r -- '                --host) opt_host=$token ;;'
    print -r -- '                --repo) opt_repo=$token ;;'
    print -r -- '                --command) has_command=1 ;;'
    print -r -- '            esac'
    print -r -- '            case "$scope|$pending" in'
    for scope in "${spec_scopes[@]}"; do
        for idx in ${=spec_scope_flags[$scope]-}; do
            if (( flag_locks[idx] )); then
                f_names=( "${(@ps:,:)flag_names[idx]}" )
                for f in "${f_names[@]}"; do
                    _ms_rc_sh_sq "$scope|$f"
                    print -r -- "                $REPLY) flag_form=1 ;;"
                done
            fi
        done
    done
    print -r -- '            esac'
    print -r -- '            pending='\'''\'''
    print -r -- '        elif (( seen_dash )); then'
    print -r -- '            ((dash_count+=1))'
    print -r -- '        elif [[ $token == -- ]]; then'
    print -r -- '            seen_dash=1'
    print -r -- '        elif [[ $token == -* ]]; then'
    print -r -- '            [[ $token == --base-only ]] && opt_base_only=1'
    print -r -- '            case "$scope|$token" in'
    for scope in "${spec_scopes[@]}"; do
        for idx in ${=spec_scope_flags[$scope]-}; do
            f_names=( "${(@ps:,:)flag_names[idx]}" )
            if [[ -n ${flag_kind[idx]} ]]; then
                for f in "${f_names[@]}"; do
                    _ms_rc_sh_sq "$scope|$f"
                    print -r -- "                $REPLY) pending=\$token ;;"
                done
            elif (( flag_locks[idx] )); then
                for f in "${f_names[@]}"; do
                    _ms_rc_sh_sq "$scope|$f"
                    print -r -- "                $REPLY) flag_form=1 ;;"
                done
            fi
        done
    done
    print -r -- '            esac'
    print -r -- '        else'
    print -r -- '            if (( pos_count == 0 && ! flag_form )); then'
    print -r -- '                case "$scope|$token" in'
    for scope in "${spec_scopes[@]}"; do
        children=()
        [[ -n ${spec_scope_children[$scope]-} ]] && children=( "${(@f)spec_scope_children[$scope]}" )
        for child in "${children[@]}"; do
            if [[ $scope == '_' ]]; then full_child=$child; else full_child="$scope/$child"; fi
            _ms_rc_sh_sq "$scope|$child"
            match_sq=$REPLY
            _ms_rc_sh_sq "$full_child"
            print -r -- "                    $match_sq) scope=$REPLY; pos_count=0; flag_form=0; has_command=0; continue ;;"
        done
    done
    print -r -- '                esac'
    print -r -- '            fi'
    print -r -- '            ((pos_count+=1))'
    print -r -- '        fi'
    print -r -- '    done'
    print -r -- ''
    print -r -- '    COMPREPLY=()'
    print -r -- '    if [[ -n $pending ]]; then'
    print -r -- '        case "$scope|$pending" in'
    for scope in "${spec_scopes[@]}"; do
        for idx in ${=spec_scope_flags[$scope]-}; do
            [[ -n ${flag_kind[idx]} ]] || continue
            f_names=( "${(@ps:,:)flag_names[idx]}" )
            for f in "${f_names[@]}"; do
                _ms_rc_sh_sq "$scope|$f"
                print -r -- "            $REPLY)"
                _ms_rc_bash_emit_kind '                ' "${flag_kind[idx]}"
                print -r -- '                ;;'
            done
        done
    done
    print -r -- '        esac'
    print -r -- '    elif (( seen_dash )); then'
    print -r -- '        case $scope in'
    for scope in "${spec_scopes[@]}"; do
        [[ -n ${arg_kind[${scope}:dash1]-} || -n ${arg_kind[${scope}:dash-rest]-} ]] || continue
        mode_val=${spec_scope_mode[$scope]-}
        _ms_rc_sh_sq "$scope"
        print -r -- "            $REPLY)"
        print -r -- '                if (( dash_count == 0 )); then'
        if [[ $mode_val == flag-form-locks-positional && -n ${arg_kind[${scope}:dash-rest]-} ]]; then
            print -r -- '                    if (( has_command )); then'
            _ms_rc_bash_emit_kind '                        ' "${arg_kind[${scope}:dash-rest]}"
            print -r -- '                    else'
            if [[ -n ${arg_kind[${scope}:dash1]-} ]]; then
                _ms_rc_bash_emit_kind '                        ' "${arg_kind[${scope}:dash1]}"
            else
                _ms_rc_bash_emit_kind '                        ' "${arg_kind[${scope}:dash-rest]}"
            fi
            print -r -- '                    fi'
        elif [[ -n ${arg_kind[${scope}:dash1]-} ]]; then
            _ms_rc_bash_emit_kind '                    ' "${arg_kind[${scope}:dash1]}"
        else
            _ms_rc_bash_emit_kind '                    ' "${arg_kind[${scope}:dash-rest]}"
        fi
        print -r -- '                else'
        if [[ -n ${arg_kind[${scope}:dash-rest]-} ]]; then
            _ms_rc_bash_emit_kind '                    ' "${arg_kind[${scope}:dash-rest]}"
        else
            print -r -- '                    :'
        fi
        print -r -- '                fi'
        print -r -- '                ;;'
    done
    print -r -- '        esac'
    print -r -- '    else'
    print -r -- '        case $scope in'
    for scope in "${spec_scopes[@]}"; do
        mode_val=${spec_scope_mode[$scope]-}
        children=()
        [[ -n ${spec_scope_children[$scope]-} ]] && children=( "${(@f)spec_scope_children[$scope]}" )
        max_pos=${spec_scope_max_pos[$scope]:-0}
        all_flags=()
        for idx in ${=spec_scope_flags[$scope]-}; do
            f_names=( "${(@ps:,:)flag_names[idx]}" )
            all_flags+=( "${f_names[@]}" )
        done
        _ms_rc_sh_sq "$scope"
        print -r -- "            $REPLY)"
        if (( $#all_flags )); then
            quoted=()
            for f in "${all_flags[@]}"; do _ms_rc_sh_sq "$f"; quoted+=( "$REPLY" ); done
            if [[ $mode_val == flag-form-locks-positional ]]; then
                print -r -- '                if [[ $word == -* && $pos_count -eq 0 ]]; then'
            else
                print -r -- '                if [[ $word == -* ]]; then'
            fi
            print -r -- "                    _ms_bash_comp_choices \"\$word\" ${(j: :)quoted}"
            print -r -- '                else'
        else
            print -r -- '                if false; then :'
            print -r -- '                else'
        fi
        if (( $#children )); then
            quoted=()
            for child in "${children[@]}"; do _ms_rc_sh_sq "$child"; quoted+=( "$REPLY" ); done
            print -r -- '                    if (( pos_count == 0 )); then'
            print -r -- "                        _ms_bash_comp_choices \"\$word\" ${(j: :)quoted}"
            print -r -- '                    fi'
        else
            print -r -- '                    case $((pos_count + 1)) in'
            for (( pos = 1; pos <= max_pos; pos++ )); do
                [[ -n ${arg_kind[${scope}:$pos]-} ]] || continue
                print -r -- "                        $pos)"
                if (( pos == 1 )) && [[ $mode_val == flag-form-locks-positional ]]; then
                    print -r -- '                            if (( ! flag_form )); then'
                    _ms_rc_bash_emit_kind '                                ' "${arg_kind[${scope}:$pos]}"
                    print -r -- '                            fi'
                else
                    _ms_rc_bash_emit_kind '                            ' "${arg_kind[${scope}:$pos]}"
                fi
                print -r -- '                            ;;'
            done
            if [[ -n ${arg_kind[${scope}:rest]-} ]]; then
                print -r -- '                        *)'
                _ms_rc_bash_emit_kind '                            ' "${arg_kind[${scope}:rest]}"
                print -r -- '                            ;;'
            fi
            print -r -- '                    esac'
        fi
        print -r -- '                fi'
        print -r -- '                ;;'
    done
    print -r -- '        esac'
    print -r -- '    fi'
    print -r -- '    if [[ -n $trim ]]; then'
    print -r -- '        for index in "${!COMPREPLY[@]}"; do COMPREPLY[index]=${COMPREPLY[index]#"$trim"}; done'
    print -r -- '    fi'
    print -r -- '}'
    _ms_rc_sh_sq "$spec_cmd"
    print -r -- "complete -o filenames -F _ms_complete_${slug} $REPLY"
}

# --- FISH EMITTER ------------------------------------------------------------

# Return the fish `-a '...'` (or `-F` for file) flags for a <kind> into REPLY.
_ms_rc_fish_arg_flags() {
    local slug=$1 kind=$2
    local -a items=() quoted=()
    local item
    case $kind in
        string)                  REPLY='-x' ;;
        dir)                     REPLY="-x -a '(__fish_complete_directories)'" ;;
        file)                    REPLY='-r -F' ;;
        command)                 REPLY="-x -a '(__fish_complete_command)'" ;;
        choices:*)
            items=( "${(@ps:,:)${kind#choices:}}" )
            for item in "${items[@]}"; do
                _ms_rc_fish_sq "$item"
                quoted+=( "$REPLY" )
            done
            REPLY="-x -a '(printf \"%s\\n\" ${(j: :)quoted})'"
            ;;
        ms:modules)              REPLY="-x -a '(__ms_comp_${slug}_helper modules)'" ;;
        ms:hosts)                REPLY="-x -a '(__ms_comp_${slug}_helper hosts)'" ;;
        ms:installers)           REPLY="-x -a '(__ms_comp_${slug}_helper installers)'" ;;
        ms:update-steps)         REPLY="-x -a '(__ms_comp_${slug}_helper update-steps)'" ;;
        ms:launch-hosts)         REPLY="-x -a '(__ms_comp_${slug}_helper launch-hosts)'" ;;
        ms:git-branches)         REPLY="-x -a '(__ms_comp_${slug}_helper git-branches)'" ;;
        ms:repos)                REPLY="-x -a '(__ms_comp_${slug}_kind repos)'" ;;
        ms:base-repos)           REPLY="-x -a '(__ms_comp_${slug}_kind base-repos)'" ;;
        ms:base-repos-or-dir)    REPLY="-x -a '(__ms_comp_${slug}_kind base-repos-or-dir)'" ;;
        ms:worktrees)            REPLY="-x -a '(__ms_comp_${slug}_kind worktrees)'" ;;
        ms:launch-session-target) REPLY="-x -a '(__ms_comp_${slug}_kind launch-session-target)'" ;;
        ms:launch-repo-target)   REPLY="-x -a '(__ms_comp_${slug}_kind launch-repo-target)'" ;;
    esac
}

# Return the fish positional `-a '...'` / `-F` flags (without `-x` / `-r`) for a <kind>.
_ms_rc_fish_pos_flags() {
    local slug=$1 kind=$2
    local -a items=() quoted=()
    local item
    case $kind in
        string)                  REPLY='' ;;
        dir)                     REPLY="-a '(__fish_complete_directories)'" ;;
        file)                    REPLY='-F' ;;
        command)                 REPLY="-a '(__fish_complete_command)'" ;;
        choices:*)
            items=( "${(@ps:,:)${kind#choices:}}" )
            for item in "${items[@]}"; do
                _ms_rc_fish_sq "$item"
                quoted+=( "$REPLY" )
            done
            REPLY="-a '(printf \"%s\\n\" ${(j: :)quoted})'"
            ;;
        ms:modules)              REPLY="-a '(__ms_comp_${slug}_helper modules)'" ;;
        ms:hosts)                REPLY="-a '(__ms_comp_${slug}_helper hosts)'" ;;
        ms:installers)           REPLY="-a '(__ms_comp_${slug}_helper installers)'" ;;
        ms:update-steps)         REPLY="-a '(__ms_comp_${slug}_helper update-steps)'" ;;
        ms:launch-hosts)         REPLY="-a '(__ms_comp_${slug}_helper launch-hosts)'" ;;
        ms:git-branches)         REPLY="-a '(__ms_comp_${slug}_helper git-branches)'" ;;
        ms:repos)                REPLY="-a '(__ms_comp_${slug}_kind repos)'" ;;
        ms:base-repos)           REPLY="-a '(__ms_comp_${slug}_kind base-repos)'" ;;
        ms:base-repos-or-dir)    REPLY="-a '(__ms_comp_${slug}_kind base-repos-or-dir)'" ;;
        ms:worktrees)            REPLY="-a '(__ms_comp_${slug}_kind worktrees)'" ;;
        ms:launch-session-target) REPLY="-a '(__ms_comp_${slug}_kind launch-session-target)'" ;;
        ms:launch-repo-target)   REPLY="-a '(__ms_comp_${slug}_kind launch-repo-target)'" ;;
    esac
}

# Emit a Fish completion file to stdout for the currently parsed spec.
_ms_rc_emit_fish() {
    emulate -L zsh
    local helper=$1 slug home_sq cmd_sq scope scope_sq child full_child idx f_kind mode_val
    local desc_opt cond f short_f long_f extra_flags msq cond_sq child_sq flag_opts
    local -a f_names=() children=() shorts=() longs=()
    integer pos max_pos i max_n

    _ms_rc_slug "$spec_cmd"; slug=$REPLY
    _ms_rc_fish_sq "$MARKSHARC_HOME"; home_sq=$REPLY
    _ms_rc_fish_sq "$spec_cmd"; cmd_sq=$REPLY

    print -r -- '# Generated by marksharc render; do not edit.'
    print -r -- ''
    print -r -- "function __ms_comp_${slug}_helper"
    print -r -- '    set -l home "$MARKSHARC_HOME"'
    print -r -- "    test -n \"\$home\"; or set home $home_sq"
    print -r -- '    test -r "$home/core/cli/complete"; or return 0'
    print -r -- '    set -l env_args'
    print -r -- '    if set -q MARKSHARC_HOST; and test -n "$MARKSHARC_HOST"'
    print -r -- '        set -a env_args "MARKSHARC_HOST=$MARKSHARC_HOST"'
    print -r -- '    end'
    print -r -- '    if set -q MARKSHARC_CONFIG; and test -n "$MARKSHARC_CONFIG"'
    print -r -- '        set -a env_args "MARKSHARC_CONFIG=$MARKSHARC_CONFIG"'
    print -r -- '    end'
    print -r -- '    command env $env_args zsh -f "$home/core/cli/complete" $argv 2>/dev/null'
    print -r -- 'end'
    print -r -- ''
    print -r -- "function __ms_comp_${slug}_ctx"
    print -r -- '    set -l query $argv[1]'
    print -r -- '    set -l tokens (commandline -opc)'
    print -r -- '    set -l scope _'
    print -r -- '    set -l pending ""'
    print -r -- '    set -l seen_dash 0'
    print -r -- '    set -l pos_count 0'
    print -r -- '    set -l dash_count 0'
    print -r -- '    set -l flag_form 0'
    print -r -- '    set -l has_cmd 0'
    print -r -- '    set -l opt_host ""'
    print -r -- '    set -l opt_repo ""'
    print -r -- '    set -l base_only 0'
    print -r -- '    if test (count $tokens) -ge 2'
    print -r -- '        for tok in $tokens[2..-1]'
    print -r -- '            if test -n "$pending"'
    print -r -- '                switch "$pending"'
    print -r -- '                    case --host'
    print -r -- '                        set opt_host "$tok"'
    print -r -- '                    case --repo'
    print -r -- '                        set opt_repo "$tok"'
    print -r -- '                    case --command'
    print -r -- '                        set has_cmd 1'
    print -r -- '                end'
    print -r -- '                switch "$scope|$pending"'
    for scope in "${spec_scopes[@]}"; do
        for idx in ${=spec_scope_flags[$scope]-}; do
            if (( flag_locks[idx] )); then
                f_names=( "${(@ps:,:)flag_names[idx]}" )
                for f in "${f_names[@]}"; do
                    _ms_rc_fish_sq "$scope|$f"
                    print -r -- "                    case $REPLY"
                    print -r -- '                        set flag_form 1'
                done
            fi
        done
    done
    print -r -- '                end'
    print -r -- '                set pending ""'
    print -r -- '            else if test "$seen_dash" -eq 1'
    print -r -- '                set dash_count (math $dash_count + 1)'
    print -r -- '            else if test "$tok" = --'
    print -r -- '                set seen_dash 1'
    print -r -- '            else if string match -q -- "-*" "$tok"'
    print -r -- '                test "$tok" = --base-only; and set base_only 1'
    print -r -- '                switch "$scope|$tok"'
    for scope in "${spec_scopes[@]}"; do
        for idx in ${=spec_scope_flags[$scope]-}; do
            f_names=( "${(@ps:,:)flag_names[idx]}" )
            if [[ -n ${flag_kind[idx]} ]]; then
                for f in "${f_names[@]}"; do
                    _ms_rc_fish_sq "$scope|$f"
                    print -r -- "                    case $REPLY"
                    print -r -- '                        set pending "$tok"'
                done
            elif (( flag_locks[idx] )); then
                for f in "${f_names[@]}"; do
                    _ms_rc_fish_sq "$scope|$f"
                    print -r -- "                    case $REPLY"
                    print -r -- '                        set flag_form 1'
                done
            fi
        done
    done
    print -r -- '                end'
    print -r -- '            else'
    print -r -- '                set -l matched_sub 0'
    print -r -- '                if test "$pos_count" -eq 0; and test "$flag_form" -eq 0'
    print -r -- '                    switch "$scope|$tok"'
    for scope in "${spec_scopes[@]}"; do
        children=()
        [[ -n ${spec_scope_children[$scope]-} ]] && children=( "${(@f)spec_scope_children[$scope]}" )
        for child in "${children[@]}"; do
            if [[ $scope == '_' ]]; then full_child=$child; else full_child="$scope/$child"; fi
            _ms_rc_fish_sq "$scope|$child"
            msq=$REPLY
            _ms_rc_fish_sq "$full_child"
            print -r -- "                        case $msq"
            print -r -- "                            set scope $REPLY"
            print -r -- '                            set pos_count 0'
            print -r -- '                            set flag_form 0'
            print -r -- '                            set has_cmd 0'
            print -r -- '                            set matched_sub 1'
        done
    done
    print -r -- '                    end'
    print -r -- '                end'
    print -r -- '                if test "$matched_sub" -eq 0'
    print -r -- '                    set pos_count (math $pos_count + 1)'
    print -r -- '                end'
    print -r -- '            end'
    print -r -- '        end'
    print -r -- '    end'
    print -r -- '    switch "$query"'
    print -r -- '        case scope'
    print -r -- '            echo "$scope"'
    print -r -- '        case pending'
    print -r -- '            echo "$pending"'
    print -r -- '        case dash'
    print -r -- '            echo "$seen_dash"'
    print -r -- '        case pos'
    print -r -- '            echo "$pos_count"'
    print -r -- '        case dash_pos'
    print -r -- '            echo "$dash_count"'
    print -r -- '        case locked'
    print -r -- '            echo "$flag_form"'
    print -r -- '        case has_cmd'
    print -r -- '            echo "$has_cmd"'
    print -r -- '        case host'
    print -r -- '            echo "$opt_host"'
    print -r -- '        case repo'
    print -r -- '            echo "$opt_repo"'
    print -r -- '        case base_only'
    print -r -- '            echo "$base_only"'
    print -r -- '    end'
    print -r -- 'end'
    print -r -- ''
    print -r -- "function __ms_comp_${slug}_kind"
    print -r -- '    set -l kind $argv[1]'
    print -r -- "    set -l host (__ms_comp_${slug}_ctx host)"
    print -r -- "    set -l repo (__ms_comp_${slug}_ctx repo)"
    print -r -- "    set -l base_only (__ms_comp_${slug}_ctx base_only)"
    print -r -- '    set -l cur (commandline -ct)'
    print -r -- '    set -l machine "$MARKSHARC_HOST"'
    print -r -- '    test -n "$machine"; or set machine (hostname -s)'
    print -r -- '    switch "$kind"'
    print -r -- '        case repos'
    print -r -- '            set -l args repos'
    print -r -- '            test -n "$host"; and set -a args --host "$host"'
    print -r -- '            test "$base_only" -eq 1; and set -a args --base-only'
    print -r -- "            __ms_comp_${slug}_helper \$args"
    print -r -- '        case base-repos'
    print -r -- '            set -l args base-repos'
    print -r -- '            test -n "$host"; and set -a args --host "$host"'
    print -r -- "            __ms_comp_${slug}_helper \$args"
    print -r -- '        case base-repos-or-dir'
    print -r -- '            if contains -- "$host" "" local localhost "$machine"; and string match -qr '\''^(/|~)'\'' -- "$cur"'
    print -r -- '                __fish_complete_directories "$cur"'
    print -r -- '            else'
    print -r -- '                set -l args base-repos'
    print -r -- '                test -n "$host"; and set -a args --host "$host"'
    print -r -- "                __ms_comp_${slug}_helper \$args"
    print -r -- '            end'
    print -r -- '        case worktrees'
    print -r -- '            set -l args worktrees'
    print -r -- '            test -n "$host"; and set -a args --host "$host"'
    print -r -- '            test -n "$repo"; and set -a args --repo "$repo"'
    print -r -- "            __ms_comp_${slug}_helper \$args"
    print -r -- '        case launch-session-target'
    print -r -- '            if string match -q "*:*" -- "$cur"'
    print -r -- '                set -l parts (string split -m 1 : -- "$cur")'
    print -r -- '                if contains -- "$parts[1]" "" local localhost "$machine"'
    print -r -- '                    for d in (__fish_complete_directories "$parts[2]")'
    print -r -- '                        echo "$parts[1]:$d"'
    print -r -- '                    end'
    print -r -- '                end'
    print -r -- '            else'
    print -r -- '                __fish_complete_directories "$cur"'
    print -r -- "                __ms_comp_${slug}_helper launch-hosts --colon"
    print -r -- '            end'
    print -r -- '        case launch-repo-target'
    print -r -- '            if string match -qr '\''^(/|~)'\'' -- "$cur"'
    print -r -- '                __fish_complete_directories "$cur"'
    print -r -- '            else if string match -q "*:*" -- "$cur"'
    print -r -- '                set -l parts (string split -m 1 : -- "$cur")'
    print -r -- '                if contains -- "$parts[1]" "" local localhost "$machine"; and string match -qr '\''^(/|~)'\'' -- "$parts[2]"'
    print -r -- '                    for d in (__fish_complete_directories "$parts[2]")'
    print -r -- '                        echo "$parts[1]:$d"'
    print -r -- '                    end'
    print -r -- '                else'
    print -r -- '                    set -l args launch-repo-target --current "$cur"'
    print -r -- '                    test -n "$host"; and set -a args --host "$host"'
    print -r -- '                    test "$base_only" -eq 1; and set -a args --base-only'
    print -r -- "                    __ms_comp_${slug}_helper \$args"
    print -r -- '                end'
    print -r -- '            else'
    print -r -- '                set -l args launch-repo-target --current "$cur"'
    print -r -- '                test -n "$host"; and set -a args --host "$host"'
    print -r -- '                test "$base_only" -eq 1; and set -a args --base-only'
    print -r -- "                __ms_comp_${slug}_helper \$args"
    print -r -- '            end'
    print -r -- '    end'
    print -r -- 'end'
    print -r -- ''

    print -r -- "complete -c $cmd_sq -f"

    for scope in "${spec_scopes[@]}"; do
        _ms_rc_fish_sq "$scope"; scope_sq=$REPLY
        mode_val=${spec_scope_mode[$scope]-}
        children=()
        [[ -n ${spec_scope_children[$scope]-} ]] && children=( "${(@f)spec_scope_children[$scope]}" )
        max_pos=${spec_scope_max_pos[$scope]:-0}

        # Child subcommands
        for child in "${children[@]}"; do
            if [[ $scope == '_' ]]; then full_child=$child; else full_child="$scope/$child"; fi
            cond="test (__ms_comp_${slug}_ctx scope) = $scope_sq; and test (__ms_comp_${slug}_ctx pending) = ''; and test (__ms_comp_${slug}_ctx dash) -eq 0; and test (__ms_comp_${slug}_ctx pos) -eq 0"
            _ms_rc_fish_sq "$cond"; cond_sq=$REPLY
            _ms_rc_fish_sq "$child"; child_sq=$REPLY
            desc_opt=''
            if [[ -n ${spec_scope_desc[$full_child]-} ]]; then
                _ms_rc_fish_sq "${spec_scope_desc[$full_child]//[[:cntrl:]]/}"
                desc_opt=" -d $REPLY"
            fi
            print -r -- "complete -c $cmd_sq -n $cond_sq -a $child_sq$desc_opt"
        done

        # Flags
        for idx in ${=spec_scope_flags[$scope]-}; do
            f_names=( "${(@ps:,:)flag_names[idx]}" )
            f_kind=${flag_kind[idx]}
            shorts=()
            longs=()
            for f in "${f_names[@]}"; do
                if [[ $f == --* ]]; then longs+=( "${f#--}" ); else shorts+=( "${f#-}" ); fi
            done
            cond="test (__ms_comp_${slug}_ctx scope) = $scope_sq; and test (__ms_comp_${slug}_ctx dash) -eq 0"
            if [[ $mode_val == flag-form-locks-positional ]]; then
                cond+="; and test (__ms_comp_${slug}_ctx pos) -eq 0"
            fi
            _ms_rc_fish_sq "$cond"; cond_sq=$REPLY
            desc_opt=''
            if [[ -n ${flag_desc[idx]} ]]; then
                _ms_rc_fish_sq "${flag_desc[idx]//[[:cntrl:]]/}"
                desc_opt=" -d $REPLY"
            fi
            extra_flags=''
            if [[ -n $f_kind ]]; then
                _ms_rc_fish_arg_flags "$slug" "$f_kind"
                extra_flags=" $REPLY"
            fi
            # Pair first short and first long on one complete line; emit any extras separately.
            max_n=$(( $#shorts > $#longs ? $#shorts : $#longs ))
            for (( i = 1; i <= max_n; i++ )); do
                flag_opts=''
                if (( i <= $#shorts )); then
                    _ms_rc_fish_sq "${shorts[i]}"
                    flag_opts+=" -s $REPLY"
                fi
                if (( i <= $#longs )); then
                    _ms_rc_fish_sq "${longs[i]}"
                    flag_opts+=" -l $REPLY"
                fi
                print -r -- "complete -c $cmd_sq -n $cond_sq$flag_opts$extra_flags$desc_opt"
            done
        done

        # Numbered positional args
        for (( pos = 1; pos <= max_pos; pos++ )); do
            [[ -n ${arg_kind[${scope}:$pos]-} ]] || continue
            _ms_rc_fish_pos_flags "$slug" "${arg_kind[${scope}:$pos]}"
            extra_flags=$REPLY
            [[ -n $extra_flags ]] || continue
            cond="test (__ms_comp_${slug}_ctx scope) = $scope_sq; and test (__ms_comp_${slug}_ctx pending) = ''; and test (__ms_comp_${slug}_ctx dash) -eq 0; and test (__ms_comp_${slug}_ctx pos) -eq $(( pos - 1 ))"
            if (( pos == 1 )) && [[ $mode_val == flag-form-locks-positional ]]; then
                cond+="; and test (__ms_comp_${slug}_ctx locked) -eq 0"
            fi
            _ms_rc_fish_sq "$cond"; cond_sq=$REPLY
            desc_opt=''
            if [[ -n ${arg_desc[${scope}:$pos]-} ]]; then
                _ms_rc_fish_sq "${arg_desc[${scope}:$pos]//[[:cntrl:]]/}"
                desc_opt=" -d $REPLY"
            fi
            print -r -- "complete -c $cmd_sq -n $cond_sq $extra_flags$desc_opt"
        done

        # Rest positional arg
        if [[ -n ${arg_kind[${scope}:rest]-} ]]; then
            _ms_rc_fish_pos_flags "$slug" "${arg_kind[${scope}:rest]}"
            extra_flags=$REPLY
            if [[ -n $extra_flags ]]; then
                cond="test (__ms_comp_${slug}_ctx scope) = $scope_sq; and test (__ms_comp_${slug}_ctx pending) = ''; and test (__ms_comp_${slug}_ctx dash) -eq 0; and test (__ms_comp_${slug}_ctx pos) -ge $max_pos"
                if (( max_pos == 0 )) && [[ $mode_val == flag-form-locks-positional ]]; then
                    cond+="; and test (__ms_comp_${slug}_ctx locked) -eq 0"
                fi
                _ms_rc_fish_sq "$cond"; cond_sq=$REPLY
                print -r -- "complete -c $cmd_sq -n $cond_sq $extra_flags"
            fi
        fi

        # Dash1 arg
        if [[ -n ${arg_kind[${scope}:dash1]-} ]]; then
            _ms_rc_fish_pos_flags "$slug" "${arg_kind[${scope}:dash1]}"
            extra_flags=$REPLY
            if [[ -n $extra_flags ]]; then
                cond="test (__ms_comp_${slug}_ctx scope) = $scope_sq; and test (__ms_comp_${slug}_ctx dash) -eq 1; and test (__ms_comp_${slug}_ctx dash_pos) -eq 0"
                if [[ $mode_val == flag-form-locks-positional ]]; then
                    cond+="; and test (__ms_comp_${slug}_ctx has_cmd) -eq 0"
                fi
                _ms_rc_fish_sq "$cond"; cond_sq=$REPLY
                print -r -- "complete -c $cmd_sq -n $cond_sq $extra_flags"
            fi
        fi

        # Dash-rest arg
        if [[ -n ${arg_kind[${scope}:dash-rest]-} ]]; then
            _ms_rc_fish_pos_flags "$slug" "${arg_kind[${scope}:dash-rest]}"
            extra_flags=$REPLY
            if [[ -n $extra_flags ]]; then
                if [[ -n ${arg_kind[${scope}:dash1]-} ]]; then
                    cond="test (__ms_comp_${slug}_ctx scope) = $scope_sq; and test (__ms_comp_${slug}_ctx dash) -eq 1; and test (__ms_comp_${slug}_ctx dash_pos) -ge 1"
                    _ms_rc_fish_sq "$cond"; cond_sq=$REPLY
                    print -r -- "complete -c $cmd_sq -n $cond_sq $extra_flags"
                    if [[ $mode_val == flag-form-locks-positional ]]; then
                        cond="test (__ms_comp_${slug}_ctx scope) = $scope_sq; and test (__ms_comp_${slug}_ctx dash) -eq 1; and test (__ms_comp_${slug}_ctx dash_pos) -eq 0; and test (__ms_comp_${slug}_ctx has_cmd) -eq 1"
                        _ms_rc_fish_sq "$cond"; cond_sq=$REPLY
                        print -r -- "complete -c $cmd_sq -n $cond_sq $extra_flags"
                    fi
                else
                    cond="test (__ms_comp_${slug}_ctx scope) = $scope_sq; and test (__ms_comp_${slug}_ctx dash) -eq 1"
                    _ms_rc_fish_sq "$cond"; cond_sq=$REPLY
                    print -r -- "complete -c $cmd_sq -n $cond_sq $extra_flags"
                fi
            fi
        fi
    done
}

# --- CARAPACE 1.8.5 YAML EMITTER ---------------------------------------------

# Fill global `reply` with the Carapace action strings for a <kind>.
_ms_rc_carapace_actions() {
    local hq=$1 kind=$2
    reply=()
    case $kind in
        string)                  return 0 ;;
        dir)                     reply=( '$directories' ) ;;
        file)                    reply=( '$files' ) ;;
        command)                 reply=( '$carapace.shell.Executables' ) ;;
        choices:*)               reply=( "${(@ps:,:)${kind#choices:}}" ) ;;
        ms:modules)              reply=( "\$($hq modules --from-carapace)" ) ;;
        ms:hosts)                reply=( "\$($hq hosts --from-carapace)" ) ;;
        ms:installers)           reply=( "\$($hq installers --from-carapace)" ) ;;
        ms:update-steps)         reply=( "\$($hq update-steps --from-carapace)" ) ;;
        ms:launch-hosts)         reply=( "\$($hq launch-hosts --from-carapace)" ) ;;
        ms:repos)                reply=( "\$($hq repos --from-carapace)" ) ;;
        ms:base-repos)           reply=( "\$($hq base-repos --from-carapace)" ) ;;
        ms:base-repos-or-dir)    reply=( '$directories' "\$($hq base-repos --from-carapace)" ) ;;
        ms:worktrees)            reply=( "\$($hq worktrees --from-carapace)" ) ;;
        ms:git-branches)         reply=( "\$($hq git-branches --from-carapace)" ) ;;
        ms:launch-session-target) reply=( '$directories' "\$($hq launch-hosts --colon --from-carapace)" '$nospace(:)' ) ;;
        ms:launch-repo-target)   reply=( '$directories' "\$($hq launch-repo-target --from-carapace)" '$nospace(:)' ) ;;
    esac
}

# Emit a Carapace command object (root or nested subcommand) at given indentation.
_ms_rc_emit_carapace_scope() {
    local scope=$1 name=$2 desc=$3 indent=$4 hq=$5
    local idx f f_key f_spec f_desc_dq suffix act act_dq child full_child k_dq sub_out sub_line
    local -a f_names=() children=() flag_comp_indices=()
    integer max_pos pos has_comp=0 j first

    _ms_rc_yaml_dq "$name"
    print -r -- "${indent}name: $REPLY"
    if [[ -n $desc ]]; then
        _ms_rc_yaml_dq "$desc"
        print -r -- "${indent}description: $REPLY"
    fi

    # Flags
    if [[ -n ${spec_scope_flags[$scope]-} ]]; then
        print -r -- "${indent}flags:"
        for idx in ${=spec_scope_flags[$scope]-}; do
            f_names=( "${(@ps:,:)flag_names[idx]}" )
            suffix=''
            (( flag_repeat[idx] )) && suffix+='*'
            [[ -n ${flag_kind[idx]} ]] && suffix+='='
            f_spec="${(j:, :)f_names}${suffix}"
            _ms_rc_yaml_dq "$f_spec"
            k_dq=$REPLY
            _ms_rc_yaml_dq "${flag_desc[idx]}"
            f_desc_dq=$REPLY
            print -r -- "${indent}  ${k_dq}: ${f_desc_dq}"
            if [[ -n ${flag_kind[idx]} && ${flag_kind[idx]} != string ]]; then
                flag_comp_indices+=( "$idx" )
                has_comp=1
            fi
        done
    fi

    max_pos=${spec_scope_max_pos[$scope]:-0}
    (( max_pos > 0 )) && has_comp=1
    [[ -n ${arg_kind[${scope}:rest]-} && ${arg_kind[${scope}:rest]} != string ]] && has_comp=1
    [[ -n ${arg_kind[${scope}:dash1]-} && ${arg_kind[${scope}:dash1]} != string ]] && has_comp=1
    [[ -n ${arg_kind[${scope}:dash-rest]-} && ${arg_kind[${scope}:dash-rest]} != string ]] && has_comp=1

    if (( has_comp )); then
        print -r -- "${indent}completion:"
        if (( $#flag_comp_indices )); then
            print -r -- "${indent}  flag:"
            for idx in "${flag_comp_indices[@]}"; do
                f_names=( "${(@ps:,:)flag_names[idx]}" )
                f_key=''
                for f in "${f_names[@]}"; do
                    if [[ $f == --* ]]; then f_key=${f#--}; break; fi
                done
                [[ -n $f_key ]] || f_key=${f_names[1]#-}
                _ms_rc_carapace_actions "$hq" "${flag_kind[idx]}"
                (( $#reply )) || continue
                _ms_rc_yaml_dq "$f_key"
                print -r -- "${indent}    ${REPLY}:"
                for act in "${reply[@]}"; do
                    _ms_rc_yaml_dq "$act"
                    print -r -- "${indent}      - $REPLY"
                done
            done
        fi
        if (( max_pos > 0 )); then
            print -r -- "${indent}  positional:"
            for (( pos = 1; pos <= max_pos; pos++ )); do
                _ms_rc_carapace_actions "$hq" "${arg_kind[${scope}:$pos]-string}"
                if (( ! $#reply )); then
                    print -r -- "${indent}    - []"
                else
                    _ms_rc_yaml_dq "${reply[1]}"
                    print -r -- "${indent}    - - $REPLY"
                    for (( j = 2; j <= $#reply; j++ )); do
                        _ms_rc_yaml_dq "${reply[j]}"
                        print -r -- "${indent}      - $REPLY"
                    done
                fi
            done
        fi
        if [[ -n ${arg_kind[${scope}:rest]-} && ${arg_kind[${scope}:rest]} != string ]]; then
            _ms_rc_carapace_actions "$hq" "${arg_kind[${scope}:rest]}"
            if (( $#reply )); then
                print -r -- "${indent}  positionalany:"
                for act in "${reply[@]}"; do
                    _ms_rc_yaml_dq "$act"
                    print -r -- "${indent}    - $REPLY"
                done
            fi
        fi
        if [[ -n ${arg_kind[${scope}:dash1]-} && ${arg_kind[${scope}:dash1]} != string ]]; then
            _ms_rc_carapace_actions "$hq" "${arg_kind[${scope}:dash1]}"
            if (( $#reply )); then
                print -r -- "${indent}  dash:"
                _ms_rc_yaml_dq "${reply[1]}"
                print -r -- "${indent}    - - $REPLY"
                for (( j = 2; j <= $#reply; j++ )); do
                    _ms_rc_yaml_dq "${reply[j]}"
                    print -r -- "${indent}      - $REPLY"
                done
            fi
        fi
        if [[ -n ${arg_kind[${scope}:dash-rest]-} && ${arg_kind[${scope}:dash-rest]} != string ]]; then
            _ms_rc_carapace_actions "$hq" "${arg_kind[${scope}:dash-rest]}"
            if (( $#reply )); then
                print -r -- "${indent}  dashany:"
                for act in "${reply[@]}"; do
                    _ms_rc_yaml_dq "$act"
                    print -r -- "${indent}    - $REPLY"
                done
            fi
        fi
    fi

    children=()
    [[ -n ${spec_scope_children[$scope]-} ]] && children=( "${(@f)spec_scope_children[$scope]}" )
    if (( $#children )); then
        print -r -- "${indent}commands:"
        for child in "${children[@]}"; do
            if [[ $scope == '_' ]]; then full_child=$child; else full_child="$scope/$child"; fi
            # First line of each list item uses "- " prefix; subsequent lines indent by 4.
            first=1
            sub_out=$(_ms_rc_emit_carapace_scope "$full_child" "$child" "${spec_scope_desc[$full_child]-}" "${indent}    " "$hq")
            while IFS= read -r sub_line || [[ -n $sub_line ]]; do
                if (( first )); then
                    print -r -- "${indent}  - ${sub_line#${indent}    }"
                    first=0
                else
                    print -r -- "$sub_line"
                fi
            done <<< "$sub_out"
        done
    fi
}

_ms_rc_emit_carapace() {
    emulate -L zsh
    local helper=$1 hq
    _ms_rc_sh_sq "$helper"; hq=$REPLY
    print -r -- '# Generated by marksharc render; do not edit.'
    _ms_rc_emit_carapace_scope '_' "$spec_cmd" "$spec_desc" '' "$hq"
}

# --- ENTRY POINT -------------------------------------------------------------

# Discover all .comp specs (core < enabled public modules < enabled overlay modules),
# validate every discovered spec, resolve override precedence by command name,
# and render zsh, bash, fish, and carapace targets into $1.
_ms_render_completions() {
    emulate -L zsh
    local stage=$1
    local config=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}
    local helper="$MARKSHARC_HOME/core/cli/complete"
    local file mod dir cmd
    local -a discovered=() cmd_order=()
    local -A cmd_file=()

    # 1. Framework core specs (always active)
    for file in "$MARKSHARC_HOME"/core/completions/*.comp(N-.); do
        discovered+=( "$file" )
    done
    # 2. Enabled public modules in render plan
    for mod in "${_ms_plan[@]}"; do
        dir=${_ms_mod_dir[$mod]-}
        [[ $dir == "$MARKSHARC_HOME"/modules/* ]] || continue
        for file in "$dir"/completions/*.comp(N-.); do
            discovered+=( "$file" )
        done
    done
    # 3. Enabled overlay modules in render plan (highest precedence)
    for mod in "${_ms_plan[@]}"; do
        dir=${_ms_mod_dir[$mod]-}
        [[ $dir == "$config"/modules/* ]] || continue
        for file in "$dir"/completions/*.comp(N-.); do
            discovered+=( "$file" )
        done
    done

    (( $#discovered )) || return 0

    local spec_cmd spec_desc
    local -a spec_scopes flag_scope flag_names flag_kind flag_repeat flag_locks flag_desc
    local -A spec_scope_exists spec_scope_desc spec_scope_children spec_scope_mode spec_scope_flags spec_scope_max_pos arg_kind arg_desc

    # Validate every discovered spec and record winning file per command name.
    for file in "${discovered[@]}"; do
        _ms_rc_parse "$file" || return 1
        if [[ -z ${cmd_file[$spec_cmd]-} ]]; then
            cmd_order+=( "$spec_cmd" )
        fi
        cmd_file[$spec_cmd]=$file
    done

    command mkdir -p -- "$stage/zsh" "$stage/bash" "$stage/fish" "$stage/carapace" || return 1

    for cmd in "${cmd_order[@]}"; do
        file=${cmd_file[$cmd]}
        _ms_rc_parse "$file" || return 1
        _ms_rc_emit_zsh "$helper" > "$stage/zsh/_$cmd" || return 1
        _ms_rc_emit_bash "$helper" > "$stage/bash/$cmd.bash" || return 1
        _ms_rc_emit_fish "$helper" > "$stage/fish/$cmd.fish" || return 1
        _ms_rc_emit_carapace "$helper" > "$stage/carapace/$cmd.yaml" || return 1
        if (( ${+_ms_render_completion_files} )); then
            (( ${_ms_render_completion_files[(Ie)_$cmd]} )) || _ms_render_completion_files+=( "_$cmd" )
        fi
    done
    return 0
}
