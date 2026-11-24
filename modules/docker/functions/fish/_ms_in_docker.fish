# _ms_in_docker: succeed inside a container: /.dockerenv exists, PID 1's cgroup mentions
# docker, or this shell is PID 1 (docker on mac and windows; not bulletproof). The two file
# paths can be overridden for tests with _ms_docker_env_file and _ms_docker_cgroup_file.
function _ms_in_docker
    set -l env_file /.dockerenv
    set -l cgroup_file /proc/1/cgroup
    set -q _ms_docker_env_file; and set env_file "$_ms_docker_env_file"
    set -q _ms_docker_cgroup_file; and set cgroup_file "$_ms_docker_cgroup_file"
    test -f "$env_file"; and return 0
    if test -r "$cgroup_file"; and string match -q '*docker*' <"$cgroup_file"
        return 0
    end
    test "$fish_pid" = 1
end
