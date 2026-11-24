# chdir-set-title: label the tab (and herdr workspace and pane) from the working directory,
# the git repository and branch, and the cwf session name. Skipped inside a herdr core
# terminal, in nested shells (SHLVL other than 1), and while chdir_set_title_skip is set.
function chdir-set-title --description 'Set tab and pane titles from the working directory'
    test -z "$HC_TERMINAL_ID"; or return 0
    test "$SHLVL" = 1; or return 0
    test -z "$chdir_set_title_skip"; or return 0

    # The last two directories stay informative without being verbose; in a worktree the
    # repository name takes the top line.
    set -l short_host (string split -m 1 . -- "$hostname")[1]
    # The macOS shared-folder prefix (written [s] so the personal-value lint reads it as a pattern).
    set -l normpwd (string replace -r '^/User[s]/Shared(/|$)' / -- "$PWD")
    if test "$normpwd" = "$HOME"
        set normpwd '~'
    else if string match -q -- "$HOME/*" "$normpwd"
        set normpwd '~/'(string sub -s (math (string length -- "$HOME") + 2) -- "$normpwd")
    end
    set -l slashcount (string length -- (string replace -a -r '[^/]' '' -- "$normpwd"))
    set -l parts (string match -v -- '' (string split / -- "$normpwd"))
    set -l toppath
    set -l dirname
    if test $slashcount -lt 3
        set toppath "$short_host"
        set dirname "$normpwd"
    else if test $slashcount -eq 3
        set toppath (string join / -- $parts[-3])
        set dirname (string join / -- $parts[-2..-1])
    else
        set toppath (string join / -- $parts[-4..-3])
        set dirname (string join / -- $parts[-2..-1])
    end

    set -l topprint "$dirname"
    set -l subprint "$toppath"
    set -l tabprint "$normpwd"
    set -l paneprint "$normpwd"

    set -l cwf_sname
    if command -sq cwf
        set cwf_sname (command cwf session name 2>/dev/null)
        or set cwf_sname
        set cwf_sname "$cwf_sname[1]"
    end

    if command git rev-parse --is-inside-work-tree >/dev/null 2>&1
        set -l git_remote (command git remote get-url origin 2>/dev/null)
        set -l git_repo
        test -z "$git_remote"; or set git_repo (string replace -r '\.git$' '' -- (path basename -- "$git_remote"))
        test -n "$git_repo"; or set git_repo (path basename -- (command git rev-parse --show-toplevel))
        set -l git_branch (command git symbolic-ref --quiet --short HEAD 2>/dev/null)
        test -n "$git_branch"; or set git_branch detached-(command git rev-parse --short HEAD 2>/dev/null)
        set -l git_path (command git rev-parse --show-prefix 2>/dev/null)
        set topprint "$git_repo"
        set subprint "$dirname"
        set tabprint "$git_branch"
        set paneprint "$git_path"
        test -n "$paneprint"; or set paneprint "$dirname"
    end
    test -z "$cwf_sname"; or set tabprint "$cwf_sname"

    # herdr first: it may itself run inside wezterm.
    if test -n "$HERDR_TAB_ID"
        if type -q herdr
            set -l source_name fish-chdir
            herdr workspace report-metadata "$HERDR_WORKSPACE_ID" --source "$source_name" --token topname="$topprint-rm" >/dev/null 2>&1
            herdr workspace report-metadata "$HERDR_WORKSPACE_ID" --source "$source_name" --token subname="$subprint" >/dev/null 2>&1
            herdr workspace rename "$HERDR_WORKSPACE_ID" "$topprint" >/dev/null 2>&1
            herdr tab rename "$HERDR_TAB_ID" "$tabprint" >/dev/null 2>&1
            herdr pane rename "$HERDR_PANE_ID" "$paneprint" >/dev/null 2>&1
        end
    else if test -n "$WEZTERM_PANE"
        if type -q wezterm
            wezterm cli set-tab-title "$tabprint"
        end
    else
        set-title "$tabprint"
    end
    return 0
end
