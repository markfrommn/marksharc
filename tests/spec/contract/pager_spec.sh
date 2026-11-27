# The pager module extends MANPATH the same way in zsh, fish and Bash (DEV-70): what earlier
# modules (brew) set stays in front, the system directories follow once, and one empty entry
# ends the list, so man keeps its default and PATH-derived search in every shell.
Describe 'pager MANPATH'
  # manpath_run INPUT EXPECTED: run the pager init of each shell with MANPATH set to INPUT
  # (unset when empty); each must print EXPECTED.
  manpath_run() {
    if [ -n "$1" ]; then export MANPATH="$1"; else unset MANPATH; fi
    printf '%s\n' "$2" > "$TEST_ROOT/expected"
    zsh -f -c '
      have_command() { return 1; }
      source "$MARKSHARC_ROOT/modules/pager/init.zsh" || exit
      print -r -- "$MANPATH"
    ' > "$TEST_ROOT/zsh.out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 1; }
    fish --no-config -c '
      for lib in directives path modules plugins cache
        source "$MARKSHARC_ROOT/core/fish/lib/$lib.fish"
      end
      _ms_fish_init_module "$MARKSHARC_ROOT/modules/pager"
      printf "%s\n" "$MANPATH"
    ' > "$TEST_ROOT/fish.out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 2; }
    "${MARKSHARC_TEST_BASH:-bash}" --noprofile --norc -c '
      source "$MARKSHARC_ROOT/core/bash/ownership.bash"
      source "$MARKSHARC_ROOT/modules/pager/init.bash"
      printf "%s\n" "$MANPATH"
    ' > "$TEST_ROOT/bash.out" 2> "$TEST_ROOT/err" || { cat "$TEST_ROOT/err"; return 3; }
    for manpath_shell in zsh fish bash; do
      cmp -s "$TEST_ROOT/expected" "$TEST_ROOT/$manpath_shell.out" && continue
      printf '%s: %s\n' "$manpath_shell" "$(cat "$TEST_ROOT/$manpath_shell.out")" >&2
      return 4
    done
  }
  manpath_case() {
    # /usr/local/man joins only where it exists.
    manpath_system=/usr/share/man
    [ -d /usr/local/man ] && manpath_system=$manpath_system:/usr/local/man
    # Unset; Homebrew's leading-colon form of our own list; a nested shell that already has
    # the list; Homebrew's directory in front; a spaced entry, doubled, with stray empties.
    for manpath_pair in "|$manpath_system:" ":$manpath_system|$manpath_system:" \
      "$manpath_system:|$manpath_system:" \
      "/opt/brew/share/man|/opt/brew/share/man:$manpath_system:" \
      "/opt/My Tools/share/man:/opt/My Tools/share/man::/usr/share/man:|/opt/My Tools/share/man:$manpath_system:"; do
      manpath_run "${manpath_pair%%|*}" "${manpath_pair#*|}" || return $?
    done
  }
  It 'extends MANPATH identically in zsh, fish and Bash, ending in one empty entry'
    Skip if 'selected Bash is older than 4.4' bash_interactive_unavailable
    When run manpath_case
    The status should be success
  End
End
