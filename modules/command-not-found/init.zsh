# command-not-found module, init phase: Homebrew and apt providers, with zsh's 127 fallback.

typeset -ga command_not_found_apt_candidates=(
    /usr/lib/command-not-found
    /usr/share/command-not-found/command-not-found
)

command_not_found_handler() {
    emulate -L zsh
    local candidate
    for candidate in "${command_not_found_apt_candidates[@]}"; do
        if [[ -x $candidate ]]; then
            "$candidate" -- "$1"
            return $?
        fi
    done
    printf 'zsh: command not found: %s\n' "$1" >&2
    return 127
}

if (( ${+commands[brew]} )); then
    typeset -g _ms_cnf_homebrew="${commands[brew]:A:h:h}/Library/Homebrew/command-not-found/handler.sh"
    if [[ -r $_ms_cnf_homebrew ]]; then
        source "$_ms_cnf_homebrew"
        unset _ms_cnf_homebrew
        return 0
    fi
    unset _ms_cnf_homebrew
fi
