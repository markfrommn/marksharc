Describe 'native zsh qualification'
  native_contract() {
    emulate -L zsh
    local -a items=('two words' three)
    local -A pairs=(key 'literal value')
    local value='two words'
    [[ $#items == 2 && $items[1] == 'two words' && $pairs[key] == 'literal value' ]] || return 1
    [[ ! -o shwordsplit && -o nomatch ]] || return 2
    set -- $value
    [[ $# == 1 ]] || return 3
    local marker=outer
    inner() { emulate -L zsh; local marker=inner; setopt shwordsplit; }
    inner
    [[ $marker == outer && ! -o shwordsplit ]] || return 4
    command_mock() { print -r -- "$@"; }
    [[ $(command_mock 'one argument') == 'one argument' ]] || return 5
  }
  It 'retains arrays, native options, scopes and literal mock arguments'
    When run native_contract
    The status should be success
  End
  It 'agrees with a direct native zsh process'
    When run command zsh -dfc 'a=("two words" three); [[ $#a == 2 && ! -o shwordsplit && -o nomatch ]]'
    The status should be success
  End
End
