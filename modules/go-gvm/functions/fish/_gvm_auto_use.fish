# Switch Go on directory change from the go directive of go.mod.
function _gvm_auto_use
    test -f go.mod; or return 0
    set -l go_ver ''
    while read -l line
        if string match -qr '^go [0-9]+\.[0-9]+' -- "$line"
            set go_ver go(string split -n ' ' -- "$line")[2]
            break
        end
    end <go.mod
    if test -n "$go_ver"; and test "$go_ver" != "$gvm_go_name"
        gvm use "$go_ver" >/dev/null 2>&1; or echo "GVM: $go_ver is not installed."
    end
    return 0
end
