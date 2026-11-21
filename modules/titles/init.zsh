# Register the title hook, then kick the chpwd hooks once so every module's hook (nvm, gvm,
# zoxide, ...) sees the starting directory. The title hook itself skips this kick: the
# variable is set around it and removed again (chdir-set-title honours it).
autoload -Uz add-zsh-hook
add-zsh-hook chpwd chdir-set-title
typeset -gx chdir_set_title_skip="yes"
cd .
unset chdir_set_title_skip
