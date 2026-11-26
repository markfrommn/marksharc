#!/usr/bin/env python3
"""Exercise Bash navigation against a real Readline terminal."""
import os
import pty
import select
import subprocess
import tempfile
import time
from pathlib import Path

with tempfile.TemporaryDirectory() as temp:
    base = Path(temp)
    (base / 'first child').mkdir()
    (base / 'second').mkdir()
    config = base / 'marksharc'
    config.mkdir()
    (config / 'config.conf').write_text('module nav\nmodule ssh-agent off\nmodule titles off\n')
    rc = base / 'bashrc'
    rc.write_text('''dirhistory_past=user_past dirhistory_future=user_future
bind -m emacs '"\\e[1;3C": beginning-of-line'
plain_arrow_before=$(bind -m emacs -p | grep -F '"\\e[A":')
PS1='NAV:\\w> '
source "$MARKSHARC_HOME/core/bash/bashrc.bash"
''')
    master, slave = pty.openpty()
    process = subprocess.Popen([os.environ.get('MARKSHARC_TEST_BASH', 'bash'), '--noprofile', '--rcfile', str(rc), '-i'],
                               cwd=temp, stdin=slave, stdout=slave, stderr=slave,
                               env={**os.environ, 'TERM': 'xterm', 'TERM_PROGRAM': 'ghostty', 'CDPATH': '/tmp',
                                    'MARKSHARC_HOME': os.environ['MARKSHARC_ROOT'], 'MARKSHARC_CONFIG': str(config),
                                    'MARKSHARC_NOTIFY': '0'})
    os.close(slave)

    pending = b''

    def expect(needle):
        global pending
        deadline = time.monotonic() + 10
        while needle not in pending and time.monotonic() < deadline:
            if select.select([master], [], [], 0.2)[0]:
                pending += os.read(master, 65536)
        if needle not in pending:
            raise AssertionError(f'missing {needle!r}: {pending!r}')
        index = pending.index(needle) + len(needle)
        data, pending = pending[:index], pending[index:]
        return data

    def command(text):
        os.write(master, text.encode() + b'; printf "\\nDONE_%s\\n" marker\n')
        result = expect(b'DONE_marker\r\n')
        expect(b'> ')
        return result

    try:
        expect(b'> ')
        result = command('[[ $(bind -m emacs -p | grep -F "\\"\\e[A\\":") == "$plain_arrow_before" ]] && echo NAVCHECK_OK')
        assert b'NAVCHECK_OK\r\n' in result, result
        command('cd "first child"')
        command('cd ../second')
        result = command('nav_count=0; nav_counter() { ((nav_count+=1)); }; '
                         '_ms_bash_register_chpwd nav_counter; dirhistory_back; '
                         '[[ $nav_count == 0 ]] && _ms_bash_prompt_dispatch 0 0; '
                         '[[ $nav_count == 1 ]] && echo NAVCHECK_OK; dirhistory_forward')
        assert b'NAVCHECK_OK\r\n' in result, result
        os.write(master, b'\x1b[1;3D')
        expect(b'first child> ')
        os.write(master, b'\x1b[1;3C')
        expect(b'second> ')
        os.write(master, b'\x1bb')
        expect(b'first child> ')
        os.write(master, b'\x1bf')
        expect(b'second> ')
        os.write(master, b'\x1b[1;3A')
        expect((str(base) + '> ').encode())
        os.write(master, b'\x1b[1;3B')
        expect(b'first child> ')
        result = command('dirhistory_back; [[ $PWD == "' + temp + '" ]] && echo NAVCHECK_OK')
        assert b'NAVCHECK_OK\r\n' in result, result
        command('cd second')
        result = command('dirhistory_forward; [[ $PWD == "' + temp + '/second" ]] && echo NAVCHECK_OK')
        assert b'NAVCHECK_OK\r\n' in result, result
        result = command('pushd .. >/dev/null; insert-cycledleft; [[ $PWD == "' + temp + '/second" ]] && echo NAVCHECK_OK')
        assert b'NAVCHECK_OK\r\n' in result, result
        command('set -o vi')
        os.write(master, b'\x1b[1;3A')
        expect((str(base) + '> ').encode())
        os.write(master, b'\x1b[1;3B')
        expect(b'first child> ')
        os.write(master, b'\x1b')
        time.sleep(0.2)
        os.write(master, b'\x1b[1;3A')
        expect((str(base) + '> ').encode())
        os.write(master, b'i')
        result = command('DIRHISTORY_SIZE=08; sample=(); for n in {1..9}; do _ms_nav_push sample "$n"; done; '
                         '[[ ${#sample[@]} == 8 && ${sample[0]} == 2 ]] && echo NAVCHECK_OK')
        assert b'NAVCHECK_OK\r\n' in result, result
        result = command('bind -m emacs "\\"\\e[1;3D\\": end-of-line"; '
                         'printf "module nav off\\n" >> "$MARKSHARC_CONFIG/config.conf"; '
                         'marksharc reload && ! declare -F dirhistory_back && '
                         'bind -m emacs -p | grep -Fx "\\"\\e[1;3C\\": beginning-of-line" && '
                         'bind -m emacs -p | grep -Fx "\\"\\e[1;3D\\": end-of-line" && '
                         '[[ $dirhistory_past == user_past && $dirhistory_future == user_future && '
                         '! ${_ms_nav_past+x} && ! ${_ms_nav_future+x} ]] && echo NAVCHECK_OK')
        assert b'NAVCHECK_OK\r\n' in result, result
        result = command('printf "module nav\\n" >> "$MARKSHARC_CONFIG/config.conf"; '
                         'marksharc reload && declare -F dirhistory_back && '
                         'bind -m emacs -p | grep -Fx "\\"\\e[1;3D\\": end-of-line" && echo NAVCHECK_OK')
        assert b'NAVCHECK_OK\r\n' in result, result
    finally:
        process.kill()
        process.wait(timeout=5)
        os.close(master)
