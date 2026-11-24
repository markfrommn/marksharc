# A version of diff that colours for less -R automatically.
function diffcp --wraps diff --description 'Coloured diff in less'
    command diff --color=always $argv | command less -R
end
