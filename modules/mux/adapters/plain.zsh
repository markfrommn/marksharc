mux_terminal_title() {
    [[ -n $INSIDE_EMACS && $INSIDE_EMACS != vterm ]] && return 0
    local tab=${1//[[:cntrl:]]/} window=${2//[[:cntrl:]]/} combined=${3//[[:cntrl:]]/}
    case $TERM in
        screen*|tmux*)
            [[ -z $combined ]] || printf '\033]0;%s\033\\' "$combined"
            [[ -z $window ]] || printf '\033]2;%s\033\\' "$window"
            printf '\033k%s\033\\' "$tab" ;;
        cygwin|xterm*|putty*|rxvt*|konsole*|ansi|mlterm*|alacritty*|st*|foot*|contour*|wezterm*|nsterm*)
            [[ -z $combined ]] || printf '\033]0;%s\007' "$combined"
            [[ -z $window ]] || printf '\033]2;%s\007' "$window"
            printf '\033]1;%s\007' "$tab" ;;
        *)
            if [[ $TERM_PROGRAM == (iTerm.app|Apple_Terminal) ]]; then
                [[ -z $combined ]] || printf '\033]0;%s\007' "$combined"
                [[ -z $window ]] || printf '\033]2;%s\007' "$window"
                printf '\033]1;%s\007' "$tab"
            elif zmodload zsh/terminfo 2>/dev/null && (( ${+terminfo[fsl]} && ${+terminfo[tsl]} )); then
                echoti tsl 0; printf '%s' "$tab"; echoti fsl
            fi ;;
    esac
    return 0
}

case $1 in
    detect) [[ -n $TERM && $TERM != dumb || $TERM_PROGRAM == (iTerm.app|Apple_Terminal) ]] ;;
    set_titles) mux_terminal_title "$3" ;;
    terminal_title) mux_terminal_title "${@:2}" ;;
    refresh_env|sessions) return 0 ;;
esac
