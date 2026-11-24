Describe 'wezterm module'
  terminfo_case() {
    emulate -L zsh
    printf '#!/bin/sh\nprintf "%%s\\n" "curl $*" >> "$OPLOG"\nexit 22\n' > "$TEST_ROOT/bin/curl"
    printf '#!/bin/sh\nprintf "%%s\\n" "tic $*" >> "$OPLOG"\n' > "$TEST_ROOT/bin/tic"
    chmod +x "$TEST_ROOT/bin/curl" "$TEST_ROOT/bin/tic"
    "$MARKSHARC_ROOT/modules/wezterm/installers/wezterm-terminfo" > "$TEST_ROOT/out" 2>&1
    [[ $? == 22 && $(<"$OPLOG") == curl* && $(<"$OPLOG") != *tic* ]]
  }
  It 'stops on a failed download without compiling anything'
    When run terminfo_case
    The status should be success
  End
End
