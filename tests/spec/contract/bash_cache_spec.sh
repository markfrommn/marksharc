Describe 'Bash tool init cache'
  Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
  cache_fixture() {
    mkdir -p "$TEST_ROOT/bin"
    cat > "$TEST_ROOT/bin/faketool" <<'EOF'
#!/bin/sh
printf 'generate\n' >> "$OPLOG"
printf '%s\n' 'CACHE_RESULT="${CACHE_RESULT}x"'
EOF
    chmod +x "$TEST_ROOT/bin/faketool"
  }

  cache_keys_case() {
    cache_fixture
    env PATH="$TEST_ROOT/bin:$PATH" MARKSHARC_HOME="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_HOME/core/bash/cache.bash"
      _ms_bash_init_cached -k "one two" faketool faketool "a b" c || exit 1
      _ms_bash_init_cached -k "one two" faketool faketool "a b" c || exit 2
      _ms_bash_init_cached -k "one two" faketool faketool a "b c" || exit 3
      _ms_bash_init_cached -k "one" faketool faketool "a b" c || exit 4
      [[ $CACHE_RESULT == xxxx ]] || exit 5
    ' || return 1
    [ "$(wc -l < "$OPLOG" | tr -d ' ')" = 3 ] || return 2
    touch -t 202001010000 "$TEST_ROOT/bin/faketool"
    env PATH="$TEST_ROOT/bin:$PATH" MARKSHARC_HOME="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_HOME/core/bash/cache.bash"
      _ms_bash_init_cached -k "one two" faketool faketool "a b" c
    ' || return 3
    [ "$(wc -l < "$OPLOG" | tr -d ' ')" = 4 ]
  }
  It 'keys entries on executable mtime, exact arguments and context'
    When run cache_keys_case
    The status should be success
  End

  cache_symlink_case() {
    cache_fixture
    cp "$TEST_ROOT/bin/faketool" "$TEST_ROOT/bin/other"
    touch -t 202001010000 "$TEST_ROOT/bin/faketool" "$TEST_ROOT/bin/other"
    ln -s faketool "$TEST_ROOT/bin/link"
    env PATH="$TEST_ROOT/bin:$PATH" MARKSHARC_HOME="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_HOME/core/bash/cache.bash"
      _ms_bash_init_cached tool link init || exit 1
      _ms_bash_init_cached tool link init || exit 2
    ' || return 1
    rm "$TEST_ROOT/bin/link"
    ln -s other "$TEST_ROOT/bin/link"
    env PATH="$TEST_ROOT/bin:$PATH" MARKSHARC_HOME="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_HOME/core/bash/cache.bash"
      _ms_bash_init_cached tool link init
    ' || return 2
    [ "$(wc -l < "$OPLOG" | tr -d ' ')" = 2 ]
  }
  It 'invalidates a symlink when its target changes with the same mtime'
    When run cache_symlink_case
    The status should be success
  End

  cache_failure_case() {
    cache_fixture
    env PATH="$TEST_ROOT/bin:$PATH" MARKSHARC_HOME="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_HOME/core/bash/cache.bash"
      _ms_bash_init_cached missing no_such_marksharc_tool init && exit 1
      _ms_bash_init_cached fail /bin/sh -c "exit 7" && exit 2
      _ms_bash_init_cached empty /bin/sh -c ":" || exit 3
      _ms_bash_init_cached faketool faketool || exit 4
    ' || return 1
    cache_file=$(find "$XDG_CACHE_HOME/marksharc" -name '*.bash' -type f)
    [ "$(find "$XDG_CACHE_HOME/marksharc" -name '*.bash' -type f | wc -l | tr -d ' ')" = 1 ] || return 4
    [ -n "$cache_file" ] || return 2
    printf '%s\n' '# damaged cache' > "$cache_file"
    env PATH="$TEST_ROOT/bin:$PATH" MARKSHARC_HOME="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_HOME/core/bash/cache.bash"
      _ms_bash_init_cached faketool faketool || exit 1
      [[ $CACHE_RESULT == x ]]
    ' || return 3
    [ "$(wc -l < "$OPLOG" | tr -d ' ')" = 2 ]
  }
  It 'regenerates malformed entries and does not cache missing, failing or empty generators'
    When run cache_failure_case
    The status should be success
  End

  cache_unwritable_case() {
    cache_fixture
    mkdir -p "$XDG_CACHE_HOME"
    : > "$XDG_CACHE_HOME/marksharc"
    env PATH="$TEST_ROOT/bin:$PATH" MARKSHARC_HOME="$MARKSHARC_ROOT" "${MARKSHARC_TEST_BASH:-bash}" -c '
      source "$MARKSHARC_HOME/core/bash/cache.bash"
      _ms_bash_init_cached faketool faketool || exit 1
      [[ $CACHE_RESULT == x ]]
    '
  }
  It 'applies successful output when its cache cannot be created'
    When run cache_unwritable_case
    The status should be success
  End
End
