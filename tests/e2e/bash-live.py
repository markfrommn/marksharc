#!/usr/bin/env python3
"""Inspect a real interactive Bash profile in a disposable installed home."""

import errno
import fcntl
import getpass
import os
import pty
import re
import select
import shlex
import shutil
import signal
import statistics
import struct
import subprocess
import tempfile
import termios
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
BASH = shutil.which(os.environ.get("MARKSHARC_TEST_BASH", "bash"))
PROMPT = b"MS-READY>"
ANSI = re.compile(rb"\x1b(?:\[[0-?]*[ -/]*[@-~]|\][^\x07]*(?:\x07|\x1b\\))")


class Terminal:
    def __init__(self, env, cwd):
        self.pending = b""
        self.transcript = b""
        start = time.monotonic()
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", 32, 120, 0, 0))
            os.chdir(cwd)
            os.execve(BASH, [BASH, "-i"], env)
        try:
            self.expect(PROMPT)
        except Exception:
            self.close()
            raise
        self.ms = (time.monotonic() - start) * 1000

    def send(self, data):
        os.write(self.fd, data)

    def expect(self, needle, timeout=15):
        end = time.monotonic() + timeout
        while needle not in self.pending and time.monotonic() < end:
            if not select.select([self.fd], [], [], 0.1)[0]:
                continue
            try:
                data = os.read(self.fd, 65536)
            except OSError as error:
                if error.errno != errno.EIO:
                    raise
                break
            if not data:
                break
            self.pending += data
            self.transcript += data
            # Terminal status queries occur after shell and editor binds.
            if b"\x1b[5n" in data:
                self.send(b"\x1b[0n")
        if needle not in self.pending:
            raise AssertionError(f"missing {needle!r}\n{self.transcript[-7000:]!r}")
        offset = self.pending.index(needle) + len(needle)
        result, self.pending = self.pending[:offset], self.pending[offset:]
        return result

    def command(self, text, timeout=15):
        # Split the marker in the input to distinguish echoes from output.
        self.send((text + "; printf '\\nMS-%s\\n' DONE\r").encode())
        result = self.expect(b"MS-DONE\r\n", timeout)
        self.expect(PROMPT)
        return ANSI.sub(b"", result)

    def close(self):
        os.close(self.fd)
        try:
            os.killpg(self.pid, signal.SIGHUP)
        except ProcessLookupError:
            pass
        os.waitpid(self.pid, 0)

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()


def run(env, *argv, cwd=None):
    result = subprocess.run(argv, env=env, cwd=cwd, text=True, capture_output=True, timeout=120)
    if result.returncode:
        raise RuntimeError(f"{argv!r}: {result.stdout}{result.stderr}")
    return result.stdout.strip()


def check(output, expected):
    if expected not in output:
        raise AssertionError(f"missing {expected!r} in {output!r}")


def check_wrapper(terminal, env, work):
    repo = work / "base repo"
    tree = work / "linked checkout"
    repo.mkdir()
    run(env, "git", "init", "-q", "-b", "main", cwd=repo)
    run(env, "git", "-c", "user.name=Live Test", "-c", "user.email=live@example.invalid",
        "commit", "-q", "--allow-empty", "-m", "Create fixture", cwd=repo)
    run(env, "git", "worktree", "add", "-q", "-b", "smoke", str(tree), cwd=repo)
    terminal.command("cd " + shlex.quote(str(tree)))
    # Keep any installed CWF out of this disposable Git-only test.
    terminal.send(b"PATH=/usr/bin:/bin:\"$MARKSHARC_HOME/modules/git-worktree/bin\" gwt-clean\r")
    terminal.expect(b"[y/N]")
    terminal.send(b"y\r")
    terminal.expect(PROMPT)
    check(terminal.command("printf '\\nWRAPPER=%s\\n' \"$PWD\""), b"WRAPPER=" + str(repo).encode())
    if tree.exists():
        raise AssertionError("gwt-clean retained its disposable worktree")


