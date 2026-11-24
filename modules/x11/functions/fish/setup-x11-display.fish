# setup-x11-display: remember the DISPLAY the session arrived with as DISPLAY_ORIG; an empty
# DISPLAY is bogus and dropped. Nothing here probes the network or sleeps, and nothing is
# printed unless marksharc runs verbose (then the note goes to stderr).
function setup-x11-display --description 'Record the inherited DISPLAY as DISPLAY_ORIG'
    if test -z "$DISPLAY"
        if set -q DISPLAY
            test "$_ms_fish_verbose" != 1; or printf 'marksharc: x11: clearing empty DISPLAY\n' >&2
        end
        set -e -g DISPLAY
        set -e -g DISPLAY_ORIG
    else
        set -gx DISPLAY_ORIG "$DISPLAY"
        test "$_ms_fish_verbose" != 1; or printf 'marksharc: x11: DISPLAY already set to %s\n' "$DISPLAY" >&2
    end
    return 0
end
