# titles module, init phase: label the tab on every directory change. As in zsh, startup
# itself sets no title, so a new shell runs no git or cwf query for it.
# fish_title prints nothing, so fish writes no OSC 0 title and leaves the tab title that
# chdir-set-title set alone. Redefining the named handler on reload replaces it.
function _ms_titles_on_pwd --on-variable PWD
    chdir-set-title
end

function fish_title
end
_ms_fish_track_functions fish_title

true
