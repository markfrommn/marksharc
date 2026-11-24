# Shared setup for fishtape units. Each test file runs in its own fish process:
#   source "$MARKSHARC_ROOT/tests/fish/support/helpers.fish"
#   ms_fixture            # private HOME, XDG dirs, stub bin first on PATH, core libs loaded
#   ms_stub NAME BODY     # executable NAME (a /bin/sh script running BODY), first on PATH
#   ms_module NAME        # run the loader's init for modules/NAME (functions, completions, init.fish)
#   ms_cleanup            # remove the fixture (call at the end of the file)
# Commands that reach the network, other hosts or real services are stubs that fail loudly
# and log to $OPLOG.
function ms_fixture
    set -gx TEST_ROOT (command mktemp -d "$TMPDIR/fish-unit.XXXXXX")
    set TEST_ROOT (path resolve -- "$TEST_ROOT")
    set -gx HOME "$TEST_ROOT/home"
    set -gx XDG_CONFIG_HOME "$HOME/config"
    set -gx XDG_CACHE_HOME "$HOME/cache"
    set -gx XDG_DATA_HOME "$HOME/data"
    set -gx XDG_STATE_HOME "$HOME/state"
    set -gx OPLOG "$TEST_ROOT/operations"
    command mkdir -p -- "$HOME" "$TEST_ROOT/bin"
    printf '' >"$OPLOG"
    set -gx PATH "$TEST_ROOT/bin" /usr/bin /bin /usr/sbin /sbin
    set -gx MARKSHARC_HOME "$MARKSHARC_ROOT"
    set -g MARKSHARC_HOST fixture
    set -g MARKSHARC_OS (string lower -- (uname -s))
    set -g MARKSHARC_SESSION interactive
    set -g _ms_fish_verbose 0
    for name in SSH_AUTH_SOCK SSH_AGENT_PID TMUX NVM_DIR GVM_ROOT BASH_ENV HERDR_SOCKET_PATH HERDR_TAB_ID HERDR_WORKSPACE_ID HERDR_PANE_ID WEZTERM_PANE HC_TERMINAL_ID INSIDE_EMACS DISPLAY
        set -e $name
    end
    for tool in curl wget sudo cwf ssh-agent ssh-add herdr collie brew gvm node npm
        ms_stub $tool 'printf "FORBIDDEN %s\n" "'$tool' $*" >>"$OPLOG"; exit 99'
    end
    for lib in directives path modules plugins cache
        source "$MARKSHARC_ROOT/core/fish/lib/$lib.fish"
    end
    builtin cd "$HOME"
end

function ms_stub --argument-names name body
    printf '#!/bin/sh\n%s\n' "$body" >"$TEST_ROOT/bin/$name"
    command chmod +x "$TEST_ROOT/bin/$name"
end

function ms_module --argument-names name
    _ms_fish_init_module "$MARKSHARC_ROOT/modules/$name"
end

function ms_cleanup
    builtin cd /
    command rm -rf -- "$TEST_ROOT"
end
