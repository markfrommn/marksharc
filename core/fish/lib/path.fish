# Managed PATH tiers, in the same order as the zsh path module.
function _ms_fish_command_available
    command -sq -- "$argv[1]"; and return 0
    string match -q '*/*' -- "$argv[1]"; and return 1
    for variable in $_ms_fish_tier_variables
        for dir in $$variable
            if test -x "$dir/$argv[1]"; and not test -d "$dir/$argv[1]"
                return 0
            end
        end
    end
    return 1
end

function _ms_fish_path_add_force
    set -l tier (string replace -a -r '[^A-Za-z0-9]' _ -- "$argv[1]")
    set -l variable _ms_fish_tier_$tier
    contains -- "$variable" $_ms_fish_tier_variables; or set -ga _ms_fish_tier_variables "$variable"
    for entry in $argv[2..]
        contains -- "$entry" $$variable; or set -ga $variable "$entry"
    end
end

function _ms_fish_path_add
    set -l tier $argv[1]
    for entry in $argv[2..]
        test -d "$entry"; and _ms_fish_path_add_force "$tier" "$entry"
    end
end

function _ms_fish_path_add_bindirs
    set -l tier $argv[1]
    for base in $argv[2..]
        test -d "$base"; or continue
        for sub in bin sbin script scripts batch bin/bin.(string upper (string sub -l 1 $MARKSHARC_OS))(string sub -s 2 $MARKSHARC_OS).$MARKSHARC_ARCH bin/bin.(string upper (string sub -l 1 $MARKSHARC_OS))(string sub -s 2 $MARKSHARC_OS).$MARKSHARC_ARCH/command-line-tools
            _ms_fish_path_add "$tier" "$base/$sub"
        end
    end
end

function _ms_fish_path_begin
    for variable in $_ms_fish_tier_variables
        set -e -g "$variable"
    end
    set -g _ms_fish_tier_variables
    for tier in first manager brew local system user app last
        set -g _ms_fish_tier_$tier
    end
    set -g _ms_fish_tier_order (string split ' ' -- "$argv[1]")
    _ms_fish_path_add_force system /bin /usr/bin
    _ms_fish_path_add system /sbin /usr/sbin
    _ms_fish_path_add_bindirs local /usr/local /opt
    _ms_fish_path_add_bindirs user "$HOME" "$HOME/.local" "$HOME/usr/local"
    _ms_fish_path_add user "$MARKSHARC_HOME/bin"
end

function _ms_fish_path_build
    _ms_fish_path_add_bindirs local "$HOME/.opencode"
    _ms_fish_path_add_bindirs user "$HOME/.krew" "$HOME/.antigravity-ide/antigravity-ide"
    set -l defaults manager brew system user app local
    if test "$MARKSHARC_OS" = darwin
        set defaults manager brew local system user app
    end
    set -l order
    for tier in $_ms_fish_tier_order $defaults
        if test -n "$tier"; and not contains -- "$tier" first last $order
            set -a order $tier
        end
    end
    set -l managed
    for tier in $order
        set -l tier_key (string replace -a -r '[^A-Za-z0-9]' _ -- "$tier")
        set -l variable _ms_fish_tier_$tier_key
        set -a managed $$variable
    end
    if test "$_ms_fish_verbose" = 1
        for tier in first $order last
            set -l tier_key (string replace -a -r '[^A-Za-z0-9]' _ -- "$tier")
            set -l variable _ms_fish_tier_$tier_key
            set -l entries (string join : -- $$variable)
            printf 'marksharc: PATH tier %s: %s\n' "$tier" "$entries" >&2
        end
    end
    set -l prefix
    set -l suffix
    set -l seen 0
    for entry in $PATH
        test -n "$entry"; and test "$entry" != .; or continue
        if contains -- "$entry" $managed $_ms_fish_tier_first $_ms_fish_tier_last $_ms_fish_managed
            contains -- "$entry" $_ms_fish_tier_first; or set seen 1
        else if test $seen -eq 0
            set -a prefix "$entry"
        else
            set -a suffix "$entry"
        end
    end
    set -g _ms_fish_managed $_ms_fish_tier_first $managed $_ms_fish_tier_last
    set -l result
    for entry in $_ms_fish_tier_first $prefix $managed $suffix $_ms_fish_tier_last
        contains -- "$entry" $result; or set -a result "$entry"
    end
    if test "$EUID" != 0; and contains -- "$_ms_fish_dot_in_path" on 1 yes true
        contains -- . $result; or set -a result .
    end
    set -gx PATH $result
    _ms_fish_gvm_finalize
    return 0
end
