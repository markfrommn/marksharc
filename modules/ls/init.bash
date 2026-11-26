# The declarative family aliases come from module.conf.
unalias ls 2>/dev/null || :
if ! type -P eza >/dev/null; then
    if [[ ${MARKSHARC_OS-} == darwin ]]; then alias ls='ls -G'; else alias ls='ls --color=auto'; fi
fi
:
