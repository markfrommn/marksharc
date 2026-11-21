Describe 'module test discovery and contract'
  links_case() {
    emulate -L zsh
    local dir name link
    for dir in "$MARKSHARC_ROOT"/modules/*/tests(N/); do
      name=${dir:h:t}
      link="$MARKSHARC_ROOT/tests/spec/zsh/modules/$name"
      [[ -L $link && ${link:A} == ${dir:A} ]] || { print -r -- "module $name tests are not linked from spec/zsh/modules"; return 1; }
    done
    for link in "$MARKSHARC_ROOT"/tests/spec/zsh/modules/*(N@); do
      [[ -d ${link:A} && ${link:A} == */modules/${link:t}/tests ]] || { print -r -- "dangling or foreign link $link"; return 2; }
    done
  }
  It 'links every module tests directory from spec/zsh/modules'
    When run links_case
    The status should be success
  End
  contract_case() {
    emulate -L zsh
    local conf mod order file
    for conf in "$MARKSHARC_ROOT"/modules/*/module.conf(N); do
      mod=${conf:h:t}
      [[ $(<"$conf") == *'describe '* ]] || { print -r -- "$mod: no describe"; return 1; }
      order=${${(M)${(f)"$(<"$conf")"}:#order *}[1]#order }
      [[ -z $order || $order == <0-99> ]] || { print -r -- "$mod: order out of range: $order"; return 2; }
      for file in ${conf:h}/{init.zsh,env.zsh,functions/zsh/*}(N.); do
        /bin/zsh -n "$file" || { print -r -- "$mod: syntax error in $file"; return 3; }
      done
    done
  }
  It 'gives every module a describe line, an order in range and syntactically valid zsh'
    When run contract_case
    The status should be success
  End
End
