#!/usr/bin/env python3
"""Flag file-scope declarations without -g in the zsh files the core sources.

module env.zsh/init.zsh files and the overlay local/*.zsh hooks are sourced by the core and
reloaded from the marksharc function. A bare typeset, declare, local, integer, float or
readonly at file scope is global when the file is sourced at top level but function-local when
it is sourced from a function, so such a file must say -g. Declarations inside function bodies
(anonymous functions included) are the author's business and are skipped.

Usage: function-safe-check.py ROOT   (prints "path:line: command" per finding; exit 1 if any)
"""
import re
import sys
from pathlib import Path

DECLARATIONS = {"typeset", "declare", "local", "integer", "float", "readonly", "private"}
# After these words a command starts again.
# (builtin, command, exec and noglob are prefixes: the declaration follows them.)
KEYWORDS = {"then", "do", "else", "elif", "if", "while", "until", "!", "time", "nocorrect", "noglob",
            "builtin", "command", "exec"}
# name () | function name | function name () | function (anonymous) | () (anonymous)
FUNCTION_HEAD = re.compile(
    r"^(function(\s+[^\s=()]+)*\s*(\(\s*\))?|[^\s=()]+\s*\(\s*\)|\(\s*\))$"
)


def sanitize(text):
    """Blank out comments, quoted text and heredoc bodies, keeping every newline."""
    out = []
    i, n = 0, len(text)
    word_start = True
    while i < n:
        c = text[i]
        if c == "#" and word_start:
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if c == "\\" and i + 1 < n:
            out.append(c)
            out.append(text[i + 1] if text[i + 1] == "\n" else " ")
            i += 2
            word_start = False
            continue
        if c == "'" or c == '"' or (c == "$" and text.startswith("$'", i)):
            if c == "$":
                out.append("$")
                i += 1
                c = "'"
            quote = c
            out.append(quote)
            i += 1
            while i < n and text[i] != quote:
                if text[i] == "\\" and quote == '"' and i + 1 < n:
                    out.append(" ")
                    i += 1
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            if i < n:
                out.append(quote)
                i += 1
            word_start = False
            continue
        if text.startswith("<<<", i):  # a here-string, not a heredoc
            out.append("<<<")
            i += 3
            word_start = False
            continue
        heredoc = re.match(r"<<-?\s*(['\"]?)([A-Za-z_][A-Za-z0-9_]*)\1", text[i:])
        if c == "<" and heredoc:
            out.append(heredoc.group(0))
            i += len(heredoc.group(0))
            word = heredoc.group(2)
            # the rest of this line still runs, then the body up to the terminator is blanked
            while i < n and text[i] != "\n":
                out.append(text[i])
                i += 1
            while i < n:
                end = text.find("\n", i + 1)
                line = text[i + 1 : end if end != -1 else n]
                out.append("\n")
                i += 1
                if line.strip() == word:
                    out.append(" " * len(line))
                    i += len(line)
                    break
                out.append(" " * len(line))
                i += len(line)
            continue
        out.append(c)
        word_start = c in " \t\n;&|"
        i += 1
    return "".join(out)


TOKEN = re.compile(r"(?:[ \t]|\\\n)*(\n|&&|\|\||;;|;|\||&|\{|\}|\(|\)|[^\s;&|(){}\\]+|\\.)")


def scan(text):
    findings = []
    clean = sanitize(text)
    tokens = []
    line = 1
    pos = 0
    for m in TOKEN.finditer(clean):
        line += clean.count("\n", pos, m.start(1))
        tokens.append((m.group(1), line))
        if m.group(1) == "\n":
            line += 1
        pos = m.end()
    stack = []
    cases = 0  # open case statements: a ")" at paren depth 0 ends a pattern and starts a command
    paren = 0
    start = True
    stmt = []
    for idx, (tok, lno) in enumerate(tokens):
        if tok in ("\n", ";", ";;", "&&", "||", "|", "&"):
            # "name ()" then a newline then "{": keep the head for the brace
            nxt = next((t for t, _ in tokens[idx + 1 :] if t != "\n"), "")
            if not (tok == "\n" and nxt == "{" and FUNCTION_HEAD.match(" ".join(stmt).replace("( )", "()"))):
                stmt = []
            start = True
            continue
        if tok == "{":
            head = " ".join(stmt).replace("( )", "()")
            stack.append(bool(FUNCTION_HEAD.match(head)))
            stmt = []
            start = True
            continue
        if tok == "}":
            if stack:
                stack.pop()
            stmt = []
            start = False
            continue
        if tok == "(":
            paren += 1
            stmt.append(tok)
            start = True
            continue
        if tok == ")":
            paren = max(0, paren - 1)
            stmt.append(tok)
            start = bool(cases) and paren == 0
            continue
        if tok == "esac":
            cases = max(0, cases - 1)
            stmt = []
            start = False
            continue
        if start and tok == "case":
            cases += 1
        if start and tok in KEYWORDS:
            stmt.append(tok)
            continue
        if start and tok in DECLARATIONS and not any(stack) and paren == 0:
            flags = ""
            for t, _ in tokens[idx + 1 :]:
                if t[:1] in "-+" and len(t) > 1 and not t.startswith("--"):
                    flags += t[1:]
                else:
                    break
            if "g" not in flags and not set(flags) & set("fpm"):
                findings.append((lno, tok))
        stmt.append(tok)
        start = False
    return findings


def main(root):
    root = Path(root)
    files = sorted(root.glob("modules/*/env.zsh")) + sorted(root.glob("modules/*/init.zsh"))
    files += sorted(root.glob("templates/overlay/local/*.zsh"))
    # the core files are sourced by the same reload
    files += sorted(root.glob("core/zsh/*.zsh")) + sorted(root.glob("core/zsh/lib/*.zsh"))
    failed = False
    for path in files:
        for lno, word in scan(path.read_text(errors="replace")):
            print(f"{path.relative_to(root)}:{lno}: {word} without -g at file scope")
            failed = True
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1]))
