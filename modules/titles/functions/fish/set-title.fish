# set-title TAB [WINDOW [COMBINED]]: set the terminal tab title, and optionally the window and
# combined titles. Control characters are dropped from every argument; nothing is expanded.
function set-title --description 'Set the terminal tab, window and combined titles'
    if test -n "$INSIDE_EMACS"; and test "$INSIDE_EMACS" != vterm
        return 0
    end
    set -l tab (string replace -a -r '[[:cntrl:]]' '' -- "$argv[1]")
    set -l window (string replace -a -r '[[:cntrl:]]' '' -- "$argv[2]")
    set -l combined (string replace -a -r '[[:cntrl:]]' '' -- "$argv[3]")
    if string match -q -r '^(screen|tmux)' -- "$TERM"
        test -z "$combined"; or printf '\033]0;%s\033\\' "$combined"
        test -z "$window"; or printf '\033]2;%s\033\\' "$window"
        printf '\033k%s\033\\' "$tab"
    else if string match -q -r '^(cygwin|ansi)$|^(xterm|putty|rxvt|konsole|mlterm|alacritty|st|foot|contour|wezterm|nsterm)' -- "$TERM"
        or contains -- "$TERM_PROGRAM" iTerm.app Apple_Terminal
        test -z "$combined"; or printf '\033]0;%s\007' "$combined"
        test -z "$window"; or printf '\033]2;%s\007' "$window"
        printf '\033]1;%s\007' "$tab"
    else if command -sq tput
        # Terminals that describe a status line in terminfo (tsl and fsl).
        set -l tsl (tput tsl 2>/dev/null | string collect -N)
        set -l fsl (tput fsl 2>/dev/null | string collect -N)
        if test -n "$tsl"; and test -n "$fsl"
            printf '%s%s%s' "$tsl" "$tab" "$fsl"
        end
    end
    return 0
end
