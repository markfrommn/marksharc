source "$MARKSHARC_HOME/core/zsh/lib/modules.zsh"
_ms_trace() { :; }
case $OSTYPE in darwin*) MARKSHARC_OS=darwin ;; linux*) MARKSHARC_OS=linux ;; *) MARKSHARC_OS=${OSTYPE%%[0-9.-]*} ;; esac
MARKSHARC_HOST=${MARKSHARC_HOST:-${HOST%%.*}}
config=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}
_day2_collect() {
    local name conf line _day2_dir
    _ms_modules_discover
    if [[ ${_day2_allow_missing:-0} == 1 ]]; then _ms_modules_plan env; else _ms_modules_plan init; fi
    for name in "${_ms_plan[@]}"; do
        _day2_dir=${_ms_mod_dir[$name]}; conf=$_day2_dir/module.conf
        while IFS= read -r line || [[ -n $line ]]; do
            _ms_words "$line" || continue
            _day2_directive "${reply[@]}" || return
        done < "$conf"
    done
    _day2_dir=$config
    for conf in "$config/config.conf" "$config/hosts/$MARKSHARC_HOST.conf"; do
        [[ -r $conf ]] || continue
        while IFS= read -r line || [[ -n $line ]]; do
            _ms_words "$line" || continue
            _day2_directive "${reply[@]}" || return
        done < "$conf"
    done
}
