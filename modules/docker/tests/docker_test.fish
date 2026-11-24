source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture
ms_stub claude 'printf "%s\n" "$*" >>"$TEST_ROOT/claude"'
for name in (set -n -x | string match '^SANDCAT*')
    set -e $name
end

function container_case --argument-names in_docker sandcat
    functions -e claude-yolo
    set -e SANDCAT_INSTANCE
    test "$sandcat" = yes; and set -gx SANDCAT_INSTANCE 1
    # Redefine with the case's answer, then run init.
    eval "function _ms_in_docker; return $in_docker; end"
    _ms_fish_init_module "$MARKSHARC_ROOT/modules/docker"
    functions -q claude-yolo
end

container_case 0 yes
@test "claude-yolo exists in a container with SANDCAT" $status -eq 0
printf '' >"$TEST_ROOT/claude"
claude-yolo --resume 'a b'
@test "claude-yolo runs claude without permission prompts and passes arguments" "$(cat "$TEST_ROOT/claude")" = "--dangerously-skip-permissions --resume a b"
container_case 0 no
@test "no SANDCAT variable means no claude-yolo" $status -eq 1
container_case 1 yes
@test "SANDCAT outside a container means no claude-yolo" $status -eq 1
container_case 1 no
@test "neither means no claude-yolo" $status -eq 1

# A SANDCAT variable counts by name, not by a value that happens to mention it.
set -e SANDCAT_INSTANCE
set -gx OTHER_VAR SANDCAT
function _ms_in_docker
    return 0
end
functions -e claude-yolo
_ms_fish_init_module "$MARKSHARC_ROOT/modules/docker"
@test "a value that mentions SANDCAT is not a SANDCAT variable" (functions -q claude-yolo; echo $status) -eq 1
set -e OTHER_VAR

# Reloading in a shell that left the container removes the function.
set -gx SANDCAT_PROXY 1
_ms_fish_init_module "$MARKSHARC_ROOT/modules/docker"
@test "another SANDCAT variable name works" (functions -q claude-yolo; echo $status) -eq 0
function _ms_in_docker
    return 1
end
_ms_fish_init_module "$MARKSHARC_ROOT/modules/docker"
@test "re-running init outside a container removes claude-yolo" (functions -q claude-yolo; echo $status) -eq 1
@test "init prints nothing" -z "$(_ms_fish_init_module "$MARKSHARC_ROOT/modules/docker" 2>&1)"
set -e SANDCAT_PROXY

# The real container check, with its file paths pointed at fixtures.
source "$MARKSHARC_ROOT/modules/docker/functions/fish/_ms_in_docker.fish"
set -g _ms_docker_env_file "$TEST_ROOT/dockerenv"
set -g _ms_docker_cgroup_file "$TEST_ROOT/cgroup"
_ms_in_docker
@test "no marker files and not PID 1 is not a container" $status -ne 0
touch "$TEST_ROOT/dockerenv"
_ms_in_docker
@test "a /.dockerenv file means a container" $status -eq 0
command rm "$TEST_ROOT/dockerenv"
printf '12:cpu:/user.slice\n1:name=systemd:/docker/0123abcd\n' >"$TEST_ROOT/cgroup"
_ms_in_docker
@test "docker in the PID 1 cgroup means a container" $status -eq 0
printf '0::/user.slice/session-1.scope\n' >"$TEST_ROOT/cgroup"
_ms_in_docker
@test "a plain cgroup is not a container" $status -ne 0
set -e _ms_docker_env_file _ms_docker_cgroup_file

ms_cleanup
