# Inside a container that carries SANDCAT variables, claude may skip permission prompts.
# Socket privilege repair is explicit: fix-docker-socket.
if in_docker && printenv | command grep -q SANDCAT; then
    alias claude-yolo="claude --dangerously-skip-permissions"
fi
