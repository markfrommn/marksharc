function chdir-set-title {
    [[ -z ${chdir_set_title_skip-} && ${BASH_SUBSHELL:-0} == 0 ]] || return 0
    local mux="$MARKSHARC_HOME/modules/mux/bin/marksharc-mux" active normpwd short_host
    local toppath dirname topprint subprint tabprint paneprint cwf_sname git_repo git_branch git_path remote
    local -a parts=()
    if [[ ${SHLVL:-1} != 1 ]]; then
        active=$("$mux" detect) || return 0
        [[ -n $active && $active != plain ]] || return 0
    fi
    normpwd=$PWD
    case $normpwd in /User[s]/Shared) normpwd=/ ;; /User[s]/Shared/*) normpwd=${normpwd#*/Shared} ;; esac
    # The tilde is a literal title abbreviation.
    # shellcheck disable=SC2088
    if [[ $normpwd == "$HOME" ]]; then normpwd='~'
    elif [[ $normpwd == "$HOME/"* ]]; then normpwd='~/'${normpwd#"$HOME/"}; fi
    short_host=${HOSTNAME%%.*}
    IFS=/ read -r -a parts <<< "$normpwd"
    local slashes=${normpwd//[^\/]/}
    local count=${#slashes} n=${#parts[@]}
    if (( count < 3 )); then
        toppath=$short_host dirname=$normpwd
    else
        dirname=${parts[n-2]}/${parts[n-1]}
        if (( count == 3 )); then toppath=${parts[n-3]}
        else toppath=${parts[n-4]}/${parts[n-3]}; fi
    fi
    topprint=$dirname subprint=$toppath tabprint=$normpwd paneprint=$normpwd
    cwf_sname=$(command cwf session name 2>/dev/null) || cwf_sname=''
    if command git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        remote=$(command git remote get-url origin 2>/dev/null) || remote=''
        git_repo=${remote##*/}; git_repo=${git_repo%.git}
        if [[ -z $git_repo ]]; then
            git_repo=$(command git rev-parse --show-toplevel 2>/dev/null) || git_repo=''
            git_repo=${git_repo##*/}
        fi
        git_branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null) ||
            git_branch="detached-$(command git rev-parse --short HEAD 2>/dev/null)"
        git_path=$(command git rev-parse --show-prefix 2>/dev/null) || git_path=''
        topprint=$git_repo subprint=$dirname tabprint=$git_branch paneprint=${git_path:-$dirname}
    fi
    [[ -z $cwf_sname ]] || tabprint=$cwf_sname
    "$mux" set_titles "$topprint" "$tabprint" "$paneprint" "$subprint" bash-chdir "$SHLVL"
}
