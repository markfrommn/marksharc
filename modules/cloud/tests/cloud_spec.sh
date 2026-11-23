Describe 'cloud module'
  krew_case() {
    emulate -L zsh
    printf '#!/bin/sh\nprintf "%%s\\n" "curl $*" >> "$OPLOG"\nexit 22\n' > "$TEST_ROOT/bin/curl"
    chmod +x "$TEST_ROOT/bin/curl"
    local tmp="$TEST_ROOT/tmp"; mkdir -p "$tmp"
    TMPDIR=$tmp "$MARKSHARC_ROOT/modules/cloud/installers/krew" > "$TEST_ROOT/out" 2>&1
    [[ $? == 22 && $(<"$OPLOG") == 'curl -fsSLO https://github.com/kubernetes-sigs/krew/releases/latest/download/krew-'* ]] || return 1
    [[ -z $(print -l "$tmp"/*(N)) ]] || return 2
  }
  It 'reports a failed download and removes its temporary directory'
    When run krew_case
    The status should be success
  End
End
