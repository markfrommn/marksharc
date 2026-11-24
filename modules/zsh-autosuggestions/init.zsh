# zsh-autosuggestions module, init phase (spec 6.8): suggestions from atuin's store, the
# in-memory history and completion. Order 95: after fzf-tab (71) and atuin (83), so the
# widgets it wraps exist, and before zsh-syntax-highlighting (99), which must be last.
#
# Configuration comes before the plugin is sourced; the plugin keeps values already set.
# MANUAL_REBIND binds the widgets once (at the first prompt) instead of at every prompt.
# atuin's search widgets clear the suggestion, so it never lingers behind the atuin UI.
typeset -g ZSH_AUTOSUGGEST_MANUAL_REBIND=1
typeset -g ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=${ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE:-200}
if [[ ${_ms_opt_zsh_autosuggestions_async-on} == (on|1|yes|true) ]]; then
    typeset -g ZSH_AUTOSUGGEST_USE_ASYNC=1
else
    unset ZSH_AUTOSUGGEST_USE_ASYNC
fi

if have_command atuin; then
    # The atuin strategy: the newest command in atuin's store that starts with the buffer.
    _zsh_autosuggest_strategy_atuin() {
        emulate -L zsh
        typeset -g suggestion
        suggestion=$(command atuin search --cmd-only --limit 1 --search-mode prefix -- "$1" 2>/dev/null)
    }
else
    unfunction _zsh_autosuggest_strategy_atuin 2>/dev/null
fi

# Keep only known strategies that can run here: atuin needs the command; history,
# completion and match_prev_cmd ship with the plugin. History is the last resort.
typeset -ga ZSH_AUTOSUGGEST_STRATEGY=()
typeset -g _ms_as_strategy
for _ms_as_strategy in ${=_ms_opt_zsh_autosuggestions_strategy-atuin history completion}; do
    case $_ms_as_strategy in
        atuin) (( ${+functions[_zsh_autosuggest_strategy_atuin]} )) && ZSH_AUTOSUGGEST_STRATEGY+=( atuin ) ;;
        history|completion|match_prev_cmd) ZSH_AUTOSUGGEST_STRATEGY+=( $_ms_as_strategy ) ;;
    esac
done
(( $#ZSH_AUTOSUGGEST_STRATEGY )) || ZSH_AUTOSUGGEST_STRATEGY=( history )
unset _ms_as_strategy

if (( ! ${_ms_reloading:-0} )); then
    _ms_plugins_load zsh-autosuggestions
    if (( ${+ZSH_AUTOSUGGEST_CLEAR_WIDGETS} )); then
        ZSH_AUTOSUGGEST_CLEAR_WIDGETS+=( atuin-search atuin-search-viins atuin-search-vicmd atuin-up-search atuin-up-search-viins atuin-up-search-vicmd _atuin_search_widget _atuin_up_search_widget )
        typeset -gU ZSH_AUTOSUGGEST_CLEAR_WIDGETS
    fi
fi
true
