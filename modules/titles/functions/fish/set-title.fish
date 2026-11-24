function set-title --description 'Set the terminal tab, window and combined titles'
    set -lx TERM "$TERM"
    set -lx TERM_PROGRAM "$TERM_PROGRAM"
    set -lx INSIDE_EMACS "$INSIDE_EMACS"
    command "$MARKSHARC_HOME/modules/mux/bin/marksharc-mux" terminal_title $argv
end
