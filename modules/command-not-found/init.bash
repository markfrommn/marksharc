command_not_found_handle() {
    local candidate
    for candidate in /usr/lib/command-not-found /usr/share/command-not-found/command-not-found; do
        if [[ -x $candidate ]]; then "$candidate" -- "$1"; return $?; fi
    done
    printf 'bash: command not found: %s\n' "$1" >&2
    return 127
}
_ms_cnf_brew=$(type -P brew) || _ms_cnf_brew=
if [[ -n $_ms_cnf_brew ]]; then
    _ms_cnf_dir=$(cd -P -- "${_ms_cnf_brew%/*}/.." 2>/dev/null && pwd -P)
    _ms_cnf_handler=$_ms_cnf_dir/Library/Homebrew/command-not-found/handler.sh
    if [[ -r $_ms_cnf_handler ]]; then
        # shellcheck disable=SC1090
        source "$_ms_cnf_handler"
        # Homebrew's shared handler uses zsh's spelling.
        if declare -F command_not_found_handler >/dev/null; then
            command_not_found_handle() { command_not_found_handler "$@"; }
        fi
    fi
fi
unset _ms_cnf_brew _ms_cnf_dir _ms_cnf_handler
:
