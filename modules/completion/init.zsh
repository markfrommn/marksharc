# completion module, init phase (spec 6.9): a full compinit whose dump and fpath
# fingerprint live in the per-host XDG cache (the dump is rebuilt when fpath changes),
# then the zstyles. Sourced at top level, so typeset is used and a reload skips compinit.
# -i keeps the compaudit security check (never -C or -u) but excludes an insecure
# directory silently: startup is non-interactive by contract (spec 6.6/6.10), so a
# prompt would hang PTY sessions and a world-writable distro site-functions directory
# (seen on ubuntu-latest CI) must not be trusted.
autoload -Uz compinit
if (( ! ${_ms_reloading:-0} )); then
    typeset -g _ms_cache="${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}"
    typeset -g _ms_dump="$_ms_cache/zcompdump"
    typeset -g _ms_fpath="$_ms_dump.fpath"
    typeset -g _ms_fpath_value="${(j.:.)fpath}"
    mkdir -p "$_ms_cache"
    if [[ ! -f $_ms_dump || ! -r $_ms_fpath || "$(<"$_ms_fpath")" != "$_ms_fpath_value" ]]; then
        rm -f -- "$_ms_dump"
        print -r -- "$_ms_fpath_value" >"$_ms_fpath"
    fi
    compinit -i -d "$_ms_dump"
    unset _ms_cache _ms_dump _ms_fpath _ms_fpath_value
fi

# Enable completion cache
zstyle ':completion::complete:*' use-cache on
zstyle ':completion::complete:*' cache-path ~/.cache/zsh-completions/$HOST

# Disable annoying . file autocompletion
zstyle ':completion:*' ignored-patterns '(|*/).*'

# Re-enable for specific file commands
zstyle ':completion:*:*:vi:*' ignored-patterns
zstyle ':completion:*:*:vim:*' ignored-patterns
zstyle ':completion:*:*:emacs:*' ignored-patterns
zstyle ':completion:*:*:cat:*' ignored-patterns
zstyle ':completion:*:*:bat:*' ignored-patterns
zstyle ':completion:*:*:glow:*' ignored-patterns
zstyle ':completion:*:*:ls:*' ignored-patterns
zstyle ':completion:*:*:rm:*' ignored-patterns
zstyle ':completion:*:*:cp:*' ignored-patterns
zstyle ':completion:*:*:mv:*' ignored-patterns

zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-prompt '%SAt %p: Hit TAB for more, or the character to insert%s'
zstyle ':completion:*' menu select=1 _complete _ignored _approximate
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'

# list of completers to use
zstyle ':completion:*::::' completer _expand _complete _ignored _approximate

# allow one error for every three characters typed in approximate completer
zstyle -e ':completion:*:approximate:*' max-errors \
        'reply=( $(( ($#PREFIX+$#SUFFIX)/2 )) numeric )'

# insert all expansions for expand completer
zstyle ':completion:*:expand:*' tag-order all-expansions

# formatting and messages
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:messages' format '%d'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*:corrections' format '%B%d (errors: %e)%b'
zstyle ':completion:*' group-name ''

# match uppercase from lowercase
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'

# offer indexes before parameters in subscripts
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

## add colors to processes for kill completion
zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:*:kill:*:processes' command 'ps --forest -A -o pid,user,cmd'
zstyle ':completion:*:processes-names' command 'ps axho command'

# Host completion from /etc/hosts, read with builtins: the host names (fields 2-5 of
# active lines, minus the ip6- entries) and the names after "#%" in comment lines.
typeset -ga _ms_hosts=()
typeset -g _ms_hline
typeset -ga _ms_hwords
if [[ -r /etc/hosts ]]; then
    while IFS= read -r _ms_hline || [[ -n $_ms_hline ]]; do
        if [[ $_ms_hline == '#%'* ]]; then
            _ms_hosts+=( ${_ms_hline#'#%'} )
        elif [[ $_ms_hline != '#'* && $_ms_hline != *ip6-* ]]; then
            _ms_hwords=( ${=_ms_hline} )
            _ms_hosts+=( ${_ms_hwords[2,5]} )
        fi
    done < /etc/hosts
fi
zstyle ':completion:*' hosts ${_ms_hosts}
unset _ms_hosts _ms_hline _ms_hwords

# Filename suffixes to ignore during completion (except after rm command)
zstyle ':completion:*:*:(^rm):*:*files' ignored-patterns '*?.o' '*?.c~' \
        '*?.old' '*?.pro' '.*'

# ignore completion functions (until the _ignored completer)
zstyle ':completion:*:functions' ignored-patterns '_*'
zstyle ':completion:*:*:*:users' ignored-patterns \
        adm apache bin daemon games gdm halt ident junkbust lp mail mailnull \
        named news nfsnobody nobody nscd ntp operator pcap postgres radvd \
        rpc rpcuser rpm shutdown squid sshd sync uucp vcsa xfs avahi-autoipd\
        avahi backup messagebus beagleindex debian-tor dhcp dnsmasq fetchmail\
        firebird gnats haldaemon hplip irc klog list man cupsys postfix\
        proxy syslog www-data mldonkey sys snort

# SSH Completion
zstyle ':completion:*:scp:*' tag-order \
        files users 'hosts:-host hosts:-domain:domain hosts:-ipaddr"IP\ Address *'
zstyle ':completion:*:scp:*' group-order \
        files all-files users hosts-domain hosts-host hosts-ipaddr
zstyle ':completion:*:ssh:*' tag-order \
        users 'hosts:-host hosts:-domain:domain hosts:-ipaddr"IP\ Address *'
zstyle ':completion:*:ssh:*' group-order \
        hosts-domain hosts-host users hosts-ipaddr
zstyle '*' single-ignored show

# Ensure zsh does not fall back to showing ignored patterns
zstyle ':completion:*' completer _complete

# Clear inherited module-owned Carapace exports when a fresh shell switches away
# from completion-carapace (including when the module itself is turned off).
if (( ! ${_ms_reloading:-0} )) && [[ -n ${MARKSHARC_CARAPACE_ACTIVE-} ]] && (( $+functions[_ms_completion_carapace_active] )) && ! _ms_completion_carapace_active; then
    unset CARAPACE_BRIDGES CARAPACE_EXCLUDES MARKSHARC_CARAPACE_ACTIVE
fi
true
