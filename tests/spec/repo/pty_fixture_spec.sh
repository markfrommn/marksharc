Describe 'PTY fixture input'
  large_input_case() {
    "$PYTHON" - "$MARKSHARC_ROOT/tests/support/pty_socket.py" <<'PY'
import os
import signal
import subprocess
import sys

script = 'count=0\n' + 'count=$((count+1)) # padding for the terminal input queue\n' * 1000
script += "[ \"$count\" -eq 1000 ] || exit 43; printf '\\nPTY_DONE\\n'; exit 42\n"
proc = subprocess.Popen(
    [sys.executable, sys.argv[1], 'pty', '/bin/sh', '-i'],
    env={**os.environ, 'PTY_INPUT': script},
    stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
try:
    out, err = proc.communicate(timeout=10)
    assert proc.returncode == 42, (proc.returncode, err)
    assert b'\nPTY_DONE\n' in out, out[-1000:]
finally:
    # Also bound the test if a regression blocks the fixture before its read loop.
    try:
        os.killpg(proc.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    proc.wait()
PY
  }
  It 'drains terminal output while delivering input larger than the terminal queue'
    Skip if 'Python is unavailable for the PTY fixture' test -z "$PYTHON"
    When run large_input_case
    The status should be success
  End
End
