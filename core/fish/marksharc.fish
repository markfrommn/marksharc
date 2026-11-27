# Fish entry point. The installer renders the shared environment before startup.
if not set -q MARKSHARC_HOME
    return
end

source "$MARKSHARC_HOME/core/fish/lib/directives.fish"
source "$MARKSHARC_HOME/core/fish/lib/cache.fish"
source "$MARKSHARC_HOME/core/fish/lib/path.fish"
source "$MARKSHARC_HOME/core/fish/lib/modules.fish"
source "$MARKSHARC_HOME/core/fish/lib/plugins.fish"
if set -q MARKSHARC_MISE_ACTIVATION_PATHS
    set -g _ms_fish_mise_activation_paths (string split : -- "$MARKSHARC_MISE_ACTIVATION_PATHS")
else
    set -g _ms_fish_mise_activation_paths
end
set -g _ms_fish_verbose 0
if set -q MARKSHARC_VERBOSE; and test -n "$MARKSHARC_VERBOSE"; and test "$MARKSHARC_VERBOSE" != 0
    set -g _ms_fish_verbose 1
end
if set -q _ms_fish_force_verbose
    set -g _ms_fish_verbose 1
end
set -l _ms_host (string split -m 1 . -- "$hostname")[1]
set -l _ms_cache_home "$HOME/.cache"
set -q XDG_CACHE_HOME; and test -n "$XDG_CACHE_HOME"; and set _ms_cache_home "$XDG_CACHE_HOME"
set -l _ms_rendered "$_ms_cache_home/marksharc/$_ms_host/env.fish"
set -l _ms_config "$HOME/.config/marksharc"
if set -q MARKSHARC_CONFIG; and test -n "$MARKSHARC_CONFIG"
    set _ms_config "$MARKSHARC_CONFIG"
else if set -q XDG_CONFIG_HOME; and test -n "$XDG_CONFIG_HOME"
    set _ms_config "$XDG_CONFIG_HOME/marksharc"
