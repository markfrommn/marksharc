# -*- mode: shell-script; sh-shell: zsh -*-
# Cached tool init (spec 6.10).
#
#   _ms_init_cached [-k <extra-key>] [-P <PATH>] [-x <NAME>] <tool> <command...>
#
# Stores the output of <command...> (for example `starship init zsh`) under
# ${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/<host>/init/, keyed on the command's
# resolved binary path, its mtime, the arguments, the optional extra key and the
# -P value, then sources the file. -P runs the command under that PATH (`brew
# shellenv` prints nothing when the caller's PATH already starts with its
# directories). -x caches the output as the value of an exported variable NAME instead
# of as a script (`vivid generate` prints an LS_COLORS value). Empty output is never
# cached. A hit forks nothing. A missing tool returns 1 silently; a failing tool
# returns its status and caches nothing. If the cache cannot be written, the output
# is applied directly: it is the tool's own documented shell integration, the one
# place generated text is evaluated.

# No `emulate -L` here: it implies local options, which would discard the `setopt`
# calls a tool's init script makes (atuin sets interactive_comments, for example).
_ms_init_cached() {
    local extra= runpath= export_name=
    while [[ $1 == -[kPx] ]]; do
        case $1 in
            -k) extra=${2//$'\n'/ } ;;
            -P) runpath=$2 ;;
            -x) export_name=$2; [[ $export_name =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || return 2 ;;
        esac
        shift 2
    done
    local tool=$1
    shift
    (( $# )) || return 2
    local bin=$1 key name cachedir file tmp header out body cmdbin
    local -A st
    if [[ $bin != */* ]]; then
        bin=${commands[$1]-}
        if [[ -z $bin ]]; then rehash; bin=${commands[$1]-}; fi
    fi
    [[ -n $bin && -x $bin && ! -d $bin ]] || return 1
    cmdbin=$bin
    bin=${bin:A}
    zmodload -F zsh/stat b:zstat 2>/dev/null || return 1
    zstat -H st -- "$bin" 2>/dev/null || return 1
    key="$bin|${st[mtime]}|$extra|$runpath|${(j: :)@}${export_name:+|x:$export_name}"
    key=${key//$'\n'/ }
    name=${tool//[^A-Za-z0-9._-]/_}__${${(j:_:)@[2,-1]}//[^A-Za-z0-9._-]/_}${extra:+__k_${extra//[^A-Za-z0-9._-]/_}}${export_name:+__x_$export_name}
    cachedir=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}/init
    file=$cachedir/${name[1,120]}.zsh
    if [[ -r $file ]]; then
        IFS= read -r header < "$file"
        body=$(<"$file")
        # A header-only file (empty output cached by an older version) is a miss.
        if [[ $header == "# marksharc-init: $key" && $body == *$'\n'* ]]; then
            _ms_trace "init-cache hit: $tool"
            source "$file"
            return $?
        fi
    fi
    _ms_trace "init-cache miss: $tool"
    if [[ -n $runpath ]]; then
        out=$(PATH=$runpath "$cmdbin" "${@[2,-1]}" 2>/dev/null) || return $?
    else
        out=$("$@" 2>/dev/null) || return $?
    fi
    [[ -n ${out//[[:space:]]/} ]] || return 0
    [[ -n $export_name ]] && out="export $export_name=${(qq)out}"
    [[ -d $cachedir ]] || command mkdir -p -- "$cachedir" 2>/dev/null
    tmp=$file.$$
    if { print -r -- "# marksharc-init: $key"$'\n'"$out" > "$tmp" } 2>/dev/null && command mv -f -- "$tmp" "$file" 2>/dev/null; then
        source "$file"
        return $?
    fi
    command rm -f -- "$tmp" 2>/dev/null
    eval "$out"
}
