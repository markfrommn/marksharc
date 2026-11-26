# Bash supplies the spelling of the word, including quoting and escapes.
# Remove the quoting without evaluating expansions on the pending line.
_ms_workflow_unquote() {
    local text=$1 quote='' char next i double_escapes='"\\$`'
    REPLY=''
    for ((i=0; i<${#text}; i++)); do
        char=${text:i:1}
        next=${text:i+1:1}
        case $char in
            "$quote") quote='' ;;
            \'|'"')
                if [[ $quote ]]; then REPLY+=$char; else quote=$char; fi
                ;;
            \\)
                if [[ $next && ( ! $quote || ( $quote == '"' && $double_escapes == *"$next"* ) ) ]]; then
                    REPLY+=$next
                    ((i+=1))
                else
                    REPLY+=$char
                fi
                ;;
            *) REPLY+=$char ;;
        esac
    done
}

_ms_workflow_host_name() {
    [[ $1 != -* && $1 != . && $1 != .. && $1 =~ ^[A-Za-z0-9._@:-]+$ ]]
}

_ms_workflow_local_host() {
    case $1 in ''|local|localhost|"${MARKSHARC_HOST:-${HOSTNAME%%.*}}") return 0 ;; esac
    return 1
}

_ms_workflow_hosts() {
    local word=$1 suffix=$2 name rest
    local -A seen=()
    while IFS=$'\t' read -r name rest; do
        _ms_workflow_host_name "$name" || continue
        [[ -z $suffix || $name != *:* ]] || continue
        [[ $name == "$word"* && ! ${seen[$name]+yes} ]] || continue
        COMPREPLY+=("$name$suffix")
        seen[$name]=1
    done < <(
        printf '%s\n' local localhost remote "${MARKSHARC_HOST:-${HOSTNAME%%.*}}"
        "$MARKSHARC_HOME/bin/marksharc" hosts list 2>/dev/null
    )
}

