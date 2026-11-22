# -*- mode: shell-script; sh-shell: zsh -*-
# cs and li (spec 6.10): a verbose reload of the core in the current shell. Sourced
# by the cs/li aliases (top level) and by the marksharc function; module files declare with
# -g, so both leave the same state (tests/spec/zsh/function_safe_spec.sh). It
# re-sources the core (code edits take effect), forces an env rebuild and re-runs
# the init phase. `li` also re-runs the login-only steps. Once-per-shell steps are
# skipped while _ms_reloading is set. The marksharc function (zshrc.zsh) runs it for
# `marksharc reload` with _ms_reload_quiet=1, which keeps the trace off unless
# MARKSHARC_VERBOSE is already set; cs and li always trace.
_ms_reloading=1
_ms_force_rebuild=1
_ms_reload_had_verbose=${+MARKSHARC_VERBOSE}
_ms_reload_old_verbose=${MARKSHARC_VERBOSE-}
(( ${_ms_reload_quiet:-0} )) || MARKSHARC_VERBOSE=1
source "$MARKSHARC_HOME/core/zsh/zshenv.zsh"
(( ${_ms_reload_login:-0} )) && source "$MARKSHARC_HOME/core/zsh/zprofile.zsh"
source "$MARKSHARC_HOME/core/zsh/zshrc.zsh"
(( ${_ms_reload_login:-0} )) && source "$MARKSHARC_HOME/core/zsh/zlogin.zsh"
if (( _ms_reload_had_verbose )); then MARKSHARC_VERBOSE=$_ms_reload_old_verbose; else unset MARKSHARC_VERBOSE; fi
_ms_verbose=0
[[ -n ${MARKSHARC_VERBOSE-} && $MARKSHARC_VERBOSE != 0 ]] && _ms_verbose=1
unset _ms_force_rebuild _ms_reload_had_verbose _ms_reload_old_verbose _ms_reload_login _ms_reload_quiet
_ms_reloading=0
true
