source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
ms_fixture

# The modules's functions are loaded the way the loader does it, but init.fish runs under
# a PATH that holds only the stub bin and a private directory of system tools, so a host
# less, man or diff never changes the result. The full PATH is back for the tests.
set -g TOOLS "$TEST_ROOT/tools"
command mkdir -p "$TOOLS"
for tool in sh env tr cat od mkdir mv rm
    command -sq $tool; and command ln -s (command -s $tool) "$TOOLS/$tool"
end
set -g FULL_PATH $PATH
function init_pager
    set -gx PATH "$TEST_ROOT/bin" "$TOOLS"
    ms_module pager
    set -l result $status
    set -gx PATH "$TEST_ROOT/bin" $FULL_PATH[2..]
    return $result
end

# Stubs: man and dman record what they are run with; less records its arguments and input;
# diff supports --color.
set -g MAN_BODY 'printf "args=%s\n" "$*"
printf "pager=%s\n" "$PAGER"
printf "lcall=%s lang=%s groff=%s\n" "$LC_ALL" "$LANG" "$GROFF_NO_SGR"
for v in mb md me so se us ue; do
  eval "val=\$LESS_TERMCAP_$v"
  printf "%s=%s\n" $v "$(printf %s "$val" | tr "\033" E)"
done
printf "manpath=%s\n" "$MANPATH"'
function man_stub --argument-names name out
    ms_stub $name "{
$MAN_BODY
} >\"\$TEST_ROOT/$out\""
end
# field FILE KEY: the value of a KEY=value line the stub recorded.
function field --argument-names file key
    string replace -f -r "^$key=" '' <"$TEST_ROOT/$file"
end
man_stub man man.out
ms_stub less 'printf "less %s\n" "$*" >>"$TEST_ROOT/less.out"; cat >>"$TEST_ROOT/less.out"'
ms_stub diff 'printf "diff %s\n" "$*" >>"$TEST_ROOT/diff.out"
case "$*" in "--color=always /dev/null /dev/null") exit 0 ;; esac
echo "different"; exit 1'

set -e PAGER LESS MANPATH
init_pager >"$TEST_ROOT/out" 2>&1
@test "startup is quiet" ! -s "$TEST_ROOT/out"
@test "PAGER is less -R when less exists" "$PAGER" = "less -R"
@test "PAGER is exported" "$(set -qx PAGER; and echo yes)" = yes
@test "LESS is -FRX" "$LESS" = -FRX
@test "LESS is exported" "$(set -qx LESS; and echo yes)" = yes
@test "MANPATH starts with /usr/share/man" "$MANPATH[1]" = /usr/share/man
@test "MANPATH is exported" "$(set -qx MANPATH; and echo yes)" = yes
if test -d /usr/local/man
    @test "an existing /usr/local/man is added" "$MANPATH[2]" = /usr/local/man
else
    @test "a missing /usr/local/man is not added" (count $MANPATH) -eq 1
end

# man: fish's own man function still runs; only its call sees the coloured environment.
set -l lcall_before "$(set -q LC_ALL; and echo set:$LC_ALL)"
set -l pager_before $PAGER
man ls
@test "man runs the real man with its arguments" (field man.out args) = ls
@test "man uses the less binary as pager" (field man.out pager) = "$TEST_ROOT/bin/less"
@test "man runs under the C locale and plain groff" (field man.out lcall) = "C lang=C groff=1"
@test "blink and bold are bold red" "$(field man.out mb)$(field man.out md)" = "E[01;31mE[01;31m"
@test "standout is bold yellow on blue" (field man.out so) = "E[01;33mE[44m"
@test "underline is bold green" (field man.out us) = "E[01;32m"
@test "the end sequences reset" "$(field man.out me)$(field man.out se)$(field man.out ue)" = "E[00mE[00mE[00m"
@test "fish's own man pages come first in MANPATH" (count (string match -- "manpath=$__fish_data_dir/man*" <"$TEST_ROOT/man.out")) -eq 1
@test "the environment does not leak after man" "$(set -q LC_ALL; and echo set:$LC_ALL)" = "$lcall_before"
@test "PAGER is not changed by man" "$PAGER" = "$pager_before"
@test "GROFF_NO_SGR does not leak" (set -q GROFF_NO_SGR; and echo set; or echo unset) = unset
@test "LESS_TERMCAP does not leak" (set -q LESS_TERMCAP_md; and echo set; or echo unset) = unset
man :
@test "fish's own man keeps its special-name mapping" (field man.out args) = true
man 'a page' with-space
@test "man arguments with spaces stay whole" (field man.out args) = "a page with-space"
@test "man returns the status of the real man" (ms_stub man 'exit 5'; man x; echo $status) = 5

# A reload keeps one wrapper over fish's own man, not a wrapper over itself.
man_stub man man.out
set -g _ms_fish_reloading 1
init_pager >"$TEST_ROOT/out" 2>&1
set -e _ms_fish_reloading
@test "a reload is quiet" ! -s "$TEST_ROOT/out"
man again
@test "man still works after a reload" (field man.out args) = again

# colored runs any command with the coloured environment.
@test "colored passes the termcap values" (colored sh -c 'printf %s "$LESS_TERMCAP_us"' | tr '\033' E) = "E[01;32m"
@test "colored runs functions too" (function show_lang; echo $LANG; end; colored show_lang) = C
@test "colored without a command is a usage error" (colored 2>/dev/null; echo $status) = 2

# dman and debman exist only when the commands do.
@test "dman is not defined without the command" (functions -q dman; echo $status) = 1
man_stub dman dman.out
init_pager
dman foo
@test "dman runs with the coloured environment" (field dman.out lcall) = "C lang=C groff=1"
@test "debman is not defined without the command" (functions -q debman; echo $status) = 1

# diff defaults to --color=auto when it supports --color.
@test "diff is wrapped" (functions -q diff; and echo yes) = yes
printf '' >"$TEST_ROOT/diff.out"
diff a b >/dev/null
@test "the diff wrapper defaults to --color=auto" "$(tail -n 1 "$TEST_ROOT/diff.out")" = "diff --color=auto a b"

# diffcp pipes a forced-colour diff into less -R.
printf '' >"$TEST_ROOT/diff.out"
printf '' >"$TEST_ROOT/less.out"
diffcp 'one file' two
@test "diffcp forces colour in diff" "$(cat "$TEST_ROOT/diff.out")" = "diff --color=always one file two"
@test "diffcp pages through less -R" "$(head -n 2 "$TEST_ROOT/less.out")" = "less -R
different"

# A diff without --color support is left alone.
functions -e diff
ms_stub diff 'exit 2'
init_pager
@test "diff stays unwrapped when it lacks --color" (functions -q diff; echo $status) = 1

# Without less PAGER is left alone.
set -e PAGER
command rm -f "$TEST_ROOT/bin/less"
init_pager
@test "PAGER is not set without less" (set -q PAGER; echo $status) = 1

ms_cleanup
