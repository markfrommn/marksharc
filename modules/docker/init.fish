# docker module, init phase: inside a container whose environment carries SANDCAT variables,
# claude may skip permission prompts. Socket privilege repair is explicit: fix-docker-socket.
if _ms_in_docker; and string match -q -r '^SANDCAT' -- (set -n -x)
    function claude-yolo --description 'claude without permission prompts (sandbox only)'
        claude --dangerously-skip-permissions $argv
    end
else
    functions -e claude-yolo
end
true
