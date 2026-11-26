_ms_titles_first_pwd=1
_ms_titles_on_pwd() {
    if [[ ${_ms_titles_first_pwd-} == 1 ]]; then
        unset _ms_titles_first_pwd
        return 0
    fi
    chdir-set-title
}
_ms_bash_register_chpwd _ms_titles_on_pwd
