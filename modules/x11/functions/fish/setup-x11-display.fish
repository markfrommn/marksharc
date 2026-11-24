function setup-x11-display --description 'Refresh DISPLAY and record it as DISPLAY_ORIG'
    set -l mode display
    if test "$argv[1]" = --startup
        set mode display-startup
    end
    _ms_fish_run_with_directives "$MARKSHARC_HOME/modules/mux/bin/marksharc-mux" refresh_env "$mode"; or return
    if test "$_ms_fish_verbose" = 1; and test -n "$DISPLAY"
        printf 'marksharc: x11: DISPLAY already set to %s\n' "$DISPLAY" >&2
    end
    return 0
end
