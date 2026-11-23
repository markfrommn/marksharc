# Native Bash PATH construction for generated environment directives.
# Indexed arrays keep this compatible with the system Bash on macOS.
_ms_bash_add() {
    local tier=${1//[^A-Za-z0-9]/_} dir=$2
    [[ -n $dir && -d $dir ]] || return 0
    case $tier in
        first) _ms_first+=("$dir") ;;
        manager) _ms_manager+=("$dir") ;;
        brew) _ms_brew+=("$dir") ;;
        system) _ms_system+=("$dir") ;;
        user) _ms_user+=("$dir") ;;
        app) _ms_app+=("$dir") ;;
        local) _ms_local+=("$dir") ;;
        last) _ms_last+=("$dir") ;;
        *) _ms_extra_tiers+=("$tier"); _ms_extra_dirs+=("$dir") ;;
    esac
}
_ms_bash_bindirs() {
    local tier=$1 base=$2 sub osarch
    [[ -d $base ]] || return 0
    case $MARKSHARC_OS in darwin) osarch=Darwin ;; linux) osarch=Linux ;; *) osarch=$MARKSHARC_OS ;; esac
    osarch=bin.$osarch.$MARKSHARC_ARCH
    for sub in bin sbin script scripts batch "bin/$osarch" "bin/$osarch/command-line-tools"; do
        _ms_bash_add "$tier" "$base/$sub"
    done
}
_ms_command_available() {
    local dir
    type -P "$1" >/dev/null 2>&1 && return 0
    [[ $1 != */* ]] || return 1
    for dir in "${_ms_first[@]}" "${_ms_manager[@]}" "${_ms_brew[@]}" "${_ms_system[@]}" "${_ms_user[@]}" "${_ms_app[@]}" "${_ms_local[@]}" "${_ms_last[@]}" "${_ms_extra_dirs[@]}"; do
        [[ -x $dir/$1 && ! -d $dir/$1 ]] && return 0
    done
    return 1
}
_ms_render_dir() { [[ -d $1 ]]; }
_ms_render_file() { [[ -e $1 ]]; }
_ms_bash_version_newer() {
    local left=${1#v} right=${2#v} a b
    local -a left_parts right_parts
    IFS=. read -r -a left_parts <<< "$left"
    IFS=. read -r -a right_parts <<< "$right"
    while (( ${#left_parts[@]} || ${#right_parts[@]} )); do
        a=${left_parts[0]:-0}; b=${right_parts[0]:-0}
        [[ $a =~ ^[0-9]+$ && $b =~ ^[0-9]+$ ]] || return 1
        (( 10#$a > 10#$b )) && return 0
        (( 10#$a < 10#$b )) && return 1
        left_parts=("${left_parts[@]:1}")
        right_parts=("${right_parts[@]:1}")
    done
    return 1
}
_ms_bash_nvm() {
    local dir=${NVM_DIR:-$HOME/.nvm} name candidate version best='' hops=0
    export NVM_DIR=$dir
    [[ -r $dir/alias/default ]] || return 0
    IFS= read -r name < "$dir/alias/default"
    while (( hops < 6 )); do
        name=${name//[[:space:]]/}
        case $name in v[0-9]*|[0-9]*|node|stable|system) break ;; esac
        [[ -r $dir/alias/$name ]] || return 0
        IFS= read -r name < "$dir/alias/$name"
        ((hops += 1))
    done
    case $name in
        node|stable) name= ;;
        system|'') return 0 ;;
        v*) name=${name#v} ;;
    esac
    for candidate in "$dir"/versions/node/v*; do
        [[ -d $candidate/bin ]] || continue
        version=${candidate##*/}; version=${version#v}
        [[ -z $name || $version == "$name" || $version == "$name".* ]] || continue
        if [[ -z $best ]] || _ms_bash_version_newer "$version" "$best"; then best=$version; fi
    done
    [[ -z $best ]] || _ms_bash_add manager "$dir/versions/node/v$best/bin"
}
_ms_bash_gvm() {
    local root=${GVM_ROOT:-$HOME/.gvm} name='' line dir version best=''
    if [[ -r $root/environments/default ]]; then
        while IFS= read -r line; do
            case $line in *gvm_go_name=*) name=${line##*gvm_go_name=}; name=${name//[\"\' ]/}; break ;; esac
        done < "$root/environments/default"
    fi
    if [[ -z $name || ! -x $root/gos/$name/bin/go ]]; then
        name=
        for dir in "$root"/gos/go*; do
            [[ -x $dir/bin/go ]] || continue
            version=${dir##*/go}
            if [[ -z $best ]] || _ms_bash_version_newer "$version" "$best"; then best=$version; name=${dir##*/}; fi
        done
    fi
    [[ -n $name && -x $root/gos/$name/bin/go ]] || return 0
    if [[ $MARKSHARC_SESSION == interactive ]]; then
        _ms_manager+=("$root/pkgsets/$name/global/bin")
        _ms_bash_add manager "$root/gos/$name/bin"
        _ms_manager+=("$root/pkgsets/$name/global/overlay/bin")
        _ms_bash_add manager "$root/bin"
    else
        _ms_bash_add manager "$root/pkgsets/$name/global/bin"
        _ms_bash_add manager "$root/gos/$name/bin"
    fi
}
_ms_bash_start() {
    local marker value
    local -a markers
    MARKSHARC_SESSION='batch'
    read -r -a markers <<< "${_ms_bash_markers:-CLAUDECODE AI_AGENT CODEX_SESSION_ID CODEX_SANDBOX OPENCODE GEMINI_CLI CURSOR_AGENT COPILOT_CLI KILO_CLI_MODE VSCODE_INJECTION VSCODE_NONCE}"
    for marker in "${markers[@]}"; do
        [[ $marker =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || continue
        value=${!marker-}
        if [[ -n $value && $value != 0 ]]; then MARKSHARC_SESSION=agent; break; fi
    done
    if [[ $MARKSHARC_SESSION == batch && $- == *i* && -t 0 && -t 1 ]]; then MARKSHARC_SESSION=interactive; fi
    export -n MARKSHARC_SESSION
    _ms_first=() _ms_manager=() _ms_brew=() _ms_system=() _ms_user=() _ms_app=() _ms_local=() _ms_last=() _ms_module_bins=() _ms_extra_tiers=() _ms_extra_dirs=()
    _ms_bash_has_gvm=0
}
_ms_bash_module() {
    local name=$1 dir=$2 base
    if [[ $dir == "$MARKSHARC_HOME/modules/$name" ]]; then case $name in
        path)
            _ms_system+=(/bin /usr/bin)
            _ms_bash_add system /sbin
            _ms_bash_add system /usr/sbin
            _ms_bash_bindirs local /usr/local
            _ms_bash_bindirs local /opt
            _ms_bash_bindirs user "$HOME"
            _ms_bash_bindirs user "$HOME/.local"
            _ms_bash_bindirs user "$HOME/usr/local"
            _ms_bash_add user "$MARKSHARC_HOME/bin"
            ;;
        go)
            local -a roots
            IFS=: read -r -a roots <<< "${GOPATH:-$HOME/go}"
            for base in "${roots[@]}"; do _ms_bash_bindirs user "$base"; done
            ;;
        rust) _ms_bash_bindirs user "${CARGO_HOME:-$HOME/.cargo}" ;;
        pnpm)
            for base in "$HOME/.local/share/pnpm" "$HOME/Library/pnpm"; do
                [[ ! -d $base ]] || export PNPM_HOME=$base
            done
            case ${_ms_bash_pnpm-} in on|1|yes|true) _ms_bash_add user "${PNPM_HOME-}" ;; esac
            ;;
        python)
            if [[ -f $HOME/.pyenv/bin/pyenv ]] && ! _ms_command_available uv; then
                export PYENV_ROOT=$HOME/.pyenv
                _ms_bash_add manager "$PYENV_ROOT/shims"
                _ms_bash_add manager "$PYENV_ROOT/bin"
            fi
            ;;
        node-nvm) _ms_bash_nvm ;;
        go-gvm) _ms_bash_gvm; _ms_bash_has_gvm=1 ;;
    esac; fi
}
_ms_bash_module_bin() {
    [[ ! -d $1/bin ]] || _ms_module_bins+=("$1/bin")
    return 0
}
_ms_bash_finish() {
    local entry tier found seen=0 oldifs=$IFS i normalized
    local -a inherited before after main result order defaults values
    _ms_bash_add user "${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/$MARKSHARC_HOST/bin"
    for entry in "${_ms_module_bins[@]}"; do _ms_bash_add user "$entry"; done
    _ms_bash_bindirs local "$HOME/.opencode"
    _ms_bash_bindirs user "$HOME/.krew"
    _ms_bash_bindirs user "$HOME/.antigravity-ide/antigravity-ide"
    if [[ $MARKSHARC_OS == darwin ]]; then defaults=(manager brew local system user app); else defaults=(manager brew system user app local); fi
    read -r -a order <<< "${_ms_bash_tiers-}"
    for tier in "${defaults[@]}"; do
        found=0
        for entry in "${order[@]}"; do [[ $entry != "$tier" ]] || found=1; done
        (( found )) || order+=("$tier")
    done
    main=()
    for tier in "${order[@]}"; do
        values=()
        case $tier in
            manager) values=("${_ms_manager[@]}") ;; brew) values=("${_ms_brew[@]}") ;;
            local) values=("${_ms_local[@]}") ;; system) values=("${_ms_system[@]}") ;;
            user) values=("${_ms_user[@]}") ;; app) values=("${_ms_app[@]}") ;;
            *)
                normalized=${tier//[^A-Za-z0-9]/_}
                for (( i = 0; i < ${#_ms_extra_tiers[@]}; i++ )); do
                    [[ ${_ms_extra_tiers[i]} != "$normalized" ]] || values+=("${_ms_extra_dirs[i]}")
                done
                ;;
        esac
        main+=("${values[@]}")
    done
    IFS=: read -r -a inherited <<< "$PATH"
    IFS=$oldifs
    before=() after=()
    for entry in "${inherited[@]}"; do
        [[ -n $entry && $entry != . ]] || continue
        found=0
        for tier in "${_ms_first[@]}" "${main[@]}" "${_ms_last[@]}"; do [[ $entry != "$tier" ]] || found=1; done
        if (( found )); then seen=1; elif (( seen )); then after+=("$entry"); else before+=("$entry"); fi
    done
    result=()
    for entry in "${_ms_first[@]}" "${before[@]}" "${main[@]}" "${after[@]}" "${_ms_last[@]}"; do
        found=0
        for tier in "${result[@]}"; do [[ $entry != "$tier" ]] || found=1; done
        (( found )) || result+=("$entry")
    done
    if [[ $EUID != 0 ]]; then case ${_ms_bash_dot-} in on|1|yes|true) result+=(.);; esac; fi
    IFS=:
    PATH="${result[*]}"
    IFS=$oldifs
    export PATH
    if [[ ${_ms_bash_has_gvm-0} == 1 ]]; then
        IFS=: read -r -a inherited <<< "$PATH"
        for entry in "${inherited[@]}"; do
            [[ -x $entry/go && ! -d $entry/go ]] || continue
            if [[ ${entry%/*/*} == "${GVM_ROOT:-$HOME/.gvm}/gos" ]]; then
                export GOROOT=${entry%/bin}
            elif [[ -n ${GOROOT-} && $entry/go != "$GOROOT/bin/go" ]]; then
                unset GOROOT
            fi
            break
        done
    fi
    case ${_ms_bash_agent_env-} in on|1|yes|true) export BASH_ENV=$MARKSHARC_HOME/core/bash/env.bash ;; esac
}
