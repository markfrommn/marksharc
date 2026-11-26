# Overlay hook arrays survive reload and are transported by cwf-new.
# shellcheck disable=SC2034
declare -ga cwf_new_post_create_hooks cwf_new_copy_exclude
if [[ -n ${COMMON_DEV_TOOLS-} && -d $COMMON_DEV_TOOLS ]]; then
    _ms_bash_init_cached -k "$COMMON_DEV_TOOLS" cwf cwf shell bash >/dev/null 2>&1 || :
fi