def check_launch(terminal, env, work):
    marker = work / "launch result"
    child = work / "space child"
    program = work / "live-launch"
    program.write_text('#!/bin/sh\nprintf "%s\\n" "$PWD" "$2" "$3" >>"$1"\n')
    program.chmod(0o700)
    args = ["launch-session", "--quiet", "--mux", "tmux", "--place", "tab", "--pwd", str(child),
            "--in-shell", "--", str(program), str(marker), "literal ' quotes", ""]
    run(env, "tmux", "-f", "/dev/null", "new-session", "-d", "-s", "marksharc", "sleep 90")
    try:
        terminal.command(shlex.join(args))
        deadline = time.monotonic() + 15
        while not marker.exists() and time.monotonic() < deadline:
            time.sleep(0.1)
        if not marker.exists() or marker.read_text() != f"{child}\nliteral ' quotes\n\n":
            panes = run(env, "tmux", "list-panes", "-a", "-F", "#{pane_id}")
            output = [run(env, "tmux", "capture-pane", "-pt", pane) for pane in panes.splitlines()]
            raise AssertionError(f"tmux Bash launch did not deliver argv once: {output!r}")
    finally:
        run(env, "tmux", "kill-server")


def verify(env, home):
    work = home / "live files"
    work.mkdir()
    child = work / "space child"
    child.mkdir()
    (work / "mark' quoted").touch()
    (work / "mark second").touch()
    (work / "unique's quoted").touch()
    conf = home / ".config" / "marksharc"
    starship = home / "starship.toml"
    starship.write_text(
        'format = "$status$directory$character"\n'
        '[status]\ndisabled = false\nformat = "FAILED($status) "\n'
        '[directory]\nformat = "[$path]($style) "\n'
        '[character]\nsuccess_symbol = "MS-READY>"\nerror_symbol = "MS-READY>"\n'
    )
    with (conf / "config.conf").open("a") as config:
        config.write(
            '\nset completion-carapace.enable on\n'
            'set completion-carapace.excludes git\n'
            'set prompt-starship.config ~/starship.toml\n'
            'module titles off\nmodule ssh-agent off\n'
        )
    atuin = home / ".config" / "atuin"
    atuin.mkdir()
    (atuin / "config.toml").write_text("auto_sync = false\nupdate_check = false\n")
    run(env, str(ROOT / "bin/marksharc"), "render")
    with Terminal(env, work) as terminal:
        cold = terminal.ms
        print(f"Cold tool cache {cold:.0f} ms", flush=True)
        samples = []
        for _ in range(5):
            with Terminal(env, work) as warm:
                samples.append(warm.ms)
        print(f"Warm median {statistics.median(samples):.0f} ms, max {max(samples):.0f} ms (budget 500 ms)", flush=True)
        check(terminal.command("completion-ui status"), b"active=ble/carapace")
        check(terminal.command("complete -p z"), b"__zoxide_z_complete")
        session = re.search(rb"\r\nATUIN=(\S+)\r\n", terminal.command("printf '\\nATUIN=%s\\n' \"$ATUIN_SESSION\""))
        if not session:
            raise AssertionError("Atuin did not initialize a session")
        atuin_env = {**env, "ATUIN_SESSION": session[1].decode()}
        terminal.send(b"false # ms-live-failure\r")
        check(ANSI.sub(b"", terminal.expect(PROMPT)), b"FAILED1")
        deadline = time.monotonic() + 5
        while True:
            history = run(atuin_env, "atuin", "search", "-e", "1", "--cmd-only", "ms-live-failure")
            if "false # ms-live-failure" in history:
                break
            if time.monotonic() >= deadline:
                raise AssertionError(f"Atuin did not record failed command: {history!r}")
            time.sleep(0.1)

        # Use a command with no generic provider registration so this exercises
        # the editor's filename completion.
        terminal.command("ms_live_args() { printf '<%s>\\n' \"$@\"; }")
        terminal.send(b"ms_live_args mark\t\t")
        terminal.expect(b"second")
        terminal.expect(b"quoted")
        terminal.send(b"\r\r")
        terminal.expect(b"<mark second>\r\n")
        terminal.expect(PROMPT)
        terminal.send(b"ms_live_args uniq\t")
        terminal.expect(b"quoted")
        terminal.send(b"\r")
        terminal.expect(b"<unique's quoted>\r\n")
        terminal.expect(PROMPT)

        terminal.command("printf MS-SUGGESTION-LIVE")
        terminal.send(b"printf MS-SUGG")
        terminal.expect(b"ESTION-LIVE")
        terminal.send(b"\x03")
        terminal.expect(PROMPT)

        terminal.send(b"\x12")
        terminal.expect(b"ms-live-failure")
        terminal.send(b"\x1b")
        terminal.expect(PROMPT)
        terminal.send(b"\x1b[A")
        terminal.expect(b"ms-live-failure")
        terminal.send(b"\x1b")
        terminal.expect(PROMPT)
        check(terminal.command("cd 'space child'; printf '\\nCWD=%s\\n' \"$PWD\""), str(child).encode())
        check(terminal.command("cd ..; z 'space' && printf '\\nZ=%s\\n' \"$PWD\""), b"Z=" + str(child).encode())
        check(terminal.command("cd ..; _ZO_FZF_OPTS='--filter=space' zi && printf '\\nZI=%s\\n' \"$PWD\""),
              b"ZI=" + str(child).encode())
        terminal.send(b"\x1b[1;3D")
        terminal.expect(PROMPT)
        check(terminal.command("printf '\\nNAV=%s\\n' \"$PWD\""), b"NAV=" + str(work).encode())
        check(terminal.command("pushd 'space child' >/dev/null; popd >/dev/null; printf '\\nSTACK=%s\\n' \"$PWD\""),
              b"STACK=" + str(work).encode())
        terminal.command("export FZF_DEFAULT_OPTS='--filter=space'")
        terminal.send(b"\x1bc")
        terminal.expect(PROMPT)
        check(terminal.command("printf '\\nFZF-CD=%s\\n' \"$PWD\""), b"FZF-CD=" + str(child).encode())
        terminal.command("cd ..; export FZF_DEFAULT_OPTS=\"--filter=mark\"")
        terminal.send(b"printf '<%s>\\n' \x14\r")
        terminal.expect(b"<mark' quoted>\r\n")
        terminal.expect(PROMPT)
        check_wrapper(terminal, env, work)
        check_launch(terminal, env, work)
        reloaded = terminal.command(
            "completion-ui readline; marksharc reload --verbose && printf '\\nRELOAD-OK\\n'", timeout=60
        )
        check(reloaded, b"active=ble/carapace pending=readline/carapace")
        check(reloaded, b"\r\nRELOAD-OK\r\n")
        check(terminal.command("complete -p z"), b"__zoxide_z_complete")
    with Terminal({**env, "MARKSHARC_BASH_EDITOR": "readline", "MARKSHARC_BASH_COMPLETION_UI": "native"}, work) as terminal:
        check(terminal.command("completion-ui status"), b"active=readline/bash-completion")
        check(terminal.command("complete -p z"), b"__zoxide_z_complete")


