# -*- mode: shell-script; sh-shell: zsh -*-
# Session classes (spec 6.6): interactive | agent | batch.

# Default agent and editor-injection markers. The agent module option
# _ms_opt_agent_markers (space separated) replaces this list when set; a `set agent.markers`
# line in config.conf is that option, read here because the session is classified before any
# module loads.
typeset -ga _ms_agent_markers_default=(
    CLAUDECODE AI_AGENT CODEX_SESSION_ID CODEX_SANDBOX OPENCODE GEMINI_CLI
    CURSOR_AGENT COPILOT_CLI KILO_CLI_MODE VSCODE_INJECTION VSCODE_NONCE
)

# Sets MARKSHARC_SESSION. It is a shell-local fact: recomputed in every shell,
# never exported. A marker counts when it is set, non-empty and not "0".
_ms_session_classify() {
    emulate -L zsh
    # A reload keeps the class: its stdout may be redirected (cs >/dev/null).
    if (( ${_ms_reloading:-0} )) && [[ -n ${MARKSHARC_SESSION-} ]]; then return 0; fi
    local -a markers
    local name value
    (( $+functions[_ms_config_load] )) && _ms_config_load
    if [[ -n ${_ms_cfg_set[agent.markers]-} ]]; then
        markers=( ${=_ms_cfg_set[agent.markers]} )
    elif [[ -n ${_ms_opt_agent_markers-} ]]; then
        markers=( ${=_ms_opt_agent_markers} )
    else
        markers=( "${_ms_agent_markers_default[@]}" )
    fi
    for name in $markers; do
        value=${(P)name:-}
        if [[ -n $value && $value != 0 ]]; then
            MARKSHARC_SESSION=agent
            return 0
        fi
    done
    if [[ -o interactive && -t 0 && -t 1 ]]; then
        MARKSHARC_SESSION=interactive
    else
        MARKSHARC_SESSION=batch
    fi
    return 0
}
