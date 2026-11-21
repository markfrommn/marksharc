# -*- mode: shell-script; sh-shell: zsh -*-
# Login shells: re-assert the env phase PATH after /etc/zprofile (macOS path_helper
# reorders PATH). Entries added since that the env phase did not manage stay last.
if (( ${#_ms_path_asserted} )); then
    path=( "${_ms_path_asserted[@]}" "${path[@]:|_ms_path_asserted}" )
    typeset -gU path
    export PATH
    _ms_trace "zprofile: PATH re-asserted"
fi
