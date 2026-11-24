# Optional native activation; callers may supply an explicit installed location.
# "brew shellenv" prints nothing when PATH already starts with the brew directories,
# so it is generated under a fixed minimal PATH (the cached text is then always
# complete). Sourcing it moves brew's directories to the front of PATH; the user's
# existing PATH order is kept and only directories that were absent go to the front.
# A reload leaves the shell's brew environment alone.
function setup-homebrew --description 'Activate Homebrew from its cached shellenv'
    set -l candidates $argv
    set -q candidates[1]; or set candidates /usr/local/bin/brew /opt/homebrew/bin/brew /home/linuxbrew/.linuxbrew/bin/brew
    for brew in $candidates
        if test -x "$brew"; and not test -d "$brew"
            set -q _ms_fish_reloading; and return 0
            set -l saved $PATH
            _ms_fish_init_cached -P /usr/bin:/bin:/usr/sbin:/sbin brew "$brew" shellenv fish
            set -l result $status
            set -l added
            for dir in $PATH
                contains -- "$dir" $saved; or set -a added "$dir"
            end
            set -gx PATH $added $saved
            return $result
        end
    end
    return 0
end
