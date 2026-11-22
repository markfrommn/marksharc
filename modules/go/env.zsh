# go module: $GOPATH/bin (default ~/go) in the user tier. No go binary is run: the old
# build_path asked "go env GOPATH" in interactive shells, which forked on every start.
(( ${+functions[_ms_path_add]} )) || return 0
(( ${_ms_env_rebuild:-1} )) || return 0
typeset -g _ms_gp
for _ms_gp in ${(s.:.)${GOPATH:-$HOME/go}}; do
    _ms_path_add_bindirs user "$_ms_gp"
done
unset _ms_gp
true
