case $1 in
    detect) [[ $WEZTERM_PANE == <-> ]] && (( $+commands[wezterm] )) ;;
    set_titles) command wezterm cli set-tab-title --pane-id "$WEZTERM_PANE" -- "$3" >/dev/null 2>&1 ;;
    refresh_env) return 0 ;;
    sessions) command wezterm cli list --format json ;;
esac
