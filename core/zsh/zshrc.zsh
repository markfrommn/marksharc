# -*- mode: shell-script; sh-shell: zsh -*-
#
# MarkSharc init phase (spec 6.6): interactive sessions only. Sourced at top level
# by the generated ZDOTDIR .zshrc and by reload.zsh.

[[ ${MARKSHARC_SESSION-} == interactive ]] || return 0
typeset -g _ms_starting=1
_ms_trace "init phase: start"

# Read the previous detached check before starting another; reloads and doctor timing
# do not initiate background work.
if [[ ${MARKSHARC_NOTIFY:-1} != 0 && ${_ms_reloading:-0} != 1 ]]; then
    typeset -g _ms_sync_dir=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/${MARKSHARC_HOST:-${HOST%%.*}}/sync
    typeset -g _ms_notice= _ms_generation=
    [[ -r $_ms_sync_dir/status ]] && _ms_notice=$(<"$_ms_sync_dir/status")
    [[ -r $_ms_sync_dir/generation ]] && _ms_generation=$(<"$_ms_sync_dir/generation")
    if [[ ( $_ms_notice == behind && -z $_ms_generation ) || ( -n $_ms_generation && $_ms_notice == "behind|$_ms_generation" ) ]]; then
        print -r -- 'marksharc: updates available (run marksharc sync)'
    fi
    typeset -g _ms_last_check=0 _ms_check_hours=${_ms_cfg_set[sync.check_hours]-12}
    [[ -r $_ms_sync_dir/checked ]] && IFS= read -r _ms_last_check < "$_ms_sync_dir/checked"
    [[ $_ms_last_check == <-> ]] || _ms_last_check=0
    [[ $_ms_check_hours == <-> ]] || _ms_check_hours=12
    zmodload zsh/datetime 2>/dev/null
    if [[ -x $MARKSHARC_HOME/core/cli/notify ]] && (( ${EPOCHSECONDS:-0} - _ms_last_check >= _ms_check_hours * 3600 )); then
        command nohup zsh -f "$MARKSHARC_HOME/core/cli/notify" --check </dev/null >/dev/null 2>&1 &!
    fi
    unset _ms_sync_dir _ms_last_check _ms_check_hours _ms_notice _ms_generation
fi

# cs and li reload the core with a verbose trace (spec 6.10).
alias cs='_ms_reload_login=0; . "$MARKSHARC_HOME/core/zsh/reload.zsh"'
alias li='_ms_reload_login=1; . "$MARKSHARC_HOME/core/zsh/reload.zsh"'

# The marksharc command (spec 6.2, 6.10). `reload` has to act on this shell, which a child
# process cannot, so it is a function that sources reload.zsh (quiet unless --verbose, where
# cs and li always trace). Every other subcommand runs the CLI program. Module files
# declare at file scope with -g, so a reload from this function leaves the same state as
# the aliases above.
marksharc() {
    if [[ ${1-} == reload ]]; then
        shift
        local _ms_arg
        _ms_reload_quiet=1
        for _ms_arg; do
            case $_ms_arg in
                --verbose|-v) _ms_reload_quiet=0 ;;
                *) print -ru2 -- "marksharc reload: unknown option: $_ms_arg"; unset _ms_reload_quiet; return 2 ;;
            esac
        done
        _ms_reload_login=0
        . "$MARKSHARC_HOME/core/zsh/reload.zsh"
        return
    fi
    if [[ ${1-} == doctor ]]; then
        MARKSHARC_DOCTOR_PATH=$PATH MARKSHARC_DOCTOR_ENV=${MARKSHARC_ENV-} "$MARKSHARC_HOME/bin/marksharc" "$@"
        return
    fi
    "$MARKSHARC_HOME/bin/marksharc" "$@"
}

# Each init may register cleanup for its own hooks before the next init plan.
for _ms_cleanup in "${_ms_init_cleanups[@]}"; do
    (( $+functions[$_ms_cleanup] )) && "$_ms_cleanup"
done
typeset -ga _ms_init_cleanups=()
unset _ms_cleanup
if (( $+functions[_ms_modules_plan] )); then
    _ms_modules_plan init
    _ms_modules_setup_paths
    _ms_phase=init
    source "$MARKSHARC_HOME/core/zsh/phase.zsh"
fi
[[ -r ${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}/local/post.zsh ]] && source "${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}/local/post.zsh"
# Tools run during init (envman, version managers) may have re-added entries: keep
# the first occurrence of each.
typeset -gU path
path=( "${path[@]}" )
_ms_trace "init phase: done"
unset _ms_starting
