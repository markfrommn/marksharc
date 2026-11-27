#!/bin/zsh -f
# Shared offline dynamic completion candidate helper (COMPLETION-SPEC section 4).
# Invoked internally by rendered zsh, Bash, Fish, and Carapace completions.
# Strictly offline and read-only: never invokes ssh, hc, herdr, repo-list, or git fetch.
emulate -L zsh
setopt extendedglob

MARKSHARC_HOME=${${(%):-%x}:A:h:h:h}
export MARKSHARC_HOME

case $OSTYPE in
    darwin*) MARKSHARC_OS=darwin ;;
    linux*)  MARKSHARC_OS=linux ;;
    *)       MARKSHARC_OS=${${OSTYPE%%[0-9.-]*}:l} ;;
esac
MARKSHARC_HOST=${MARKSHARC_HOST:-${HOST%%.*}}

typeset config=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}
typeset cache=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/$MARKSHARC_HOST

_ms_trace() { :; }

source "$MARKSHARC_HOME/core/cli/hosts-lib.zsh" || exit 1

_complete_valid_host() {
    local name=$1
    [[ -n $name && $name != . && $name != .. && $name != */* ]] && _ms_hosts_valid_name "$name"
}

_complete_resolve_host() {
    local host=${1-}
    case $host in
        ''|local|localhost|"$MARKSHARC_HOST")
            REPLY=local
            return 0
            ;;
    esac
    _complete_valid_host "$host" || { REPLY=; return 1; }
    REPLY=$host
    return 0
}

_complete_emit() {
    local val=${1//[[:cntrl:]]/}
    local desc=${2-}
    desc=${desc//[[:cntrl:]]/}
    [[ -n $val ]] || return 0
    if [[ -n $desc ]]; then
        print -r -- "$val"$'\t'"$desc"
    else
        print -r -- "$val"
    fi
}

_complete_cmd_modules() {
    typeset -g _ms_discover_all=1
    _ms_modules_discover
    local name
    for name in ${(o)_ms_mod_names}; do
        _complete_emit "$name" "${_ms_mod_describe[$name]-}"
    done
}

_complete_cmd_hosts() {
    _ms_hosts_read 2>/dev/null || return 0
    local h t
    for h in "${_ms_host_names[@]}"; do
        _complete_valid_host "$h" || continue
        t=${_ms_host_targets[$h]-}
        if [[ -n $t && $t != "$h" ]]; then
            _complete_emit "$h" "$t"
        else
            _complete_emit "$h"
        fi
    done
}

_complete_cmd_installers() {
    local -a names=()
    local -A seen=()
    local _day2_allow_missing=1
    source "$MARKSHARC_HOME/core/cli/day2-lib.zsh" || return 0
    _day2_directive() {
        [[ $1 == installer && $# == 3 && -n $2 ]] || return 0
        if [[ -z ${seen[$2]-} ]]; then
            seen[$2]=1
            names+=( "$2" )
        fi
        return 0
    }
    _day2_collect 2>/dev/null || true
    local name
    for name in "${names[@]}"; do
        _complete_emit "$name"
    done
}

_complete_cmd_update_steps() {
    local -a names=( sync pins system render )
    local -A seen=( sync 1 pins 1 system 1 render 1 )
    local _day2_allow_missing=0
    source "$MARKSHARC_HOME/core/cli/day2-lib.zsh" || return 0
    _day2_directive() {
        [[ $1 == update && $# -ge 3 && -n $2 ]] || return 0
        if [[ -z ${seen[$2]-} ]]; then
            seen[$2]=1
            names+=( "$2" )
        fi
        return 0
    }
    _day2_collect 2>/dev/null || true
    local name
    for name in "${names[@]}"; do
        _complete_emit "$name"
    done
}

_complete_cmd_launch_hosts() {
    local colon=$1 prefix_filter=${2-}
    local -A seen=()
    local h t out
    local -a builtins=( local localhost remote )
    [[ -n $MARKSHARC_HOST ]] && builtins+=( "$MARKSHARC_HOST" )
    for h in "${builtins[@]}"; do
        _complete_valid_host "$h" || continue
        [[ -z ${seen[$h]-} ]] || continue
        seen[$h]=1
        if (( colon )); then
            [[ $h != *:* ]] || continue
            out="$h:"
        else
            out=$h
        fi
        [[ -z $prefix_filter || $out == "$prefix_filter"* ]] || continue
        _complete_emit "$out"
    done
    _ms_hosts_read 2>/dev/null || return 0
    for h in "${_ms_host_names[@]}"; do
        _complete_valid_host "$h" || continue
        [[ -z ${seen[$h]-} ]] || continue
        seen[$h]=1
        if (( colon )); then
            [[ $h != *:* ]] || continue
            out="$h:"
        else
            out=$h
        fi
        [[ -z $prefix_filter || $out == "$prefix_filter"* ]] || continue
        t=${_ms_host_targets[$h]-}
        if [[ -n $t && $t != "$h" ]]; then
            _complete_emit "$out" "$t"
        else
            _complete_emit "$out"
        fi
    done
}

_complete_emit_repos() {
    local host=$1 prefix=$2 base_only=$3
    local REPLY=
    _complete_resolve_host "$host" || return 0
    local file="$cache/repos/$REPLY.tsv"
    [[ -r $file ]] || return 0
    local line name rpath kind base branch base_name cand
    local -a fields=()
    local -A seen=()
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -n $line ]] || continue
        fields=( "${(@ps:\t:)line}" )
        name=${fields[1]-}
        rpath=${fields[2]-}
        kind=${fields[3]-}
        base=${fields[4]-}
        branch=${fields[5]-}
        [[ -n $name ]] || continue
        if [[ $kind == base ]]; then
            cand="${prefix}${name}"
            if [[ -z ${seen[$cand]-} ]]; then
                seen[$cand]=1
                _complete_emit "$cand"
            fi
        elif [[ $kind == worktree && $base_only != 1 ]]; then
            base_name=${base:t}
            [[ -n $base_name ]] || continue
            cand="${prefix}${base_name}/${name}"
            if [[ -z ${seen[$cand]-} ]]; then
                seen[$cand]=1
                _complete_emit "$cand"
            fi
            if [[ -n $branch && $branch != "$name" ]]; then
                cand="${prefix}${base_name}/${branch}"
                if [[ -z ${seen[$cand]-} ]]; then
                    seen[$cand]=1
                    _complete_emit "$cand"
                fi
            fi
        fi
    done < "$file"
}

_complete_cmd_base_repos() {
    local host=$1
    _complete_emit_repos "$host" '' 1
}

_complete_cmd_worktrees() {
    local host=$1 repo=$2
    local REPLY=
    _complete_resolve_host "$host" || return 0
    local file="$cache/repos/$REPLY.tsv"
    [[ -r $file ]] || return 0
    local line name rpath kind base branch base_name
    local -a fields=()
    local -A seen=()
    while IFS= read -r line || [[ -n $line ]]; do
        [[ -n $line ]] || continue
        fields=( "${(@ps:\t:)line}" )
        name=${fields[1]-}
        rpath=${fields[2]-}
        kind=${fields[3]-}
        base=${fields[4]-}
        branch=${fields[5]-}
        [[ $kind == worktree && -n $name ]] || continue
        base_name=${base:t}
        if [[ -n $repo && $base_name != "$repo" ]]; then
            continue
        fi
        if [[ -z ${seen[$name]-} ]]; then
            seen[$name]=1
            _complete_emit "$name"
        fi
        if [[ -n $branch && $branch != "$name" && -z ${seen[$branch]-} ]]; then
            seen[$branch]=1
            _complete_emit "$branch"
        fi
    done < "$file"
}

_complete_cmd_launch_repo_target() {
    local host=$1 base_only=$2 current=$3
    if [[ $current == *:* ]]; then
        local target_host=${current%%:*}
        _complete_valid_host "$target_host" || return 0
        _complete_emit_repos "$target_host" "${target_host}:" "$base_only"
        return 0
    fi
    local -a repo_lines=()
    local line
    repo_lines=( "${(@f)$(_complete_emit_repos "$host" '' "$base_only")}" )
    integer matched_repos=0
    for line in "${repo_lines[@]}"; do
        [[ -n $line ]] || continue
        print -r -- "$line"
        if [[ -z $current || $line == "$current"* ]]; then
            (( ++matched_repos ))
        fi
    done
    if [[ -z $host ]]; then
        if (( matched_repos == 0 )); then
            _complete_cmd_launch_hosts 1 "$current"
        elif [[ -n $current ]]; then
            _complete_cmd_launch_hosts 1 "$current"
        fi
    fi
}

_complete_cmd_git_branches() {
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        _complete_emit "$line"
    done < <(command git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null)
}

(( $# >= 1 )) || { print -ru2 -- 'Usage: complete <kind> [options]'; exit 2; }
typeset kind=$1
shift

typeset opt_host= opt_repo= opt_prefix= opt_current=
integer opt_colon=0 opt_base_only=0 opt_from_carapace=0
integer has_host=0 has_repo=0 has_base_only=0 has_current=0

while (( $# )); do
    case $1 in
        --host)
            (( $# >= 2 )) || { print -ru2 -- 'complete: --host requires a value'; exit 2; }
            opt_host=$2; has_host=1; shift 2 ;;
        --repo)
            (( $# >= 2 )) || { print -ru2 -- 'complete: --repo requires a value'; exit 2; }
            opt_repo=$2; has_repo=1; shift 2 ;;
        --prefix)
            (( $# >= 2 )) || { print -ru2 -- 'complete: --prefix requires a value'; exit 2; }
            opt_prefix=$2; shift 2 ;;
        --current)
            (( $# >= 2 )) || { print -ru2 -- 'complete: --current requires a value'; exit 2; }
            opt_current=$2; has_current=1; shift 2 ;;
        --colon)
            opt_colon=1; shift ;;
        --base-only)
            opt_base_only=1; has_base_only=1; shift ;;
        --from-carapace)
            opt_from_carapace=1; shift ;;
        *)
            print -ru2 -- "complete: unknown option: $1"
            exit 2 ;;
    esac
done

if (( opt_from_carapace )); then
    (( has_host )) || opt_host=${C_FLAG_HOST-}
    (( has_repo )) || opt_repo=${C_FLAG_REPO-}
    if (( ! has_base_only )) && [[ ${C_FLAG_BASE_ONLY-} == (true|1) ]]; then
        opt_base_only=1
    fi
    (( has_current )) || opt_current=${C_VALUE-}
fi

case $kind in
    modules)            _complete_cmd_modules ;;
    hosts)              _complete_cmd_hosts ;;
    installers)         _complete_cmd_installers ;;
    update-steps)       _complete_cmd_update_steps ;;
    launch-hosts)       _complete_cmd_launch_hosts "$opt_colon" ;;
    repos)              _complete_emit_repos "$opt_host" "$opt_prefix" "$opt_base_only" ;;
    base-repos)         _complete_cmd_base_repos "$opt_host" ;;
    worktrees)          _complete_cmd_worktrees "$opt_host" "$opt_repo" ;;
    launch-repo-target) _complete_cmd_launch_repo_target "$opt_host" "$opt_base_only" "$opt_current" ;;
    git-branches)       _complete_cmd_git_branches ;;
    *)
        print -ru2 -- "complete: unknown kind: $kind"
        exit 2 ;;
esac
exit 0
