# mise module, interactive init: cached native activation plus thin nvm/gvm compatibility.
# The env phase owns safe settings and shims; this phase owns only functions it created.

# Erasing an inline function makes fish suppress later autoloads of that name. After a
# compatibility function is removed, restore the real definition as soon as its module or
# plugin has put its autoload directory back on fish_function_path.
function _ms_fish_mise_restore_autoload --argument-names name
    set -l flag _ms_fish_mise_restore_$name
    set -q $flag; or return 0
    if functions -q "$name"
        set -e -g "$flag"
        return 0
    end
    for dir in $fish_function_path
        if test -r "$dir/$name.fish"
            source "$dir/$name.fish"
            if functions -q "$name"
                set -e -g "$flag"
            end
            return 0
        end
    end
    return 0
end

# Remove a compatibility function only while its body is still the one mise installed.
# A real manager or another module may have replaced it since the last reload.
function _ms_fish_mise_drop_compat --argument-names name
    set -l active _ms_fish_mise_compat_$name
    set -l definition _ms_fish_mise_compat_definition_$name
    set -q $active; or return 1
    set -l result 1
    if functions -q "$name"
        set -l current (functions "$name" | string collect)
        if test "$current" = "$$definition"
            functions -e "$name"
            set -g _ms_fish_mise_restore_$name 1
            set result 0
        end
    end
    set -e -g "$active"
    set -e -g "$definition"
    return $result
end

function _ms_fish_mise_compat_hint --argument-names manager tool
    printf '%s: unsupported operation; use the corresponding mise command:\n' "$manager" >&2
    printf '  mise shell %s@<version>\n' "$tool" >&2
    printf '  mise install %s@<version>\n' "$tool" >&2
    printf '  mise ls %s\n' "$tool" >&2
    printf '  mise current %s\n' "$tool" >&2
    printf '  mise use --global %s@<version>\n' "$tool" >&2
    return 2
end

function _ms_fish_mise_clear_activation
    set -l had_state 0
    set -q MARKSHARC_MISE_ACTIVATION_PATHS; and set had_state 1
    set -q MARKSHARC_MISE_SHIMS; and set had_state 1
    set -q MARKSHARC_MISE_SETTINGS_ACTIVE; and set had_state 1
    set -q _ms_fish_mise_wrapper_active; and set had_state 1
    set -q _ms_fish_mise_cnf_tracked; and set had_state 1
    set -q _ms_fish_mise_eval; and set had_state 1
    test "$had_state" = 1; or return 0
    _ms_fish_mise_drop_activation_paths
    for fn in __mise_env_eval_on_prompt __mise_cd_hook __mise_env_eval __mise_env_eval_2 _ms_fish_mise_eval
        functions -q "$fn"; and functions -e "$fn"
    end
    if set -q _ms_fish_mise_cnf_tracked; and functions -q fish_command_not_found
        set -l current (functions fish_command_not_found | string collect)
        if test "$current" = "$_ms_fish_mise_cnf_definition"
            functions -e fish_command_not_found
            if functions -q __mise_fish_command_not_found
                functions -c __mise_fish_command_not_found fish_command_not_found
            else if functions -q __fish_default_command_not_found_handler
                functions -c __fish_default_command_not_found_handler fish_command_not_found
            else
                functions -e fish_command_not_found
            end
        end
    end
    functions -e __mise_fish_command_not_found
    set -e -g _ms_fish_mise_cnf_tracked _ms_fish_mise_cnf_definition
    set -e -g MISE_SHELL MISE_NODE_VERSION MISE_GO_VERSION MISE_PYTHON_VERSION MISE_RUBY_VERSION
    set -e -g __MISE_ORIG_PATH __MISE_SESSION __mise_skip_first_prompt_pwd __mise_env_again
    if set -q _ms_fish_mise_wrapper_active
        if functions -q mise
            set -l current (functions mise | string collect)
            if test "$current" = "$_ms_fish_mise_wrapper_definition"
                functions -e mise
                if functions -q _ms_fish_mise_saved_mise
                    functions -c _ms_fish_mise_saved_mise mise
                end
            end
        end
        set -e -g _ms_fish_mise_wrapper_active
        set -e -g _ms_fish_mise_wrapper_definition
    end
    functions -e _ms_fish_mise_native _ms_fish_mise_saved_mise
    return 0
end

function _ms_fish_mise_reload_cleanup
    _ms_fish_mise_drop_compat nvm
    _ms_fish_mise_drop_compat gvm
    _ms_fish_mise_clear_activation
    return 0
end
set -ga _ms_fish_init_cleanups _ms_fish_mise_reload_cleanup

set -l _ms_mise_owned
for _ms_mise_tool in node go python ruby
    if _ms_fish_mise_owns "$_ms_mise_tool"
        set -a _ms_mise_owned "$_ms_mise_tool"
    end
end
set -l _ms_mise_compat 0
contains -- "$_ms_opt_mise_compat" on 1 yes true; and set _ms_mise_compat 1

