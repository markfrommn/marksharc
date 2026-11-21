# cuda module (Linux): when the NVIDIA driver is loaded (/dev/nvidiactl exists; the old
# code forked lspci and grepped for an RTX), export the MPS directories and put CUDA's
# bin directory in the app tier. Both honour _ms_fs_root.
(( ${_ms_env_rebuild:-1} )) || return 0
if [[ -e ${_ms_fs_root-}/dev/nvidiactl ]]; then
    export CUDA_MPS_PIPE_DIRECTORY=/tmp/nvidia-mps CUDA_MPS_LOG_DIRECTORY=$HOME/tmp/nvidia-mps
    (( ${+functions[_ms_path_add]} )) && _ms_path_add app /usr/local/cuda/bin
fi
true
