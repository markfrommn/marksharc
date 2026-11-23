# -*- mode: shell-script; sh-shell: zsh -*-
#
# path module (spec 6.7): the tier API and the PATH builder. Modules contribute
# directories to named tiers during the env phase; the finalizer registered below
# builds PATH once every module has run. Sourced at top level by core/zshenv.zsh and
# safe to source twice (it resets the tier contents; the builder keeps what it did
# not generate).
#
# Tiers, in the default order: first, (inherited before a managed entry), manager,
# brew, local, system, user, app, (inherited after), last. macOS keeps local before
# system; Linux puts local after app, which is what the old build_path produced.
# A tiers option lists the order; tiers it omits follow in the default order.
# manager holds version-manager directories (gvm, nvm, pyenv), so they come ahead of
# Homebrew in every session class.
#
# _ms_fs_root is the test seam for directory probes: absolute system paths are
# probed under that prefix, paths below $HOME as they are.

typeset -ga _ms_path_tier_names=( first manager brew local system user app last )
typeset -ga _ms_path_tier_first _ms_path_tier_manager _ms_path_tier_brew _ms_path_tier_local
typeset -ga _ms_path_tier_system _ms_path_tier_user _ms_path_tier_app _ms_path_tier_last
typeset -ga _ms_managed_path
_ms_path_tier_first=(); _ms_path_tier_manager=(); _ms_path_tier_brew=(); _ms_path_tier_local=()
_ms_path_tier_system=(); _ms_path_tier_user=(); _ms_path_tier_app=(); _ms_path_tier_last=()

# REPLY = the path as it must be probed (seam prefix for absolute system paths).
_ms_fs_path() {
    if [[ -n ${_ms_fs_root-} && $1 != "$HOME" && $1 != "$HOME"/* ]]; then REPLY=${_ms_fs_root}$1; else REPLY=$1; fi
}

_ms_isdir() {
    [[ -n $1 ]] || return 1
    local REPLY
    _ms_fs_path "$1"
    [[ -d $REPLY ]]
}

# _ms_path_add [-f] <tier> <dir>... : append directories to a tier. Missing directories
# are skipped unless -f; duplicates are dropped. A no-op in a child that inherited a
# matching PATH (_ms_env_rebuild is 0).
_ms_path_add() {
    emulate -L zsh
    (( ${_ms_env_rebuild:-1} )) || return 0
    local force=0 tier var dir
    if [[ $1 == -f ]]; then force=1; shift; fi
    tier=$1; shift
    var=_ms_path_tier_${tier//[^A-Za-z0-9]/_}
    typeset -ga "$var"
    local -a cur=( "${(@P)var}" )
    for dir in "$@"; do
        [[ -n $dir ]] || continue
        (( force )) || _ms_isdir "$dir" || continue
        (( ${cur[(Ie)$dir]} )) && continue
        cur+=( "$dir" )
    done
    set -A "$var" "${cur[@]}"
    return 0
}

# _ms_path_add_bindirs <tier> <base>... : the standard command subdirectories under
# each existing base directory (bin, sbin, script, scripts, batch and the
# bin/bin.<OS>.<arch> trees).
_ms_path_add_bindirs() {
    emulate -L zsh
    (( ${_ms_env_rebuild:-1} )) || return 0
    local tier=$1 base sub osarch=bin.${(C)MARKSHARC_OS}.$MARKSHARC_ARCH
    shift
    for base in "$@"; do
        _ms_isdir "$base" || continue
        for sub in bin sbin script scripts batch bin/$osarch bin/$osarch/command-line-tools; do
            _ms_isdir "$base/$sub" && _ms_path_add "$tier" "$base/$sub"
        done
    done
    return 0
}

# Is a command on PATH, or in a directory already contributed to any tier? The
# loader asks this for env-phase "requires command", before the builder has run.
_ms_command_pending() {
    emulate -L zsh
    local name=$1 tier var dir REPLY
    [[ -n $name ]] || return 1
    whence -p -- "$name" >/dev/null 2>&1 && return 0
    [[ $name == */* ]] && return 1
    for tier in $_ms_path_tier_names; do
        var=_ms_path_tier_$tier
        for dir in "${(@P)var}"; do
            _ms_fs_path "$dir/$name"
            [[ -x $REPLY && ! -d $REPLY ]] && return 0
        done
    done
    return 1
}

