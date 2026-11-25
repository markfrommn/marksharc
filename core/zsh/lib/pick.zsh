# Read value<TAB>label candidates from stdin and print the selected values.
# Callers piping candidates save their original terminal with `exec {fd}<&0`.
_ms_pick() {
    local header='' flag='an explicit selection flag' terminal_fd=0
    local -i multi=0
    while (( $# )); do
        case $1 in
            --multi) multi=1; shift ;;
            --header) (( $# >= 2 )) || return 2; header=$2; shift 2 ;;
            --flag) (( $# >= 2 )) || return 2; flag=$2; shift 2 ;;
            --terminal-fd) (( $# >= 2 )) || return 2; terminal_fd=$2; shift 2 ;;
            *) return 2 ;;
        esac
    done
    if [[ $terminal_fd != <-> ]] || ! [[ -t $terminal_fd && -t 2 ]]; then
        print -ru2 -- "Selection needs a terminal; pass $flag."
        return 3
    fi
    local tool
    if (( $+commands[gum] )); then
        tool=gum
    elif (( $+commands[fzf] )); then
        tool=fzf
    else
        print -ru2 -- "Selection needs gum or fzf; pass $flag."
        return 3
    fi
    local line label raw chosen display
    local -a values=() labels=() args=() selected=()
    local -A counts=() by_label=()
    while IFS= read -r line || [[ -n $line ]]; do
        [[ $line == *$'\t'* ]] || continue
        label=${line#*$'\t'}
        values+=( "${line%%$'\t'*}" )
        labels+=( "$label" )
        counts[$label]=$(( ${counts[$label]:-0} + 1 ))
    done
    (( $#labels )) || return 1
    local -i index
    for (( index = 1; index <= $#labels; ++index )); do
        label=$labels[index]
        if (( counts[$label] > 1 )); then
            display="$label (${values[index]})"
            while [[ -n ${counts[$display]-}${by_label[$display]+x} ]]; do
                display+=" [$index]"
            done
            labels[index]=$display
        fi
        by_label[${labels[index]}]=${values[index]}
    done
    if [[ $tool == gum ]]; then
        args=( choose )
        (( multi )) && args+=( --no-limit )
        [[ -z $header ]] || args+=( --header "$header" )
    else
        (( multi )) && args+=( --multi )
        [[ -z $header ]] || args+=( --header "$header" )
    fi
    raw=$(print -r -l -- "${labels[@]}" | command "$tool" "${args[@]}") || return 1
    [[ -n $raw ]] || return 0
    selected=( "${(@f)raw}" )
    for chosen in "${selected[@]}"; do
        [[ -z ${by_label[$chosen]+x} ]] || print -r -- "${by_label[$chosen]}"
    done
}
