# -*- mode: shell-script; sh-shell: zsh -*-
# Managed Carapace YAML spec wiring and lifecycle helpers (COMPLETION-SPEC section 6).
# All declarations stay inside functions so this file is safe to source from a function.

# Resolve Carapace's platform specs directory (COMPLETION-SPEC section 6.1).
#   _ms_carapace_specs_dir [os] -> sets REPLY
_ms_carapace_specs_dir() {
    emulate -L zsh
    local os=${1:-${MARKSHARC_OS-}}
    local base
    if [[ -z $os ]]; then
        case $OSTYPE in
            darwin*) os=darwin ;;
            linux*)  os=linux ;;
            *)       os=${${OSTYPE%%[0-9.-]*}:l} ;;
        esac
    fi
    if [[ -n ${XDG_CONFIG_HOME-} ]]; then
        base=$XDG_CONFIG_HOME
        while [[ $base == ?*/ ]]; do base=${base%/}; done
        REPLY=${base%/}/carapace/specs
    elif [[ $os == darwin ]]; then
        REPLY="$HOME/Library/Application Support/carapace/specs"
    else
        REPLY="$HOME/.config/carapace/specs"
    fi
}

# Read a symlink's literal target into REPLY without forking when zsh/stat is available.
_ms_carapace_readlink() {
    emulate -L zsh
    local p=$1
    local -a res=()
    REPLY=
    [[ -L $p ]] || return 1
    if zmodload -F zsh/stat b:zstat 2>/dev/null && zstat -L -A res +link -- "$p" 2>/dev/null && [[ -n ${res[1]-} ]]; then
        REPLY=${res[1]}
        return 0
    fi
    REPLY=$(command readlink "$p" 2>/dev/null) || return 1
    [[ -n $REPLY ]]
}

# Is completion-carapace enabled in the current render plan (COMPLETION-SPEC section 6.2)?
_ms_carapace_render_enabled() {
    emulate -L zsh
    (( ${_ms_plan[(Ie)completion-carapace]} )) || return 1
    local enable=${_ms_cfg_set[completion-carapace.enable]-${_ms_mod_optdef[completion-carapace.enable]-off}}
    if [[ $enable == (on|1|yes|true) ]]; then
        return 0
    fi
    if [[ ${_ms_cfg_enabled[completion-carapace]-0} == 1 && -z ${_ms_cfg_set[completion-carapace.enable]+x} ]]; then
        return 0
    fi
    return 1
}

# Reconcile managed Carapace spec symlinks against $cache/completions/carapace/*.yaml
# and maintain $cache/carapace-specs-manifest (COMPLETION-SPEC section 6.2).
_ms_carapace_reconcile_symlinks() {
    emulate -L zsh
    local cache=$1
    local carapace_cache=$cache/completions/carapace
    local manifest=$cache/carapace-specs-manifest
    local specs_dir line cmd link target cur_target tmp link_tmp
    local -a prev_links=() prev_targets=() rendered_files=() managed_lines=()
    local -A prev_target_by_link=() managed_links=()
    integer enabled=0 i

    _ms_carapace_render_enabled && enabled=1
    _ms_carapace_specs_dir "$MARKSHARC_OS"
    specs_dir=$REPLY

    if [[ -r $manifest ]]; then
        while IFS=$'\t' read -r cmd link target || [[ -n $cmd ]]; do
            [[ -n $cmd && -n $link && -n $target ]] || continue
            prev_links+=( "$link" )
            prev_targets+=( "$target" )
            prev_target_by_link[$link]=$target
        done < "$manifest"
    fi

    if (( enabled )) && [[ -d $carapace_cache ]]; then
        rendered_files=( "$carapace_cache"/*.yaml(N-.) )
        rendered_files=( ${(o)rendered_files} )
        if (( $#rendered_files )); then
            [[ -d $specs_dir ]] || command mkdir -p -- "$specs_dir" || {
                print -ru2 -- "marksharc render: could not create Carapace specs directory: $specs_dir"
                return 1
            }
            for target in "${rendered_files[@]}"; do
                cmd=${target:t:r}
                link=$specs_dir/$cmd.yaml
                if [[ ! -e $link && ! -L $link ]]; then
                    if command ln -s -- "$target" "$link"; then
                        managed_links[$link]=$target
                        managed_lines+=( "$cmd"$'\t'"$link"$'\t'"$target" )
                    else
                        print -ru2 -- "marksharc render: warning: could not link Carapace spec at $link"
                    fi
                elif [[ -L $link ]]; then
                    _ms_carapace_readlink "$link" || REPLY=
                    cur_target=$REPLY
                    if [[ $cur_target == "$target" ]]; then
                        managed_links[$link]=$target
                        managed_lines+=( "$cmd"$'\t'"$link"$'\t'"$target" )
                    elif [[ $cur_target == "$carapace_cache/"* ]] ||
                         [[ -n ${prev_target_by_link[$link]-} && $cur_target == "${prev_target_by_link[$link]}" ]]; then
                        link_tmp=$link.marksharc.tmp.$$
                        if command ln -s -- "$target" "$link_tmp" && command mv -f -- "$link_tmp" "$link"; then
                            managed_links[$link]=$target
                            managed_lines+=( "$cmd"$'\t'"$link"$'\t'"$target" )
                        else
                            command rm -f -- "$link_tmp" 2>/dev/null
                            print -ru2 -- "marksharc render: warning: could not update Carapace spec symlink at $link"
                        fi
                    else
                        print -ru2 -- "marksharc render: warning: keeping non-MarkSharc Carapace spec at $link (skipping managed spec for $cmd)"
                    fi
                else
                    print -ru2 -- "marksharc render: warning: keeping non-MarkSharc Carapace spec at $link (skipping managed spec for $cmd)"
                fi
            done
        fi
    fi

    # Prune stale symlinks from the previous manifest only if still pointing to our recorded target.
    for (( i = 1; i <= $#prev_links; i++ )); do
        link=${prev_links[i]}
        target=${prev_targets[i]}
        [[ -n ${managed_links[$link]-} ]] && continue
        if [[ -L $link ]] && _ms_carapace_readlink "$link" && [[ $REPLY == "$target" ]]; then
            command rm -f -- "$link"
        fi
    done

    if (( $#managed_lines )); then
        tmp=$manifest.tmp.$$
        if print -rl -- "${managed_lines[@]}" > "$tmp" && command mv -f -- "$tmp" "$manifest"; then
            return 0
        fi
        command rm -f -- "$tmp" 2>/dev/null
        return 1
    else
        command rm -f -- "$manifest" 2>/dev/null || :
    fi
    return 0
}
