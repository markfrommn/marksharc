if test "$MARKSHARC_SESSION" = interactive; and test -n "$LAUNCH_RUN"
    function _ms_launch_run --on-event fish_prompt
        functions -e _ms_launch_run
        set -l payload "$LAUNCH_RUN"
        set -l replace_shell "$LAUNCH_RUN_EXEC"
        set -e -g LAUNCH_RUN LAUNCH_RUN_EXEC
        test -n "$payload"; or return 0

        set -l words
        for field in (string split \t -- "$payload")
            # Collect the decoded word and remove only string replace's final newline.
            set -l raw (string replace -a '%0A' \n -- "$field" | string replace -a '%09' \t | string replace -a '%25' '%' | string collect -N)
            set -a words (string split -r -m 1 -f 1 \n -- "$raw")
        end
        test -n "$words[1]"; or return 0
        if test "$replace_shell" = 1
            exec $words
            exit $status
        end
        $words
    end
end
