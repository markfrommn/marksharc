# zsh-options module, init phase: the interactive option set and locale. Directory-stack
# options live in the nav module.

# The prompt is rebuilt by starship each time; keep PS1 out of children.
typeset -g +x PS1

# If terminal is xterm set xterm color
if [[ $TERM == xterm ]]; then
    TERM=xterm-256color
    export TERM
fi

unsetopt ALL_EXPORT BG_NICE
setopt MENUCOMPLETE PROMPT_SUBST notify globdots correct autolist
setopt correctall recexact longlistjobs autoresume
setopt extendedglob rcquotes mailwarning

# Keep dot files out of auto-correct
typeset -gU CORRECT_IGNORE
typeset -gU CORRECT_IGNORE_FILE
CORRECT_IGNORE='.???*'       # commands
CORRECT_IGNORE_FILE='.???*'  # arguments

# Autoload zsh modules when they are referenced
zmodload -a zsh/stat stat
zmodload -a zsh/zpty zpty
zmodload -a zsh/zprof zprof
zmodload -ap zsh/mapfile mapfile
autoload colors zsh/terminfo

# Locale. LC_ALL wins over LC_CTYPE; the old values are kept as they were.
LC_ALL='en_US.UTF-8'
LANG='en_US.UTF-8'
LC_CTYPE=C
export LANG
export BLOCKSIZE=1K

alias j='jobs -l'
true
