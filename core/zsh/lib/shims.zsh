# Generated executable shims. Provider files are data, never shell programs.
_ms_provider_read() {
    emulate -L zsh
    setopt extendedglob
    local file=$1 line key stripped
    typeset -gA _ms_provider_values=()
    while IFS= read -r line || [[ -n $line ]]; do
        stripped=${line##[[:space:]]#}
        [[ -z $stripped || $stripped == \#* ]] && continue
        _ms_words "$line" || { print -ru2 "Invalid provider line in $file"; return 1; }
        (( ${#reply} == 3 )) && [[ $reply[1] == env && $reply[2] =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || {
            print -ru2 "Invalid provider directive in $file"; return 1
        }
        key=$reply[2]
        _ms_provider_values[$key]=$reply[3]
    done < "$file"
}

_ms_shims_render() {
    emulate -L zsh
    local stage=$1 dir file pname name row session state pid socket collie='' module output
    local -a rows
    for module in $_ms_plan; do
        case $module in
            cc-providers)
                dir=${_ms_cfg_set[cc-providers.dir]-${_ms_mod_optdef[cc-providers.dir]-}}
                [[ -n $dir ]] || dir=${MARKSHARC_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/marksharc}/providers
                for file in "$dir"/*.conf(N-.); do
                    pname=${${file:t}%.conf}
                    [[ $pname =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] || { print -ru2 "Invalid provider name: ${file:t}"; return 1; }
                    _ms_provider_read "$file" || return 1
                    for name in claude${pname} models${pname}; do
                        [[ ! -e $stage/$name ]] || return 1
                        print -rl -- '#!/bin/zsh -f' "exec ${(q)_ms_mod_dir[cc-providers]}/bin/provider ${(q)MARKSHARC_HOME} ${(q)file} ${(q)name} \"\$@\"" > "$stage/$name" || return 1
                        chmod 700 "$stage/$name" || return 1
                    done
                done
                ;;
            herdr)
                command -v herdr >/dev/null 2>&1 || continue
                if command -v collie >/dev/null 2>&1; then collie=$(command -v collie); fi
                if [[ ! -x $collie ]]; then
                    local -a candidates=( "$HOME"/.config/**/collie-ctl.sh(N-.x) )
                    collie=${candidates[1]-}
                fi
                output=$(command herdr session list) || return 1
                rows=( "${(@f)output}" )
                for row in "${rows[@]:1}"; do
                    [[ -n ${row//[[:space:]]/} ]] || continue
                    read -r session state pid socket <<< "$row"
                    [[ $session =~ '^[A-Za-z0-9_.-]+$' && -n $socket ]] || { print -ru2 'Unsupported Herdr session row'; return 1; }
                    name=herdr-$session
                    [[ ! -e $stage/$name ]] || return 1
                    print -rl -- '#!/bin/zsh -f' "exec herdr session attach ${(q)session} \"\$@\"" > "$stage/$name" || return 1
                    chmod 700 "$stage/$name" || return 1
                    if [[ -n $collie ]]; then
                        name=collie-$session
                        [[ ! -e $stage/$name ]] || return 1
                        print -rl -- '#!/bin/zsh -f' "export HERDR_SOCKET_PATH=${(q)socket}" "exec ${(q)collie} \"\$@\"" > "$stage/$name" || return 1
                        chmod 700 "$stage/$name" || return 1
                    fi
                done
                ;;
        esac
    done
}
