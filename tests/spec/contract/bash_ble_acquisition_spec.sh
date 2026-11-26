Describe 'Explicit ble.sh acquisition'
  marksharc="$MARKSHARC_ROOT/bin/marksharc"

  absent_update_case() {
    stub_command git 'printf "%s\n" "$*" >> "$OPLOG"; exit 99'
    "$marksharc" update --only ble-sh > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 1
    grep -q 'first install: marksharc install ble.sh' "$TEST_ROOT/out" || return 2
    [ ! -s "$OPLOG" ] && [ ! -e "$XDG_CACHE_HOME" ]
  }
  It 'leaves acquisition opt-in during updates'
    When run absent_update_case
    The status should be success
  End

  failed_build_case() {
    XDG_CACHE_HOME="$TEST_ROOT/cache with spaces"; export XDG_CACHE_HOME
    IFS= read -r BLE_PIN < "$MARKSHARC_ROOT/modules/line-editor-ble/ble.pin"
    export BLE_PIN
    cache=$XDG_CACHE_HOME/marksharc/plugins
    target=$cache/ble.sh@$BLE_PIN
    stub_command git '
      if [ "$1" = init ]; then mkdir -p "$3/.git"; exit $?; fi
      [ "$1" = -C ] || exit 99
      checkout=$2
      shift 2
      case $1 in
        remote) : > "$checkout/.git/has-origin" ;;
        fetch) [ "$5" = origin ] && [ "$6" = "$BLE_PIN" ] ;;
        checkout) : ;;
        submodule) [ -f "$checkout/.git/has-origin" ] ;;
        rev-parse) printf "%s\n" "$BLE_PIN" ;;
        *) exit 99 ;;
      esac'
    stub_command gawk 'printf "%s\n" "GNU Awk 5.2"'
    stub_command gmake '
      if [ "$1" = --version ]; then printf "%s\n" "GNU Make 4.4"; exit 0; fi
      printf "%s\n" build >> "$OPLOG"
      mkdir -p "$3/out/lib" && printf "%s\n" "# editor" > "$3/out/ble.sh" || exit 1
      [ "${BLE_BUILD_FAIL:-0}" != 1 ]'
    if BLE_BUILD_FAIL=1 "$marksharc" install ble.sh > "$TEST_ROOT/out" 2> "$TEST_ROOT/err"; then return 1; fi
    [ ! -e "$target" ] || return 2
    set -- "$cache"/.ble.*
    [ ! -e "$1" ] || return 3
    "$marksharc" install ble.sh > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 4
    [ -s "$target/out/ble.sh" ] || return 5
    "$marksharc" update --only ble-sh > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 6
    [ "$(grep -c '^build$' "$OPLOG")" -eq 2 ] || return 7
    previous=$cache/ble.sh@0000000000000000000000000000000000000000
    mv -- "$target" "$previous" || return 8
    "$marksharc" update --only ble-sh > "$TEST_ROOT/out" 2> "$TEST_ROOT/err" || return 9
    [ -s "$target/out/ble.sh" ] && [ -s "$previous/out/ble.sh" ] &&
      [ "$(grep -c '^build$' "$OPLOG")" -eq 3 ]
  }
  It 'discards failed builds, reuses the same pin, and installs changed pins on update'
    When run failed_build_case
    The status should be success
  End
End
