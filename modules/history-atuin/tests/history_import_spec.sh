Describe 'legacy history import'
  import_bin() { print -r -- "$MARKSHARC_ROOT/modules/history-atuin/bin/import-legacy-history"; }
  import_script() {
    mkdir -p "$TEST_ROOT/tmp"
    TMPDIR="$TEST_ROOT/tmp" PATH="${IMPORT_PATH:-$PATH}" "$(import_bin)" "$@"
  }
  no_sqlite3() { ! command -v sqlite3 >/dev/null 2>&1; }

  # Legacy fixtures live under the temporary HOME. printf '%s\n' keeps every
  # backslash-newline exact.
  make_fixtures() {
    local t="$HOME/.cache/zsh-directory-history" tr="$HOME/.cache/zsh-directory-history-box2"
    printf '%s\n' ': 1700000000:0;ls -l' ': 1700000010:3;echo one\' 'two' ': 1700000020:0;git status' > "$HOME/.zsh_history"
    printf '%s\n' ': 1700000000:0;ls -l' ': 1700000020:0;git status' ': 1700000030:0;date' > "$HOME/.zhistory"
    mkdir -p "$t/work/tester/proj" "$t/no_active_project" "$tr/home/tester/x"
    printf '%s\n' ': 1700000020:0;git status' ': 1700000040:0;make test' > "$t/work/tester/proj/history"
    printf '%s\n' ': 1700000050:0;uptime' > "$t/no_active_project/history"
    : > "$t/history"
    printf '%s\n' ': 1700000060:0;systemctl status' > "$HOME/.zsh_history-box2"
    printf '%s\n' ': 1700000070:0;cd x' > "$tr/home/tester/x/history"
  }
  # The stub records its argv, then keeps what it was asked to import: the
  # extended-history file (plain route) or a text dump of the rows (histdb route).
  stub_atuin() {
    cat > "$TEST_ROOT/bin/atuin" <<'DATA'
#!/bin/sh
printf 'atuin %s\n' "$*" >> "$OPLOG"
case "$1 $2" in
  'import zsh')
    printf 'HISTFILE=%s\n' "$HISTFILE" >> "$OPLOG"
    cp "$HISTFILE" "$TEST_ROOT/imported";;
  'import zsh-hist-db')
    printf 'HISTDB_FILE=%s\n' "$HISTDB_FILE" >> "$OPLOG"
    sqlite3 "$HISTDB_FILE" "select h.start_time||'|'||p.host||'|'||p.dir||'|'||replace(c.argv, char(10), '<NL>')||'|'||h.duration||'|'||h.exit_status from history h join commands c on c.id=h.command_id join places p on p.id=h.place_id order by h.start_time, h.id" > "$TEST_ROOT/imported";;
esac
echo atuin-banner
[ -z "$STUB_FAIL" ] || { echo 'atuin: boom' >&2; exit 1; }
DATA
    chmod +x "$TEST_ROOT/bin/atuin"
  }
  home_files() { find "$HOME" -type f | sort; }

  # Arithmetic over the portable default fixtures:
  #   .zsh_history 3 + .zhistory 3 + tree 3 = 9 (copied -box2 files are opt-in)
  #   unique (timestamp, command) = 6: ls -l and git status repeat across files,
  #   git status also in the tree
  #   with a directory = 2: git status, make test
  default_summary() {
    printf '%s\n' \
      "source $HOME/.zsh_history label=$HOST entries=3" \
      "source $HOME/.zhistory label=$HOST entries=3" \
      "tree $HOME/.cache/zsh-directory-history label=$HOST files=3 entries=3"
  }

  It 'parses the extended format and preserves multi-line entries'
    multiline_case() {
      emulate -L zsh
      make_fixtures; stub_atuin
      import_script --dry-run --route plain --source "$HOME/.zsh_history" || return 1
      import_script --route plain --source "$HOME/.zsh_history" > /dev/null || return 2
      local expected=': 1700000000:0;ls -l
: 1700000010:3;echo one\
two
: 1700000020:0;git status'
      [[ $(<"$TEST_ROOT/imported") == "$expected" ]] || { cat "$TEST_ROOT/imported"; return 3; }
    }
    When run multiline_case
    The status should be success
    The output should equal "source $HOME/.zsh_history label=$HOST entries=3
total=3 unique=3 with_dir=0 route=plain
dry-run: nothing written"
  End

  It 'de-duplicates across default files and trees, preferring the copy with a directory'
    dedupe_case() { emulate -L zsh; make_fixtures; import_script --dry-run --route histdb; }
    Skip if 'sqlite3 is absent' no_sqlite3
    When run dedupe_case
    The status should be success
    The output should equal "$(default_summary)
total=9 unique=6 with_dir=2 route=histdb
dry-run: nothing written"
  End

  It 'includes ZDOTDIR/.zsh_history in defaults when distinct from HOME'
    zdotdir_case() {
      emulate -L zsh
      printf '%s\n' ': 1700000000:0;ls -l' > "$HOME/.zsh_history"
      printf '%s\n' ': 1700000080:0;pwd' > "$ZDOTDIR/.zsh_history"
      import_script --dry-run --route plain
    }
    When run zdotdir_case
    The status should be success
    The output should equal "source $HOME/.zsh_history label=$HOST entries=1
