Describe 'cached tool init (_ms_init_cached)'
  tool_stub() {
    cat > "$TEST_ROOT/bin/${1:-faketool}" <<'DATA'
#!/bin/sh
echo "GEN $*" >> "$OPLOG"
echo 'print -r -- SRC >> "$OPLOG"'
echo 'faketool_fn() { print -r -- fn-ok; }'
echo 'typeset -g faketool_var=set'
DATA
    chmod +x "$TEST_ROOT/bin/${1:-faketool}"
  }
  hit_case() {
    emulate -L zsh
    ms_fixture; tool_stub
    ms_run -c '_ms_init_cached faketool faketool init zsh; print -r -- "rc=$? $(faketool_fn) $faketool_var"' || return 1
    [[ $(<"$TEST_ROOT/out") == "rc=0 fn-ok set" && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    [[ $(<"$OPLOG") == $'GEN init zsh\nSRC' ]] || { cat "$OPLOG"; return 3; }
    local -a cached=( "$XDG_CACHE_HOME"/marksharc/*/init/*(N.) )
    (( $#cached == 1 )) || { print -l -- $cached; return 4; }
    # Second shell: cache hit, the tool is not run again and nothing is forked.
    : > "$OPLOG"
    local tool
    mkdir -p "$TEST_ROOT/forbidden"
    for tool in mkdir mv rm cat date stat; do
      printf '#!/bin/sh\necho "FORBIDDEN %s" >> "$OPLOG"\nexit 99\n' "$tool" > "$TEST_ROOT/forbidden/$tool"
      chmod +x "$TEST_ROOT/forbidden/$tool"
    done
    ms_run PATH="$TEST_ROOT/forbidden:$PATH" -c '_ms_init_cached faketool faketool init zsh; print -r -- "rc=$? $(faketool_fn)"' || return 5
    [[ $(<"$OPLOG") == SRC && $(<"$TEST_ROOT/out") == "rc=0 fn-ok" ]] || { cat "$OPLOG"; return 6; }
  }
  It 'runs the tool once, then sources the cached output without running or forking'
    When run hit_case
    The status should be success
  End
  miss_case() {
    emulate -L zsh
    ms_fixture; tool_stub
    ms_run -c '_ms_init_cached faketool faketool init zsh' || return 1
    : > "$OPLOG"
    touch -t 202001010000 "$TEST_ROOT/bin/faketool"
    ms_run -c '_ms_init_cached faketool faketool init zsh' || return 2
    [[ $(<"$OPLOG") == $'GEN init zsh\nSRC' ]] || { cat "$OPLOG"; return 3; }
    : > "$OPLOG"
    ms_run -c '_ms_init_cached faketool faketool init zsh' || return 4
    [[ $(<"$OPLOG") == SRC ]] || return 5
    # Different arguments and a different -k key are cached separately.
    : > "$OPLOG"
    ms_run -c '_ms_init_cached faketool faketool init bash; _ms_init_cached -k one faketool faketool init zsh; _ms_init_cached -k two faketool faketool init zsh' || return 6
    [[ $(<"$OPLOG") == $'GEN init bash\nSRC\nGEN init zsh\nSRC\nGEN init zsh\nSRC' ]] || { cat "$OPLOG"; return 7; }
    : > "$OPLOG"
    ms_run -c '_ms_init_cached faketool faketool init bash; _ms_init_cached -k one faketool faketool init zsh' || return 8
    [[ $(<"$OPLOG") == $'SRC\nSRC' ]]
  }
  It 'regenerates when the binary mtime, arguments or extra key change'
    When run miss_case
    The status should be success
  End
  symlink_case() {
    emulate -L zsh
    ms_fixture; tool_stub real-faketool
    ln -s real-faketool "$TEST_ROOT/bin/faketool"
    ms_run -c '_ms_init_cached faketool faketool init zsh' || return 1
    : > "$OPLOG"
    touch -t 202001010000 "$TEST_ROOT/bin/real-faketool"
    ms_run -c '_ms_init_cached faketool faketool init zsh' || return 2
    [[ $(<"$OPLOG") == $'GEN init zsh\nSRC' ]] || { cat "$OPLOG"; return 3; }
    # A tool given by absolute path (brew style) works too.
    : > "$OPLOG"
    ms_run -c '_ms_init_cached brew "$TEST_ROOT/bin/faketool" shellenv zsh' || return 4
    [[ $(<"$OPLOG") == $'GEN shellenv zsh\nSRC' ]]
  }
  It 'keys on the resolved binary so a relinked upgrade regenerates'
    When run symlink_case
    The status should be success
  End
  missing_case() {
    emulate -L zsh
    ms_fixture
    ms_run -c '_ms_init_cached nosuchtool nosuchtool init zsh; print -r -- "rc=$?"' || return 1
    [[ $(<"$TEST_ROOT/out") == rc=1 && ! -s $TEST_ROOT/err && ! -s $OPLOG ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    local -a cached=( "$XDG_CACHE_HOME"/marksharc/*/init/*(N) )
    (( $#cached == 0 )) || return 3
    # A tool that fails is not cached and its status is returned.
    printf '#!/bin/sh\necho GEN >> "$OPLOG"\necho "print BAD >> \\"\\$OPLOG\\""\nexit 3\n' > "$TEST_ROOT/bin/failtool"
    chmod +x "$TEST_ROOT/bin/failtool"
    ms_run -c '_ms_init_cached failtool failtool init zsh; print -r -- "rc=$?"' || return 4
    [[ $(<"$TEST_ROOT/out") == rc=3 && $(<"$OPLOG") == GEN && ! -s $TEST_ROOT/err ]] || { cat "$OPLOG" "$TEST_ROOT/out"; return 5; }
    cached=( "$XDG_CACHE_HOME"/marksharc/*/init/*(N) )
    (( $#cached == 0 ))
  }
  It 'is silent and returns nonzero for a missing tool, and never caches a failing tool'
    When run missing_case
    The status should be success
  End
  unwritable_case() {
    emulate -L zsh
    ms_fixture; tool_stub
    mkdir -p "$XDG_CACHE_HOME"; : > "$XDG_CACHE_HOME/marksharc"
    ms_run -c '_ms_init_cached faketool faketool init zsh; print -r -- "rc=$? $(faketool_fn)"' || return 1
    [[ $(<"$TEST_ROOT/out") == "rc=0 fn-ok" && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    [[ $(<"$OPLOG") == $'GEN init zsh\nSRC' ]]
  }
  It 'still applies the init output when the cache directory is unwritable'
    When run unwritable_case
    The status should be success
  End
  empty_case() {
    emulate -L zsh
    ms_fixture
    printf '#!/bin/sh\necho "GEN" >> "$OPLOG"\n' > "$TEST_ROOT/bin/emptytool"
    chmod +x "$TEST_ROOT/bin/emptytool"
    ms_run -c '_ms_init_cached emptytool emptytool init zsh; print -r -- "rc=$?"' || return 1
    [[ $(<"$TEST_ROOT/out") == rc=0 && ! -s $TEST_ROOT/err ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
    local -a cached=( "$XDG_CACHE_HOME"/marksharc/*/init/*(N) )
    (( ${#cached} == 0 )) || return 3
    # Empty output is a miss every time, so a later non-empty answer is used.
    ms_run -c '_ms_init_cached emptytool emptytool init zsh' || return 4
    [[ $(grep -c '^GEN$' "$OPLOG") == 2 ]]
  }
  It 'never caches empty output'
    When run empty_case
    The status should be success
  End
  fixed_path_case() {
    emulate -L zsh
    ms_fixture
    printf '#!/bin/sh\necho "print -r -- PATHSEEN:$PATH >> \\"\\$OPLOG\\""\n' > "$TEST_ROOT/bin/pathtool"
    chmod +x "$TEST_ROOT/bin/pathtool"
    ms_run -c '_ms_init_cached -P /usr/bin:/bin pathtool pathtool init zsh' || return 1
    [[ $(<"$OPLOG") == PATHSEEN:/usr/bin:/bin ]] || { cat "$OPLOG"; return 2; }
  }
  It 'generates under a fixed PATH when asked'
    When run fixed_path_case
    The status should be success
  End
End
