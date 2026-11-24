# node-nvm module, init phase: node switches on directory changes from the nearest .nvmrc.
# The env phase already put the default node on PATH, so node, npm and the rest work
# without nvm.sh, which is slow to source; load-nvmrc asks bash nvm only when an .nvmrc
# applies (or after leaving one). The pinned nvm.fish plugin stays as fish's nvm command.
set -l _ms_nvm_dir "$HOME/.nvm"
set -q NVM_DIR[1]; and test -n "$NVM_DIR"; and set _ms_nvm_dir "$NVM_DIR"
if test -s "$_ms_nvm_dir/nvm.sh"
    function _ms_fish_nvmrc_hook --on-variable PWD
        load-nvmrc
    end
    load-nvmrc
else
    test "$_ms_fish_verbose" = 1; and printf 'marksharc: removing the nvmrc hook\n' >&2
    functions -e _ms_fish_nvmrc_hook
end
return 0
