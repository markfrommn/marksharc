# ls module, init phase: one definition per alias. With eza the family uses it; bare ls
# is left alone so scripts that run ls keep its output. Without eza, ls itself gets
# colour (GNU --color on Linux, BSD -G on macOS).
unalias ls 2>/dev/null
if have_command eza; then
    alias dir='eza -l' lsf='eza -F' la='eza -a' lf='eza -FA' ll='eza -lA'
else
    if [[ ${ostype-} == Darwin ]]; then alias ls='ls -G'; else alias ls='ls --color=auto'; fi
    alias dir='ls -l' lsf='ls -F' la='ls -a' lf='ls -FA' ll='ls -lA'
fi
true
