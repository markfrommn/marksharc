# ls module, init phase: the directive-owned family is rendered from module.conf.
# Bare ls stays native because its no-eza macOS case cannot share the fallback lines:
# eza leaves a pre-existing ls alias removed and never creates one itself.
unalias ls 2>/dev/null
if ! have_command eza; then
    if [[ ${MARKSHARC_OS-} == darwin ]]; then alias ls='ls -G'; else alias ls='ls --color=auto'; fi
fi
true