_ms_workflow_directories() {
    local word=$1 prefix=$2 path candidate
    case $word in
        \~) path=$HOME/ ;;
        \~/*) path=$HOME/${word#\~/} ;;
        *) path=$word ;;
    esac
    while IFS= read -r candidate; do
        if [[ $word == \~ || $word == \~/* ]]; then
            candidate=\~/${candidate#"$HOME"/}
        fi
        if [[ $prefix && ! $trim ]]; then
            # A quoted host:path is one replacement word, which Readline
            # cannot stat as a directory to add the trailing slash itself.
            candidate+=/
            compopt -o nospace 2>/dev/null || :
        fi
        COMPREPLY+=("$prefix$candidate")
    done < <(compgen -d -- "$path")
}

# Read the stored inventory only. Never refresh it or contact a remote on Tab.
_ms_workflow_repos() {
    local host=$1 selection=$2 repo=$3 word=$4 prefix=$5
    local cache name path kind base branch candidate
    local -a candidates
    if _ms_workflow_local_host "$host"; then host=local; fi
    _ms_workflow_host_name "$host" || return 0
    cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOSTNAME%%.*}}/repos/$host.tsv
    [[ -r $cache ]] || return 0
    while IFS=$'\t' read -r name path kind base branch; do
        case $selection:$kind in
            base:base|target:base) candidates=("$name") ;;
            target:worktree)
                candidates=("${base##*/}/$name")
                [[ ! $branch || $branch == "$name" ]] || candidates+=("${base##*/}/$branch")
                ;;
            worktree:worktree)
                [[ ${base##*/} == "$repo" ]] || continue
                candidates=("$name")
                [[ ! $branch || $branch == "$name" ]] || candidates+=("$branch")
                ;;
            *) continue ;;
        esac
        for candidate in "${candidates[@]}"; do
            [[ $candidate != "$word"* ]] || COMPREPLY+=("$prefix$candidate")
        done
    done < "$cache"
}

# Reassemble host qualifiers, host aliases and NAME=VALUE options split by
# Readline's default word breaks. Readline replaces only the final fragment.
_ms_workflow_complete() {
    local tool=${1##*/} index current=${COMP_CWORD:-1} word token trim='' REPLY
    local -a arguments=()
    word=${COMP_WORDS[current]-$2}
    if [[ $word == [:@=] ]]; then word=''; ((current+=1)); fi
    while (( current > 2 )) && [[ ${COMP_WORDS[current-1]} == [:@=] ]]; do
        trim=${COMP_WORDS[current-2]}${COMP_WORDS[current-1]}$trim
        ((current-=2))
    done
    _ms_workflow_unquote "$trim$word"
    word=$REPLY
    _ms_workflow_unquote "$trim"
    trim=$REPLY
    for ((index=1; index<current; index++)); do
        token=${COMP_WORDS[index]}
        while (( index+2 < current )) && [[ ${COMP_WORDS[index+1]} == [:@=] ]]; do
            token+=${COMP_WORDS[index+1]}${COMP_WORDS[index+2]}
            ((index+=2))
        done
        _ms_workflow_unquote "$token"
        arguments+=("$REPLY")
    done

    COMPREPLY=()
    _ms_workflow_candidates "$tool" "$word" "${arguments[@]}"
    if [[ $trim ]]; then
        for index in "${!COMPREPLY[@]}"; do COMPREPLY[index]=${COMPREPLY[index]#"$trim"}; done
    fi
}

_ms_workflow_candidates() {
    local tool=$1 word=$2 option='' host='' repo='' token prefix='' selection=target
    local commands=0 positions=0 base_only=0 flag_form=0 literal_args=0
    local valued='--host --mux --mux-id --place' switches
    shift 2
    case $tool in
        launch-session)
            valued+=' --pwd --command --name --env'
            switches='--in-shell --no-focus --dry-run --quiet --help -h'
            ;;
        launch-repo)
            valued+=' --repo --worktree --command --name --env'
            switches='--in-shell --no-focus --dry-run --quiet --rescan --base-only --help -h'
            ;;
        cwf-new)
            valued+=' --repo'
            switches='--launch --pick'
            ;;
    esac

    for token; do
        if [[ $option ]]; then
            case $option in
                --host) host=$token; flag_form=1 ;;
                --repo) repo=$token; flag_form=1 ;;
                --worktree|--pwd) flag_form=1 ;;
                --command) commands=1; flag_form=1 ;;
            esac
            option=''
        elif (( literal_args )); then
            ((positions+=1))
        else
            case $token in
                --) literal_args=1; positions=1 ;;
                --base-only) base_only=1 ;;
                -*)
                    if [[ " $valued " == *" $token "* ]]; then option=$token; fi
                    ;;
                *) ((positions+=1)) ;;
            esac
        fi
    done

    case $option in
        --host) _ms_workflow_hosts "$word" ''; return 0 ;;
        --repo) selection=base ;;
        --worktree) _ms_workflow_repos "$host" worktree "$repo" "$word" ''; return 0 ;;
        --pwd)
            if _ms_workflow_local_host "$host"; then _ms_workflow_directories "$word" ''; fi
            return 0
            ;;
        --mux) mapfile -t COMPREPLY < <(compgen -W 'hc herdr herdr-core tmux' -- "$word"); return 0 ;;
        --place) mapfile -t COMPREPLY < <(compgen -W 'workspace tab hidden' -- "$word"); return 0 ;;
        --command) mapfile -t COMPREPLY < <(compgen -c -- "$word"); return 0 ;;
        --mux-id|--name|--env) return 0 ;;
    esac
    if [[ $selection == base ]]; then
        if _ms_workflow_local_host "$host" && [[ $word == /* || $word == '~'* ]]; then
            _ms_workflow_directories "$word" ''
        else
            _ms_workflow_repos "$host" base '' "$word" ''
        fi
        return 0
    fi
    if [[ $word == -* && $commands == 0 && $positions == 0 ]]; then
        mapfile -t COMPREPLY < <(compgen -W "$valued $switches" -- "$word")
        return 0
    fi
    if [[ $tool == cwf-new ]]; then
        if (( ! positions )); then
            while IFS= read -r token; do
                [[ $token != "$word"* ]] || COMPREPLY+=("$token")
            done < <(command git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
        fi
        return 0
    fi
    if (( commands || positions > 1 )); then
        compopt -o default 2>/dev/null || :
        return 0
    elif (( positions == 1 )); then
        mapfile -t COMPREPLY < <(compgen -c -- "$word")
        return 0
    elif (( flag_form )); then
        return 0
    fi

    if [[ $word == *:* && ( $tool == launch-repo || ${word#*:} == '' ||
                            ${word#*:} == /* || ${word#*:} == \~* ) ]] &&
       _ms_workflow_host_name "${word%%:*}"; then
        host=${word%%:*}
        prefix=$host:
        word=${word#*:}
    fi
    if [[ $tool == launch-session ]]; then
        if _ms_workflow_local_host "$host"; then _ms_workflow_directories "$word" "$prefix"; fi
        if [[ ! $host ]]; then
            _ms_workflow_hosts "$word" :
            compopt -o nospace 2>/dev/null || :
        fi
    elif _ms_workflow_local_host "$host" && [[ $word == /* || $word == '~'* ]]; then
        _ms_workflow_directories "$word" "$prefix"
    else
        (( ! base_only )) || selection=base
        _ms_workflow_repos "$host" "$selection" '' "$word" "$prefix"
        if [[ ! $host && $word && ${#COMPREPLY[@]} == 0 ]]; then
            _ms_workflow_hosts "$word" :
            compopt -o nospace 2>/dev/null || :
        fi
    fi
}
