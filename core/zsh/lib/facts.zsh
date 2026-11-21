# -*- mode: shell-script; sh-shell: zsh -*-
# Host facts from shell builtins and files read with builtins (spec 6.6).
# _ms_fs_root is a test seam: a prefix for the files read below (default "").

_ms_facts() {
    emulate -L zsh
    local root=${_ms_fs_root-} line kernel
    local -a words

    case $OSTYPE in
        darwin*) ostype=Darwin ;;
        linux*)  ostype=Linux ;;
        *)       kernel=${OSTYPE%%[0-9.-]*}; ostype=${(C)kernel} ;;
    esac
    hwtype=$CPUTYPE
    hname=$HOST
    shorthost=${HOST%%.*}
    hostbase=${shorthost%%-*}
    idcmd=/usr/bin/id
    if [[ $ostype == Darwin ]]; then statfmtarg=-f; else statfmtarg=-c; fi
    MARKSHARC_OS=${ostype:l}
    MARKSHARC_ARCH=$hwtype
    MARKSHARC_HOST=$shorthost

    # Linux distribution: a redhat-release file wins, then os-release ID.
    if [[ $ostype == Linux ]]; then
        if [[ -f $root/etc/redhat-release ]]; then
            distro=redhat
        else
            distro=unknown
            if [[ -r $root/etc/os-release ]]; then
                while IFS= read -r line; do
                    if [[ $line == ID=* ]]; then distro=${${${line#ID=}//[\"\']/}:l}; break; fi
                done < "$root/etc/os-release"
            fi
        fi
        MARKSHARC_DISTRO=$distro
    else
        unset distro
        if [[ $ostype == Darwin ]]; then MARKSHARC_DISTRO=macos; else MARKSHARC_DISTRO=$MARKSHARC_OS; fi
    fi

    # Domain: the NIS domain, else the first search/domain line of resolv.conf.
    # Site-name mappings belong to the private overlay.
    dname=
    [[ -r $root/proc/sys/kernel/domainname ]] && read -r dname < "$root/proc/sys/kernel/domainname"
    if [[ -z $dname || $dname == "(none)" ]]; then
        dname=
        if [[ -r $root/etc/resolv.conf ]]; then
            while IFS= read -r line; do
                if [[ $line == (search|domain)* ]]; then words=( ${=line} ); dname=${words[2]-}; break; fi
            done < "$root/etc/resolv.conf"
        fi
    fi

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
