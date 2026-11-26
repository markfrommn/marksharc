# An explicit BASH_ENV can start with no inherited MarkSharc variables.
if [[ -z ${MARKSHARC_HOME-} ]]; then
    MARKSHARC_HOME=${BASH_SOURCE[0]%/core/bash/env.bash}
    export MARKSHARC_HOME
fi
if [[ -n ${MARKSHARC_HOME-} ]]; then
    # shellcheck source=core/bash/env-cache.bash
    source "$MARKSHARC_HOME/core/bash/env-cache.bash"
    _ms_bash_prepare_env
    if [[ ${MARKSHARC_SESSION-} != interactive || ${_ms_bash_rc_loading-} != 1 ]]; then
        unset -f _ms_bash_cache_path _ms_bash_artifact_matches _ms_bash_context_valid \
            _ms_bash_stale_dir _ms_bash_env_is_current _ms_bash_apply_env _ms_bash_prepare_env
    fi
fi
true
