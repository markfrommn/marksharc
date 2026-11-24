# Cached tool init (spec 6.10), the fish port of _ms_init_cached.
#
#   _ms_fish_init_cached [-k <extra-key>] [-P <PATH>] [-x <NAME>] <tool> <command...>
#
# Stores the output of <command...> (for example `starship init fish`) under
# $XDG_CACHE_HOME/marksharc/<host>/init/, keyed on the command's resolved binary path,
# its mtime, the arguments, the optional extra key and the -P value, then sources the
# file. -P runs the command under that PATH. -x caches the output as the value of an
# exported variable NAME instead of as a script. Empty output is never cached. A hit forks
# nothing. A missing tool returns 1 silently; a failing tool returns its status and
# caches nothing. If the cache cannot be written, the output is applied directly: it is
# the tool's own documented shell integration, the one place generated text is evaluated.
function _ms_fish_init_cached
    set -l extra
    set -l runpath
    set -l export_name
    while set -q argv[1]; and contains -- "$argv[1]" -k -P -x
        set -q argv[2]; or return 2
        switch $argv[1]
            case -k
                set extra (string replace -a \n ' ' -- "$argv[2]")
            case -P
                set runpath "$argv[2]"
            case -x
                string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- "$argv[2]"; or return 2
                set export_name "$argv[2]"
        end
        set -e argv[1..2]
    end
    set -q argv[2]; or return 2
    set -l tool $argv[1]
    set -e argv[1]
    set -l bin $argv[1]
    if not string match -q '*/*' -- "$bin"
        set bin (command -s -- "$bin"); or return 1
    end
    test -x "$bin"; and not test -d "$bin"; or return 1
    set -l cmdbin $bin
    set bin (path resolve -- "$bin")
    set -l mtime (path mtime -- "$bin"); or return 1
    set -l key (string replace -a \n ' ' -- "$bin|$mtime|$extra|$runpath|$argv")
    test -n "$export_name"; and set key "$key|x:$export_name"
    set -l name (string replace -a -r '[^A-Za-z0-9._-]' _ -- "$tool")__(string join _ -- $argv[2..] | string replace -a -r '[^A-Za-z0-9._-]' _)
    if test -n "$extra"
        set name "$name"__k_(string replace -a -r '[^A-Za-z0-9._-]' _ -- "$extra")
    end
    test -n "$export_name"; and set name "$name"__x_$export_name
    set name (string sub -l 120 -- "$name")
    set -l cache "$HOME/.cache"
    set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"; and set cache "$XDG_CACHE_HOME"
    set -l host "$MARKSHARC_HOST"
    test -n "$host"; or set host (string split -m 1 . -- "$hostname")[1]
    set -l dir "$cache/marksharc/$host/init"
    set -l file "$dir/$name.fish"
    if test -r "$file"
        set -l header
        read -l header <"$file"
        # A header-only file (empty output) is a miss.
        if test "$header" = "# marksharc-init: $key"; and test (count <"$file") -gt 1
            test "$_ms_fish_verbose" = 1; and printf 'marksharc: init-cache hit: %s\n' "$tool" >&2
            source "$file"
            return $status
        end
    end
    test "$_ms_fish_verbose" = 1; and printf 'marksharc: init-cache miss: %s\n' "$tool" >&2
    # set keeps the status of its command substitution; the lines are joined afterwards.
    set -l out
    if test -n "$runpath"
        set out (env PATH="$runpath" "$cmdbin" $argv[2..] 2>/dev/null)
    else
        set out ($cmdbin $argv[2..] 2>/dev/null)
    end
    set -l result $status
    test $result -eq 0; or return $result
    set out (string join \n -- $out | string collect)
    test -n (string trim -- "$out" | string collect); or return 0
    # set keeps the previous status; true makes a sourced hit succeed.
    test -n "$export_name"; and set out "set -gx $export_name "(string escape -- "$out")\ntrue
    test -d "$dir"; or command mkdir -p -- "$dir" 2>/dev/null
    set -l tmp "$file.$fish_pid"
    if printf '# marksharc-init: %s\n%s\n' "$key" "$out" >"$tmp" 2>/dev/null; and command mv -f -- "$tmp" "$file" 2>/dev/null
        source "$file"
        return $status
    end
    command rm -f -- "$tmp" 2>/dev/null
    printf '%s\n' "$out" | source
end
