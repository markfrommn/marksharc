# Parse JSON into caller-owned json_values and json_types maps indexed by JSON Pointer.
# Arrays store their length as the value. Object keys use RFC 6901 escaping.
_ms_json_parse() {
    local json=$1
    local -i json_pos=1 json_len=${#1}
    json_values=() json_types=()
    _ms_json_value '' || { json_values=() json_types=(); return 1; }
    _ms_json_space
    (( json_pos > json_len )) || { json_values=() json_types=(); return 1; }
}

_ms_json_space() {
    while (( json_pos <= json_len )); do
        case $json[json_pos] in
            ' '|$'\t'|$'\n'|$'\r') (( ++json_pos )) ;;
            *) break ;;
        esac
    done
    return 0
}

_ms_json_string() {
    [[ $json[json_pos] == '"' ]] || return 1
    (( ++json_pos ))
    local out='' ch hex next decoded
    local -i code low
    while (( json_pos <= json_len )); do
        ch=$json[json_pos]
        (( ++json_pos ))
        case $ch in
            '"') REPLY=$out; return 0 ;;
            $'\x00'|[$'\x01'-$'\x1f']) return 1 ;;
            '\')
                (( json_pos <= json_len )) || return 1
                ch=$json[json_pos]
                (( ++json_pos ))
                case $ch in
                    '"'|'\'|'/') out+=$ch ;;
                    b) out+=$'\b' ;;
                    f) out+=$'\f' ;;
                    n) out+=$'\n' ;;
                    r) out+=$'\r' ;;
                    t) out+=$'\t' ;;
                    u)
                        (( json_pos + 3 <= json_len )) || return 1
                        hex=${json[json_pos,json_pos+3]}
                        [[ $hex == [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F] ]] || return 1
                        code=$(( 16#$hex ))
                        (( json_pos += 4 ))
                        if (( code >= 0xd800 && code <= 0xdbff )); then
                            [[ ${json[json_pos,json_pos+1]} == '\u' ]] || return 1
                            (( json_pos += 2 ))
                            (( json_pos + 3 <= json_len )) || return 1
                            hex=${json[json_pos,json_pos+3]}
                            [[ $hex == [0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F] ]] || return 1
                            low=$(( 16#$hex ))
                            (( low >= 0xdc00 && low <= 0xdfff )) || return 1
                            code=$(( 0x10000 + (code - 0xd800) * 0x400 + low - 0xdc00 ))
                            (( json_pos += 4 ))
                        elif (( code >= 0xdc00 && code <= 0xdfff )); then
                            return 1
                        fi
                        if (( code < 0x80 )); then
                            printf -v next '\\x%02x' "$code"
                        elif (( code < 0x800 )); then
                            printf -v next '\\x%02x\\x%02x' $(( 0xc0 | (code >> 6) )) $(( 0x80 | (code & 0x3f) ))
                        elif (( code < 0x10000 )); then
                            printf -v next '\\x%02x\\x%02x\\x%02x' $(( 0xe0 | (code >> 12) )) $(( 0x80 | ((code >> 6) & 0x3f) )) $(( 0x80 | (code & 0x3f) ))
                        else
                            printf -v next '\\x%02x\\x%02x\\x%02x\\x%02x' $(( 0xf0 | (code >> 18) )) $(( 0x80 | ((code >> 12) & 0x3f) )) $(( 0x80 | ((code >> 6) & 0x3f) )) $(( 0x80 | (code & 0x3f) ))
                        fi
                        printf -v decoded '%b' "$next"
                        out+=$decoded ;;
                    *) return 1 ;;
                esac ;;
            *) out+=$ch ;;
        esac
    done
    return 1
}

_ms_json_value() {
    local pointer=$1 key escaped token ch REPLY
    local -i count=0 start
    _ms_json_space
    (( json_pos <= json_len )) || return 1
    ch=$json[json_pos]
    case $ch in
        '{')
            json_types[$pointer]=object
            (( ++json_pos ))
            _ms_json_space
            if [[ $json[json_pos] == '}' ]]; then (( ++json_pos )); return 0; fi
            while true; do
                _ms_json_string || return 1
                key=$REPLY
                escaped=${key//\~/\~0}
                escaped=${escaped//\//\~1}
                _ms_json_space
                [[ $json[json_pos] == ':' ]] || return 1
                (( ++json_pos ))
                _ms_json_value "$pointer/$escaped" || return 1
                _ms_json_space
                case $json[json_pos] in
                    '}') (( ++json_pos )); return 0 ;;
                    ',') (( ++json_pos )); _ms_json_space ;;
                    *) return 1 ;;
                esac
            done ;;
        '[')
            json_types[$pointer]=array
            (( ++json_pos ))
            _ms_json_space
            if [[ $json[json_pos] == ']' ]]; then
                (( ++json_pos )); json_values[$pointer]=0; return 0
            fi
            while true; do
                _ms_json_value "$pointer/$count" || return 1
                (( ++count ))
                _ms_json_space
                case $json[json_pos] in
                    ']') (( ++json_pos )); json_values[$pointer]=$count; return 0 ;;
                    ',') (( ++json_pos )); _ms_json_space ;;
                    *) return 1 ;;
                esac
            done ;;
        '"')
            _ms_json_string || return 1
            json_values[$pointer]=$REPLY
            json_types[$pointer]=string ;;
        *)
            start=$json_pos
            while (( json_pos <= json_len )); do
                case $json[json_pos] in
                    ','|'}'|']'|' '|$'\t'|$'\n'|$'\r') break ;;
                    *) (( ++json_pos )) ;;
                esac
            done
            token=${json[start,json_pos-1]}
            case $token in
                true|false) json_types[$pointer]=boolean ;;
                null) json_types[$pointer]=null ;;
                *) [[ $token =~ '^-?(0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?$' ]] || return 1
                   json_types[$pointer]=number ;;
            esac
            json_values[$pointer]=$token ;;
    esac
    return 0
}
