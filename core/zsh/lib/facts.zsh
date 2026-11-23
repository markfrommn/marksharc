# -*- mode: shell-script; sh-shell: zsh -*-
# Host facts from shell builtins and files read with builtins (spec 6.6).
# _ms_fs_root is a test seam: a prefix for the files read below (default "").

_ms_facts() {
    emulate -L zsh
    local root=${_ms_fs_root-} line kernel

    # Modernization removes the old compatibility names, including on reload in a
    # shell that still has values from an earlier core.
    unset ostype hwtype shorthost distro dname
    case $OSTYPE in
        darwin*) MARKSHARC_OS=darwin ;;
        linux*)  MARKSHARC_OS=linux ;;
        *)       kernel=${OSTYPE%%[0-9.-]*}; MARKSHARC_OS=${kernel:l} ;;
    esac
    MARKSHARC_ARCH=$CPUTYPE
    hname=$HOST
    MARKSHARC_HOST=${HOST%%.*}
    hostbase=${MARKSHARC_HOST%%-*}
    idcmd=/usr/bin/id
    if [[ $MARKSHARC_OS == darwin ]]; then statfmtarg=-f; else statfmtarg=-c; fi

    # Linux distribution: a redhat-release file wins, then os-release ID.
    if [[ $MARKSHARC_OS == linux ]]; then
        if [[ -f $root/etc/redhat-release ]]; then
            MARKSHARC_DISTRO=redhat
        else
            MARKSHARC_DISTRO=unknown
            if [[ -r $root/etc/os-release ]]; then
                while IFS= read -r line; do
                    if [[ $line == ID=* ]]; then MARKSHARC_DISTRO=${${${line#ID=}//[\"\']/}:l}; break; fi
                done < "$root/etc/os-release"
            fi
        fi
    elif [[ $MARKSHARC_OS == darwin ]]; then
        MARKSHARC_DISTRO=macos
    else
        MARKSHARC_DISTRO=$MARKSHARC_OS
    fi

    # Site naming lives in per-host overlay files, not in a core domain fact.
    # Identity facts used by the PATH builder and the umask rule. The group
    # name needs `id -gn`, so it is cached per host and gid.
    uid=$EUID
    gid=$EGID
    ustr=$USERNAME
    _ms_group_name
    return 0
}

# gstr = primary group name, from the per-host cache, forking `id` only on a miss.
_ms_group_name() {
    emulate -L zsh
    local dir=${XDG_CACHE_HOME:-$HOME/.cache}/marksharc/$MARKSHARC_HOST
    local file=$dir/group.$EGID
    gstr=
    if [[ -r $file ]]; then
        gstr=$(<"$file")
    else
        gstr=$(${_ms_idcmd:-$idcmd} -g -n 2>/dev/null) || gstr=
        if [[ -n $gstr ]]; then
            [[ -d $dir ]] || command mkdir -p -- "$dir" 2>/dev/null
            { print -r -- "$gstr" > "$file" } 2>/dev/null
        fi
    fi
    return 0
}

# Private-group users get a group-writable umask; everyone else, and root, 022.
_ms_umask() {
    if [[ -n $gstr && $gstr == $ustr && $uid != 0 ]]; then umask 002; else umask 022; fi
}