source $ZDOTDIR/.zsh_history label=$HOST entries=1
total=2 unique=2 with_dir=0 route=plain
dry-run: nothing written"
  End

  It 'assigns tree directories from the path and none for the root and no_active_project'
    directories_case() {
      emulate -L zsh
      make_fixtures; stub_atuin
      import_script --route histdb \
        --source "$HOME/.zsh_history" --source "$HOME/.zhistory" --source "$HOME/.zsh_history-box2" \
        --tree "$HOME/.cache/zsh-directory-history" --tree "$HOME/.cache/zsh-directory-history-box2" \
        > /dev/null || return 1
      cat "$TEST_ROOT/imported"
    }
    Skip if 'sqlite3 is absent' no_sqlite3
    When run directories_case
    The status should be success
    The output should equal "1700000000|$HOST|unknown|ls -l|0|-1
1700000010|$HOST|unknown|echo one<NL>two|3|-1
1700000020|$HOST|/work/tester/proj|git status|0|-1
1700000030|$HOST|unknown|date|0|-1
1700000040|$HOST|/work/tester/proj|make test|0|-1
1700000050|$HOST|unknown|uptime|0|-1
1700000060|box2|unknown|systemctl status|0|-1
1700000070|box2|/home/tester/x|cd x|0|-1"
  End

  It 'reports no directories on the plain route and with --no-dirs'
    nodirs_case() {
      emulate -L zsh
      make_fixtures
      import_script --dry-run --route plain | tail -2 | head -1
      import_script --dry-run --no-dirs --route histdb | tail -2 | head -1
    }
    Skip if 'sqlite3 is absent' no_sqlite3
    When run nodirs_case
    The output should equal "total=9 unique=6 with_dir=0 route=plain
total=9 unique=6 with_dir=0 route=histdb"
  End

  It 'labels suffixed host copies from the filename and honours FILE=LABEL'
    labels_case() {
      emulate -L zsh
      make_fixtures
      import_script --dry-run --route plain --source "$HOME/.zsh_history-box2" --source "$HOME/.zhistory=build7" \
        --tree "$HOME/.cache/zsh-directory-history-box2" --tree "$HOME/.cache/zsh-directory-history=lab"
    }
    When run labels_case
    The output should equal "source $HOME/.zsh_history-box2 label=box2 entries=1
source $HOME/.zhistory label=build7 entries=3
tree $HOME/.cache/zsh-directory-history-box2 label=box2 files=1 entries=1
tree $HOME/.cache/zsh-directory-history label=lab files=3 entries=3
total=8 unique=7 with_dir=0 route=plain
dry-run: nothing written"
  End

  It 'treats text after the last = as a label only when it has no slash'
    equals_path_case() {
      emulate -L zsh
      mkdir -p "$HOME/a=b"
      printf '%s\n' ': 1700000000:0;ls -l' > "$HOME/a=b/history"
      import_script --dry-run --route plain --source "$HOME/a=b/history" --source "$HOME/a=b/history=lab"
    }
    When run equals_path_case
    The output should equal "source $HOME/a=b/history label=$HOST entries=1
source $HOME/a=b/history label=lab entries=1
total=2 unique=1 with_dir=0 route=plain
dry-run: nothing written"
  End

  It 'dry-run writes nothing and never calls atuin'
    dry_run_case() {
      emulate -L zsh
      make_fixtures; stub_atuin
      local before after
      before=$(home_files)
      import_script --dry-run --route histdb > "$TEST_ROOT/dry.out" || return 1
      after=$(home_files)
      [[ $before == $after ]] || return 2
      [[ ! -s $OPLOG ]] || { cat "$OPLOG"; return 3; }
      [[ -z $(ls -A "$TEST_ROOT/tmp") ]] || return 4
      tail -1 "$TEST_ROOT/dry.out"
    }
    Skip if 'sqlite3 is absent' no_sqlite3
    When run dry_run_case
    The status should be success
    The output should equal 'dry-run: nothing written'
  End

  It 'skips entries that carry no timestamp, so a re-run adds nothing'
    untimed_case() {
      emulate -L zsh
      printf '%s\n' ': 1700000000:0;ls -l' 'plain line without timestamp' > "$HOME/src"
      import_script --dry-run --route plain --source "$HOME/src"
    }
    When run untimed_case
    The output should equal "source $HOME/src label=$HOST entries=1
total=1 unique=1 with_dir=0 route=plain
dry-run: nothing written"
    The stderr should equal "note: $HOME/src: skipped 1 entries without a timestamp"
  End

  It 'skips missing sources and trees silently'
    missing_case() {
      emulate -L zsh
      printf '%s\n' ': 1700000000:0;ls -l' ': 1700000020:0;git status' ': 1700000030:0;date' > "$HOME/.zhistory"
      import_script --dry-run --route plain
    }
    When run missing_case
    The status should be success
    The output should equal "source $HOME/.zhistory label=$HOST entries=3