# Build PATH from the tiers. Inherited entries that this builder did not generate
# are kept: those ahead of the first managed entry go between first and manager,
# the rest go after the managed block and before last. Entries recorded as managed
# by an earlier build but not contributed now (a vanished directory, a disabled
# module) are dropped.
_ms_path_build() {
    emulate -L zsh
    local -a order=() deflt=() mainp=() npath=() firstp=() lastp=() unmanaged=() suffix=() result=()
    local tier var entry seen_managed=0 dot=${_ms_opt_core_dot_in_path-off} euid=${uid:-$EUID}
    if [[ ${MARKSHARC_OS-} == darwin ]]; then
        deflt=( manager brew local system user app )
    else
        deflt=( manager brew system user app local )
    fi
    # A tiers option lists the order; a tier it omits follows in the default order, so no
    # contributed directory is dropped. first and last are fixed at the ends.
    if [[ -n ${_ms_opt_path_tiers-} ]]; then
        order=( ${=_ms_opt_path_tiers} )
        order=( ${order:#(first|last)} )
        for tier in $deflt; do (( ${order[(Ie)$tier]} )) || order+=( $tier ); done
    else
        order=( $deflt )
    fi
    firstp=( "${(@)_ms_path_tier_first}" )
    lastp=( "${(@)_ms_path_tier_last}" )
    for tier in $order; do
        var=_ms_path_tier_${tier//[^A-Za-z0-9]/_}
        mainp+=( "${(@P)var}" )
    done
    npath=( "${mainp[@]}" "${lastp[@]}" )
    for entry in "${path[@]}"; do
        [[ -z $entry || $entry == . ]] && continue
        if (( ${npath[(Ie)$entry]} || ${firstp[(Ie)$entry]} || ${_ms_managed_path[(Ie)$entry]} )); then
            (( ${firstp[(Ie)$entry]} )) || seen_managed=1
            continue
        fi
        if (( seen_managed )); then suffix+=( "$entry" ); else unmanaged+=( "$entry" ); fi
    done
    typeset -ga _ms_managed_path=( "${npath[@]}" "${firstp[@]}" )
    result=( "${firstp[@]}" "${unmanaged[@]}" "${mainp[@]}" "${suffix[@]}" "${lastp[@]}" )
    if [[ $euid != 0 && $dot == (on|1|yes|true) ]]; then result+=( . ); fi
    typeset -gU path
    path=( "${result[@]}" )
    export PATH
    return 0
}

# Static contributions of the path module, in the old build_path order.
_ms_path_contribute() {
    emulate -L zsh
    (( ${_ms_env_rebuild:-1} )) || return 0
    _ms_path_add -f system /bin /usr/bin
    _ms_path_add system /sbin /usr/sbin
    _ms_path_add_bindirs local /usr/local /opt
    _ms_path_add_bindirs user "$HOME" "$HOME/.local" "$HOME/usr/local"
    # The marksharc command, in every session class (spec 6.2).
    _ms_path_add user "$MARKSHARC_HOME/bin"
}

# Finalizer: late contributions (directories that have no module of their own and must
# follow every module's entries: opencode after Linuxbrew and LM Studio,
# krew and antigravity after the personal dotfile directories), then the build.
_ms_path_finalize() {
    emulate -L zsh
    (( ${_ms_env_rebuild:-1} )) || return 0
    _ms_path_add_bindirs local "$HOME/.opencode"
    _ms_path_add_bindirs user "$HOME/.krew" "$HOME/.antigravity-ide/antigravity-ide"
    _ms_path_build
}

_ms_path_contribute
(( ${_ms_env_finalizers[(Ie)_ms_path_finalize]} )) || _ms_env_finalizers+=( _ms_path_finalize )
true