def main():
    for tool in (BASH, "starship", "atuin", "zoxide", "fzf", "carapace", "tmux"):
        if not tool or not shutil.which(tool):
            raise SystemExit(f"Required live-test tool unavailable: {tool}")
    with tempfile.TemporaryDirectory(prefix="ms-bash-live.", dir="/tmp") as path:
        home = Path(path).resolve() / "home"
        home.mkdir()
        env = {
            "HOME": str(home),
            "USER": getpass.getuser(),
            "PATH": os.environ["PATH"],
            "TERM": "xterm-256color",
            "SHELL": BASH,
            "LANG": "en_US.UTF-8" if os.uname().sysname == "Darwin" else "C.UTF-8",
            "MARKSHARC_NOTIFY": "0",
            "TMUX_TMPDIR": path,
        }
        prefix = os.environ.get("HOMEBREW_PREFIX")
        if prefix:
            env["HOMEBREW_PREFIX"] = prefix
        print(os.uname().sysname, run(env, BASH, "--version").splitlines()[0], flush=True)
        run(env, "sh", str(ROOT / "install.sh"), "--no-plugins")
        run(env, str(ROOT / "bin/marksharc"), "install", "ble.sh")
        verify(env, home)
        print("Live Bash checks passed")


if __name__ == "__main__":
    main()
