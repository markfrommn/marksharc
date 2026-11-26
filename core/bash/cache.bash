# Source a tool's Bash integration, caching its successful, nonempty output.
# _ms_bash_init_cached [-k context] tool executable [arguments ...]
# The context includes settings or backend choices that affect generated code.
_ms_bash_init_cached() {
    local _ms_cache_extra='' _ms_cache_tool _ms_cache_executable _ms_cache_resolved
    local _ms_cache_dirname _ms_cache_link _ms_cache_count=0 _ms_cache_mtime
    local _ms_cache_key _ms_cache_checksum _ms_cache_name _ms_cache_dir
    local _ms_cache_file _ms_cache_header _ms_cache_body _ms_cache_output _ms_cache_tmp
    if [[ ${1-} == -k ]]; then
        (( $# >= 2 )) || return 2
        _ms_cache_extra=$2
        shift 2
    fi
    (( $# >= 2 )) || return 2
    _ms_cache_tool=$1
    shift
    _ms_cache_executable=$1
    if [[ $_ms_cache_executable != */* ]]; then
        _ms_cache_executable=$(type -P -- "$_ms_cache_executable") || return 1
    fi
    [[ -x $_ms_cache_executable && ! -d $_ms_cache_executable ]] || return 1
    [[ $_ms_cache_executable == /* ]] || _ms_cache_executable=$PWD/$_ms_cache_executable

    # Resolve links so replacing a symlink with another executable invalidates the entry.
    _ms_cache_resolved=$_ms_cache_executable
    while [[ -L $_ms_cache_resolved ]]; do
        (( _ms_cache_count += 1 ))
        (( _ms_cache_count <= 40 )) || return 1
        _ms_cache_link=$(command readlink "$_ms_cache_resolved") || return 1
        if [[ $_ms_cache_link == /* ]]; then
            _ms_cache_resolved=$_ms_cache_link
        else
            _ms_cache_resolved=${_ms_cache_resolved%/*}/$_ms_cache_link
        fi
    done
    _ms_cache_dirname=${_ms_cache_resolved%/*}
    [[ $_ms_cache_dirname != "$_ms_cache_resolved" ]] || _ms_cache_dirname=.
    _ms_cache_dirname=$(cd -P -- "$_ms_cache_dirname" && pwd -P) || return 1
    _ms_cache_resolved=$_ms_cache_dirname/${_ms_cache_resolved##*/}
    _ms_cache_mtime=$(command stat -c %Y -- "$_ms_cache_resolved" 2>/dev/null) ||
        _ms_cache_mtime=$(command stat -f %m "$_ms_cache_resolved" 2>/dev/null) || return 1

    # Bash's %q gives each argument an unambiguous single-line representation.
    printf -v _ms_cache_key '%q ' "$_ms_cache_resolved" "$_ms_cache_mtime" "$_ms_cache_extra" "$@"
    _ms_cache_checksum=$(printf '%s' "$_ms_cache_key" | command cksum) || return 1
    _ms_cache_checksum=${_ms_cache_checksum// /_}
    _ms_cache_name=${_ms_cache_tool//[^a-zA-Z0-9._-]/_}
    _ms_cache_dir=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOSTNAME%%.*}}/init-bash
    _ms_cache_file=$_ms_cache_dir/${_ms_cache_name:0:80}_$_ms_cache_checksum.bash
    if [[ -r $_ms_cache_file ]]; then
        IFS= read -r _ms_cache_header < "$_ms_cache_file"
        _ms_cache_body=$(<"$_ms_cache_file")
        if [[ $_ms_cache_header == "# marksharc-bash-init: $_ms_cache_key" &&
              $_ms_cache_body == *$'\n'* && -n ${_ms_cache_body#*$'\n'} ]]; then
            # The file contains only the selected tool's previously generated code.
            # shellcheck disable=SC1090
            source "$_ms_cache_file"
            return $?
        fi
    fi

    _ms_cache_output=$("$_ms_cache_executable" "${@:2}" 2>/dev/null) || return $?
    [[ -n ${_ms_cache_output//[[:space:]]/} ]] || return 0
    if { command mkdir -p -- "$_ms_cache_dir" &&
         _ms_cache_tmp=$(command mktemp "$_ms_cache_dir/.init.XXXXXXXX") &&
         printf '# marksharc-bash-init: %s\n%s\n' "$_ms_cache_key" "$_ms_cache_output" > "$_ms_cache_tmp" &&
         command mv -f -- "$_ms_cache_tmp" "$_ms_cache_file"; } 2>/dev/null; then
        # shellcheck disable=SC1090
        source "$_ms_cache_file"
        return $?
    fi
    [[ -z ${_ms_cache_tmp-} ]] || command rm -f -- "$_ms_cache_tmp" 2>/dev/null
    # This is the tool's own documented shell integration.
    eval "$_ms_cache_output"
}
