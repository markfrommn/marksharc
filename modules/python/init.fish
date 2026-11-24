# python module, init phase: uv is preferred; without it, pyenv's cached init output.
# The env phase already put the shims and bin directories on PATH. A reload keeps the
# shell's existing pyenv setup and only repeats the cheap variable work.
if _ms_fish_command_available uv
    test "$_ms_fish_verbose" = 1; and printf 'marksharc: uv found, preferring it to pyenv\n' >&2
else if test -f "$HOME/.pyenv/bin/pyenv"
    set -gx PYENV_ROOT "$HOME/.pyenv"
    contains -- "$PYENV_ROOT/bin" $PATH; or set -ga PATH "$PYENV_ROOT/bin"
    if not set -q _ms_fish_reloading
        _ms_fish_init_cached -k "$PYENV_ROOT" pyenv pyenv init - fish
        if _ms_fish_command_available pyenv; or functions -q pyenv
            # pyenv-virtualenv may be a plugin or a system package: ask pyenv.
            if command pyenv commands 2>/dev/null | string match -q '*virtualenv-init*'
                _ms_fish_init_cached -k "$PYENV_ROOT" pyenv pyenv virtualenv-init - fish
            end
        end
    end
end
return 0