total=3 unique=3 with_dir=0 route=plain
dry-run: nothing written"
    The stderr should equal ''
  End

  It 'fails clearly without atuin but still dry-runs'
    no_atuin_case() {
      emulate -L zsh
      make_fixtures
      mkdir -p "$TEST_ROOT/no-atuin"
      local tool
      for tool in mktemp rm; do ln -s "$(command -v $tool)" "$TEST_ROOT/no-atuin/$tool"; done
      export IMPORT_PATH="$TEST_ROOT/no-atuin"
      import_script --dry-run --route plain > /dev/null || return 1
      import_script --route plain > /dev/null 2> "$TEST_ROOT/err"
      local rc=$?
      grep -qi atuin "$TEST_ROOT/err" || return 9
      return $rc
    }
    When run no_atuin_case
    The status should equal 3
  End

  It 'falls back to plain when sqlite3 is missing'
    nosqlite_case() {
      emulate -L zsh
      make_fixtures; stub_atuin
      mkdir -p "$TEST_ROOT/nosql"
      local tool
      for tool in mktemp rm cp cat; do ln -s "$(command -v $tool)" "$TEST_ROOT/nosql/$tool"; done
      cp "$TEST_ROOT/bin/atuin" "$TEST_ROOT/nosql/atuin"
      export IMPORT_PATH="$TEST_ROOT/nosql"
      import_script --dry-run 2>/dev/null | tail -2 | head -1
      import_script > /dev/null 2> "$TEST_ROOT/err" || return 1
      cat "$TEST_ROOT/err"
      [[ -s $TEST_ROOT/imported ]] || return 2
      import_script --route histdb > /dev/null 2>&1
      print "explicit histdb: $?"
    }
    When run nosqlite_case
    The status should be success
    The output should equal "total=9 unique=6 with_dir=0 route=plain
note: sqlite3 not found; importing without directories
explicit histdb: 3"
  End

  It 'writes only under TMPDIR and cleans up'
    tmpdir_case() {
      emulate -L zsh
      make_fixtures; stub_atuin
      local before after
      before=$(home_files)
      import_script --route plain > /dev/null || return 1
      grep -q "^HISTFILE=$TEST_ROOT/tmp/" "$OPLOG" || { cat "$OPLOG"; return 2; }
      [[ -z $(ls -A "$TEST_ROOT/tmp") ]] || return 3
      after=$(home_files)
      [[ $before == $after ]]
    }
    When run tmpdir_case
    The status should be success
  End

  It 'keeps non-ASCII bytes of the extended format intact on the plain route'
    bytes_case() {
      emulate -L zsh
      stub_atuin
      # \342\203\246\203\262 is U+2192 metafied; \304\203\243 is U+0103 metafied.
      printf ': 1700000100:0;echo \342\203\246\203\262 caf\303\251 \304\203\243\n' > "$HOME/src"
      import_script --route plain --source "$HOME/src" > /dev/null || return 1
      cmp "$HOME/src" "$TEST_ROOT/imported"
    }
    When run bytes_case
    The status should be success
  End

  It 'treats quotes, semicolons and SQL text in commands as data on the histdb route'
    quoting_case() {
      emulate -L zsh
      stub_atuin
      printf '%s\n' ": 1700000200:0;echo 'a;b' -- \"x\"; DROP TABLE history;--" > "$HOME/src"
      import_script --route histdb --source "$HOME/src" > /dev/null || return 1
      cat "$TEST_ROOT/imported"
    }
    Skip if 'sqlite3 is absent' no_sqlite3
    When run quoting_case
    The output should equal "1700000200|$HOST|unknown|echo 'a;b' -- \"x\"; DROP TABLE history;--|0|-1"
  End

  It 'reports an atuin failure'
    atuin_fail_case() {
      emulate -L zsh
      make_fixtures; stub_atuin
      STUB_FAIL=1 import_script --route plain > /dev/null 2> "$TEST_ROOT/err"
      local rc=$?
      grep -q 'boom' "$TEST_ROOT/err" || return 9
      return $rc
    }
    When run atuin_fail_case
    The status should equal 1
  End

  It 'rejects bad usage with status 2'
    usage_case() {
      emulate -L zsh
      import_script --bogus > /dev/null 2>&1; print "unknown option: $?"
      import_script --route nope > /dev/null 2>&1; print "bad route: $?"
      import_script --source > /dev/null 2>&1; print "missing value: $?"
    }
    When run usage_case
    The output should equal "unknown option: 2
bad route: 2
missing value: 2"
  End

  It 'exposes import-legacy-history on PATH when history-atuin is enabled with atuin'
    path_exposure_case() {
      emulate -L zsh
      ms_fixture_full
      print 'return 0' > "$MS_HOME/modules/brew/functions/zsh/setup-homebrew"
      stub_atuin
      ms_run -c 'whence -p import-legacy-history' || return 1
      [[ $(<"$TEST_ROOT/out") == "$MS_HOME/modules/history-atuin/bin/import-legacy-history" ]] || { cat "$TEST_ROOT/out"; return 2; }
    }
    When run path_exposure_case
    The status should be success
  End
End
