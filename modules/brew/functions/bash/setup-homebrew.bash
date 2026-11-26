function setup-homebrew {
    local brew result=0 saved=$PATH new entry rest added='' var before
    local -a brew_vars=(HOMEBREW_PREFIX HOMEBREW_CELLAR HOMEBREW_REPOSITORY MANPATH INFOPATH)
    local -a brew_before=()
    (( $# )) || set -- /usr/local/bin/brew /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
    for brew in "$@"; do
        if [[ -x $brew && ! -d $brew ]]; then
            for var in "${brew_vars[@]}"; do brew_before+=("$(_ms_bash_effect variable "$var")"); done
            PATH=/usr/bin:/bin:/usr/sbin:/sbin
            _ms_bash_init_cached brew "$brew" shellenv bash || result=$?
            new=$PATH
            rest=$new:
            while [[ -n $rest ]]; do
                entry=${rest%%:*}; rest=${rest#*:}
                [[ -n $entry && :$saved: != *:"$entry":* && :$added: != *:"$entry":* ]] || continue
                added+=${added:+:}$entry
                _ms_bash_owned_path+=("$entry")
            done
            PATH=${added:+$added:}$saved
            export PATH
            for var in "${!brew_vars[@]}"; do
                before=${brew_before[var]}
                _ms_bash_record_effect variable "${brew_vars[var]}" "$before" "$(_ms_bash_effect variable "${brew_vars[var]}")"
            done
            return "$result"
        fi
    done
    return 0
}
