# rust module: $CARGO_HOME (default ~/.cargo) bin directory in the user tier.
(( ${+functions[_ms_path_add]} )) || return 0
(( ${_ms_env_rebuild:-1} )) || return 0
_ms_path_add_bindirs user "${CARGO_HOME:-$HOME/.cargo}"
true
