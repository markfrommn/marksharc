# Shared Bash 4.4+ completion helpers for declarative .comp completions
# (COMPLETION-SPEC section 5.2). Preserves Readline unquoting, :@= reassembly
# support, and literal quoting without evaluating expansions.

# Remove Bash shell quoting and escapes from a word without evaluating expansions.
_ms_bash_comp_unquote() {
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

_ms_bash_comp_local_host() {
    case $1 in ''|local|localhost|"${MARKSHARC_HOST:-${HOSTNAME%%.*}}") return 0 ;; esac
    return 1
}

_ms_bash_comp_valid_host() {
    [[ $1 != -* && $1 != . && $1 != .. && $1 =~ ^[A-Za-z0-9._@:-]+$ ]]
}

_ms_bash_comp_choices() {
    local word=$1 item
    shift
    for item in "$@"; do
        [[ $item == "$word"* ]] && COMPREPLY+=("$item")
    done
}

_ms_bash_comp_dirs() {
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
        # shellcheck disable=SC2154 # Caller _ms_complete_* sets trim when Readline split :@=.
        if [[ $prefix && ! ${trim-} ]]; then
            # A quoted host:path is one replacement word, which Readline
            # cannot stat as a directory to add the trailing slash itself.
            candidate+=/
            compopt -o nospace 2>/dev/null || :
        fi
        COMPREPLY+=("$prefix$candidate")
    done < <(compgen -d -- "$path")
}

_ms_bash_comp_helper() {
    local word=$1 prefix=$2 line val helper
    shift 2
    helper=${MARKSHARC_HOME-}/core/cli/complete
    if [[ ! -r $helper && -n ${BASH_SOURCE[0]-} ]]; then
        helper=${BASH_SOURCE[0]%/*}/../cli/complete
    fi
    [[ -r $helper ]] || return 0
    local -a env_vars=("MARKSHARC_HOST=${MARKSHARC_HOST:-${HOSTNAME%%.*}}")
    [[ -n ${MARKSHARC_CONFIG-} ]] && env_vars+=("MARKSHARC_CONFIG=$MARKSHARC_CONFIG")
    while IFS= read -r line; do
        [[ -n $line ]] || continue
        val=${line%%$'\t'*}
        [[ $val == "$word"* ]] || continue
        COMPREPLY+=("$prefix$val")
        [[ $val == *: ]] && compopt -o nospace 2>/dev/null || :
    done < <(command env "${env_vars[@]}" zsh -f "$helper" "$@" 2>/dev/null)
}

_ms_bash_comp_launch_session_target() {
    local word=$1 trim=$2 host='' prefix=''
    if [[ $word == *:* && ( ${word#*:} == '' || ${word#*:} == /* || ${word#*:} == \~* ) ]] &&
       _ms_bash_comp_valid_host "${word%%:*}"; then
        host=${word%%:*}
        prefix=$host:
        word=${word#*:}
    fi
    if _ms_bash_comp_local_host "$host"; then
        _ms_bash_comp_dirs "$word" "$prefix"
    fi
    if [[ ! $host ]]; then
        _ms_bash_comp_helper "$word" '' launch-hosts --colon
    fi
}

_ms_bash_comp_launch_repo_target() {
    local word=$1 opt_host=$2 opt_base_only=$3 trim=$4 host='' rest
    if [[ $word == *:* ]] && _ms_bash_comp_valid_host "${word%%:*}"; then
        host=${word%%:*}
        rest=${word#*:}
        if _ms_bash_comp_local_host "$host" && [[ $rest == /* || $rest == \~* ]]; then
            _ms_bash_comp_dirs "$rest" "$host:"
            return 0
        fi
    elif _ms_bash_comp_local_host "$opt_host" && [[ $word == /* || $word == \~* ]]; then
        _ms_bash_comp_dirs "$word" ''
        return 0
    fi
    local -a _args=(launch-repo-target --current "$word")
    [[ -n $opt_host ]] && _args+=(--host "$opt_host")
    (( opt_base_only )) && _args+=(--base-only)
    _ms_bash_comp_helper "$word" '' "${_args[@]}"
}
