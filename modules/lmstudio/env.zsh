# lmstudio module: ~/.lmstudio/bin. The old PATH put it right after /usr/local/bin ahead of
# the system directories on macOS (the local tier) and in the app tier, after CUDA, on
# Linux; both are kept.
(( ${+functions[_ms_path_add]} )) || return 0
if [[ ${MARKSHARC_OS-} == darwin ]]; then
    _ms_path_add local "$HOME/.lmstudio/bin"
else
    _ms_path_add app "$HOME/.lmstudio/bin"
fi
true
