"""OS fixture support only; assertions and test cases live in ShellSpec."""
import os
import pty
import select
import signal
import socket
import subprocess
import sys
import threading
import time
import tty

if sys.argv[1] == 'socket':
    with socket.socket(socket.AF_UNIX) as sock:
        sock.bind(sys.argv[2])
elif sys.argv[1] == 'pty':
    master, slave = pty.openpty()
    # PTY_INPUT (optional) is typed into the terminal once the child has started; the child
    # does not see the variable.
    typed = os.environ.get('PTY_INPUT')
    if typed is not None:
        # Avoid the kernel's canonical input limit during scripted startup;
        # interactive editors manage their own input once they initialize.
        tty.setcbreak(slave)
    child_env = {k: v for k, v in os.environ.items() if k != 'PTY_INPUT'}
    proc = subprocess.Popen(sys.argv[2:], stdin=slave, stdout=slave, stderr=slave,
                            start_new_session=True, close_fds=True, env=child_env)
    os.close(slave)
    def send_input():
        pending = memoryview(typed.encode())
        try:
            while pending:
                pending = pending[os.write(master, pending):]
        except OSError:
            # The child may exit without consuming all supplied input.
            pass

    # A blocking write of the whole script can fill macOS's PTY queues.
    # Send on a separate thread so echo/output is drained at the same time.
    if typed is not None:
        threading.Thread(target=send_input, daemon=True).start()
    deadline = time.monotonic() + 15
    try:
        while True:
            if time.monotonic() > deadline:
                raise TimeoutError('PTY child timed out')
            if select.select([master], [], [], 0.1)[0]:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    break
                if not data:
                    break
                sys.stdout.buffer.write(data.replace(b'\r\n', b'\n'))
            elif proc.poll() is not None:
                break
        result = proc.wait(timeout=1)
    finally:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=1)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
        os.close(master)
    sys.exit(result)
else:
    raise SystemExit('Expected socket or pty')