end
set -l _ms_stale 0
test -r "$_ms_rendered"; or set _ms_stale 1
if test $_ms_stale -eq 0
    for _ms_input in "$MARKSHARC_HOME"/core/** "$MARKSHARC_HOME"/modules/** "$_ms_config"/** "$_ms_config" "$MARKSHARC_HOME/core" "$MARKSHARC_HOME/modules"
        if test "$_ms_input" -nt "$_ms_rendered"
            set _ms_stale 1
            break
        end
    end
end
if test $_ms_stale -eq 1
    command zsh -f "$MARKSHARC_HOME/core/cli/render" --env-only >/dev/null 2>&1
end
set -g _ms_fish_rebuild 1
if test -r "$_ms_rendered"; and not status is-login; and not set -q _ms_fish_reloading
    begin
        read -l ignored
        read -l id_line
        set -l rendered_id (string replace -r '^# render id: ' '' -- "$id_line")
        if set -q MARKSHARC_ENV; and test -n "$rendered_id"; and test "$MARKSHARC_ENV" = "$rendered_id"
            set -g _ms_fish_rebuild 0
        end
    end <"$_ms_rendered"
end

if set -q MARKSHARC_MISE_ACTIVATION_PATHS; or set -q MARKSHARC_MISE_SHIMS; or set -q MARKSHARC_MISE_SETTINGS_ACTIVE
    set -g _ms_fish_rebuild 1
end

if not set -q _ms_fish_reloading
    set -g MARKSHARC_SESSION batch
    set -l _ms_markers CLAUDECODE AI_AGENT CODEX_SESSION_ID CODEX_SANDBOX OPENCODE GEMINI_CLI CURSOR_AGENT COPILOT_CLI KILO_CLI_MODE VSCODE_INJECTION VSCODE_NONCE
    if test -r "$_ms_rendered"
        begin
            read -l ignored
            read -l ignored
            read -l marker_line
            set -l configured (string replace -r '^# agent markers: ' '' -- "$marker_line")
            if test -n "$configured"
                set _ms_markers (string split ' ' -- "$configured")
            end
        end <"$_ms_rendered"
    end
    for _ms_marker in $_ms_markers
        string match -qr '^[A-Za-z_][A-Za-z0-9_]*$' -- "$_ms_marker"; or continue
        if set -q $_ms_marker; and test -n "$$_ms_marker"; and test "$$_ms_marker" != 0
            set -g MARKSHARC_SESSION agent
            break
        end
    end
    if test "$MARKSHARC_SESSION" = batch; and status is-interactive; and test -t 0; and test -t 1
        set -g MARKSHARC_SESSION interactive
    end
end

set -l _ms_mise_had_state 0
set -q MARKSHARC_MISE_ACTIVATION_PATHS; and set _ms_mise_had_state 1
set -q MARKSHARC_MISE_SHIMS; and set _ms_mise_had_state 1
set -q MARKSHARC_MISE_SETTINGS_ACTIVE; and set _ms_mise_had_state 1
_ms_fish_mise_drop_activation_paths
if set -q MARKSHARC_MISE_SHIMS
    _ms_fish_mise_drop_shims
end
if set -q MARKSHARC_MISE_SETTINGS_ACTIVE
    set -e -g MISE_NOT_FOUND_AUTO_INSTALL MISE_GO_SET_GOBIN MISE_IDIOMATIC_VERSION_FILE_ENABLE_TOOLS
end
set -e -g MARKSHARC_MISE_SETTINGS_ACTIVE
if test "$_ms_mise_had_state" = 1
    set -e -g MISE_SHELL MISE_NODE_VERSION MISE_GO_VERSION MISE_PYTHON_VERSION MISE_RUBY_VERSION
    set -e -g __MISE_ORIG_PATH __MISE_SESSION __MISE_DIFF
end

if test -r "$_ms_rendered"
    source "$_ms_rendered"
end
if test "$MARKSHARC_SESSION" = interactive
    # Startup prints nothing by default (spec 6.10): fish's own welcome text stays off unless
    # the user set fish_greeting. The greeting module owns any greeting.
    set -q fish_greeting; or set -g fish_greeting ''
    set -l _ms_fish_completions "$_ms_cache_home/marksharc/$_ms_host/completions/fish"
    if test -d "$_ms_fish_completions"; and not contains -- "$_ms_fish_completions" $fish_complete_path
        set -gp fish_complete_path "$_ms_fish_completions"
        set -ga _ms_fish_completion_paths "$_ms_fish_completions"
    end
    function marksharc
        if test "$argv[1]" != reload
            command "$MARKSHARC_HOME/bin/marksharc" $argv
            return $status
        end
        set -l verbose 0
        for arg in $argv[2..]
            if not contains -- "$arg" --verbose -v
                printf 'marksharc reload: unknown option: %s\n' "$arg" >&2
                return 2
            end
            set verbose 1
        end
        command "$MARKSHARC_HOME/bin/marksharc" render >/dev/null; or return 1
        for name in $_ms_fish_exports
            set -e -g "$name"
        end
        for name in $_ms_fish_aliases
            functions -e "$name"
        end
        for name in (set -n | string match '_ms_opt_*')
            set -e -g "$name"
        end
        for dir in $_ms_fish_function_paths
            set -l index (contains -i -- "$dir" $fish_function_path)
            test -n "$index"; and set -e -g fish_function_path[$index]
        end
        for dir in $_ms_fish_completion_paths
            set -l index (contains -i -- "$dir" $fish_complete_path)
            test -n "$index"; and set -e -g fish_complete_path[$index]
        end
        set -g _ms_fish_exports
        set -g _ms_fish_aliases
        set -g _ms_fish_function_paths
        set -g _ms_fish_completion_paths
        set -g _ms_fish_plugins_loaded
        set -e -g _ms_fish_gvm_root
        set -g _ms_fish_reloading 1
        for cleanup in $_ms_fish_init_cleanups
            functions -q "$cleanup"; and "$cleanup"
        end
        set -g _ms_fish_init_cleanups
        if test $verbose -eq 1
            set -g _ms_fish_force_verbose 1
        end
        _ms_fish_source_entry
        _ms_fish_forget_disabled_modules
        set -e -g _ms_fish_reloading
        set -e -g _ms_fish_force_verbose
        return 0
    end
    function cs
        marksharc reload --verbose
    end
    function li
        marksharc reload --verbose
    end
end
return 0
