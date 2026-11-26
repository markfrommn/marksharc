function git_managed_arr_core {
    (( $# >= 2 )) || return 1
    local _ms_gm_mode=$1 _ms_gm_dest=$2 _ms_gm_file _ms_gm_status
    [[ $_ms_gm_dest =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]] || return 1
    [[ $_ms_gm_mode == managed || $_ms_gm_mode == unmanaged ]] || return 1
    local -a _ms_gm_selected=()
    shift 2
    for _ms_gm_file in "$@"; do
        _ms_gm_status=0
        command git --literal-pathspecs ls-files --error-unmatch -- "$_ms_gm_file" >/dev/null 2>&1 || _ms_gm_status=$?
        if [[ $_ms_gm_mode == managed && $_ms_gm_status == 0 ]] ||
           [[ $_ms_gm_mode == unmanaged && $_ms_gm_status == 1 ]]; then
            _ms_gm_selected+=("$_ms_gm_file")
        elif (( _ms_gm_status > 1 )); then return "$_ms_gm_status"; fi
    done
    local -n _ms_gm_target=$_ms_gm_dest
    _ms_gm_target=("${_ms_gm_selected[@]}")
}