# Node compatibility. An already loaded real nvm is left alone, matching the other shells.
_ms_fish_mise_drop_compat nvm
set -l _ms_mise_nvm_dropped $status
if contains -- node $_ms_mise_owned; and test "$_ms_mise_compat" = 1
    set -e -g _ms_fish_mise_restore_nvm
    if not functions -q nvm
        function nvm --description 'Translate common nvm commands to mise'
            switch "$argv[1]"
                case use
                    if not set -q argv[2]
                        _ms_fish_mise_compat_hint nvm node
                        return 2
                    end
                    mise shell "node@$argv[2]" $argv[3..]
                case install
                    if not set -q argv[2]
                        _ms_fish_mise_compat_hint nvm node
                        return 2
                    end
                    mise install "node@$argv[2]" $argv[3..]
                case ls
                    mise ls node $argv[2..]
                case current
                    mise current node $argv[2..]
                case alias
                    if test "$argv[2]" = default; and set -q argv[3]
                        mise use --global "node@$argv[3]" $argv[4..]
                    else
                        _ms_fish_mise_compat_hint nvm node
                        return 2
                    end
                case '*'
                    _ms_fish_mise_compat_hint nvm node
                    return 2
            end
        end
        set -g _ms_fish_mise_compat_nvm 1
        set -g _ms_fish_mise_compat_definition_nvm (functions nvm | string collect)
    end
else if not contains -- node $_ms_mise_owned
    if test "$_ms_mise_nvm_dropped" = 0
        set -g _ms_fish_mise_restore_nvm 1
    end
    _ms_fish_mise_restore_autoload nvm
end

# Go compatibility. Only the version argument loses gvm's conventional "go" prefix;
# every remaining argument reaches mise literally.
_ms_fish_mise_drop_compat gvm
set -l _ms_mise_gvm_dropped $status
if contains -- go $_ms_mise_owned; and test "$_ms_mise_compat" = 1
    set -e -g _ms_fish_mise_restore_gvm
    if not functions -q gvm
        function gvm --description 'Translate common gvm commands to mise'
            switch "$argv[1]"
                case use
                    if not set -q argv[2]
                        _ms_fish_mise_compat_hint gvm go
                        return 2
                    end
                    set -l tool_version (string replace -r '^go' '' -- "$argv[2]")
                    mise shell "go@$tool_version" $argv[3..]
                case install
                    if not set -q argv[2]
                        _ms_fish_mise_compat_hint gvm go
                        return 2
                    end
                    set -l tool_version (string replace -r '^go' '' -- "$argv[2]")
                    mise install "go@$tool_version" $argv[3..]
                case ls list
                    mise ls go $argv[2..]
                case current
                    mise current go $argv[2..]
                case alias
                    if test "$argv[2]" = default; and set -q argv[3]
                        set -l tool_version (string replace -r '^go' '' -- "$argv[3]")
                        mise use --global "go@$tool_version" $argv[4..]
                    else
                        _ms_fish_mise_compat_hint gvm go
                        return 2
                    end
                case '*'
                    _ms_fish_mise_compat_hint gvm go
                    return 2
            end
        end
        set -g _ms_fish_mise_compat_gvm 1
        set -g _ms_fish_mise_compat_definition_gvm (functions gvm | string collect)
    end
else if not contains -- go $_ms_mise_owned
    if test "$_ms_mise_gvm_dropped" = 0
        set -g _ms_fish_mise_restore_gvm 1
    end
    _ms_fish_mise_restore_autoload gvm
end

if set -q _ms_mise_owned[1]; and test "$_ms_opt_mise_hook" != off
    # Preserve a pre-existing function only before the first activation. On reload the
    # current function is our wrapper, while the original remains saved separately.
    if not set -q _ms_fish_mise_wrapper_active; and functions -q mise
        functions -e _ms_fish_mise_saved_mise
        functions -c mise _ms_fish_mise_saved_mise
    end
    set -l _ms_mise_before_activation $PATH
    _ms_fish_init_cached -k "$_ms_opt_mise_auto_install|"(string join : $PATH) mise mise activate fish
    if test $status -eq 0; and functions -q mise
        functions -e _ms_fish_mise_eval
        functions -c __mise_env_eval _ms_fish_mise_eval
        function __mise_env_eval
            set -l before $PATH
            _ms_fish_mise_eval $argv
            set -l result $status
            if set -q _ms_fish_tier_variables
                _ms_fish_path_build
            end
            _ms_fish_mise_track_activation_paths $before
            return $result
        end
        function __mise_cd_hook --on-variable PWD
            __mise_env_eval
        end
        set -g _ms_fish_mise_cnf_tracked 1
        set -g _ms_fish_mise_cnf_definition (functions fish_command_not_found | string collect)
        functions -e _ms_fish_mise_native
        functions -c mise _ms_fish_mise_native
        function mise --description 'mise with immediate environment refreshes'
            _ms_fish_mise_native $argv
            set -l result $status
            if test $result -eq 0; and test "$argv[1]" = deactivate
                _ms_fish_mise_clear_activation
            else if test $result -eq 0; and contains -- "$argv[1]" shell sh use unuse
                if functions -q __mise_env_eval
                    __mise_env_eval
                end
            end
            return $result
        end
        set -g _ms_fish_mise_wrapper_active 1
        set -g _ms_fish_mise_wrapper_definition (functions mise | string collect)
        if test "$_ms_opt_mise_hook" != prompt
            functions -e __mise_env_eval_on_prompt
        end
        # auto-install-off activation can remove the shim path that env just built.
        if set -q _ms_fish_tier_variables
            _ms_fish_path_build
        end
        _ms_fish_mise_track_activation_paths $_ms_mise_before_activation
    else
        _ms_fish_mise_clear_activation
    end
else
    _ms_fish_mise_clear_activation
end

return 0
