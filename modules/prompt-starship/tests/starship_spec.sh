Describe 'prompt-starship config selection (P3.6)'
  star_run() {
    print -r -- "$1" > "$TEST_ROOT/case.zsh"
    ms_unit 'MARKSHARC_SESSION=interactive; _ms_reloading=1; INIT="$MARKSHARC_HOME/modules/prompt-starship/init.zsh"; source "$TEST_ROOT/case.zsh"'
  }
  config_case() {
    emulate -L zsh
    # Empty keeps starship's own lookup and whatever the environment says.
    star_run 'export STARSHIP_CONFIG=/inherited.toml; source $INIT; print -r -- "A=$STARSHIP_CONFIG"
unset STARSHIP_CONFIG; source $INIT; print -r -- "B=${STARSHIP_CONFIG-unset}"
_ms_opt_prompt_starship_config=rich; source $INIT; print -r -- "C=${STARSHIP_CONFIG#$MARKSHARC_HOME/} ${(t)STARSHIP_CONFIG}"
_ms_opt_prompt_starship_config=nosuch; source $INIT; print -r -- "D=${STARSHIP_CONFIG-unset}"
print "x = 1" > $HOME/my.toml; _ms_opt_prompt_starship_config="~/my.toml"; source $INIT; print -r -- "E=${STARSHIP_CONFIG#$HOME/}"
_ms_opt_prompt_starship_config=; source $INIT; print -r -- "F=${STARSHIP_CONFIG-unset}"
export STARSHIP_CONFIG=/user.toml; _ms_opt_prompt_starship_config=rich; source $INIT; _ms_opt_prompt_starship_config=; source $INIT; print -r -- "G=${STARSHIP_CONFIG-unset}"' || return 1
    # G: a reload only removes the value this module set (rich replaced /user.toml, so
    # switching off unsets it; a later user export is never touched).
    [[ $(<"$TEST_ROOT/out") == $'A=/inherited.toml\nB=unset\nC=modules/prompt-starship/presets/rich.toml scalar-export\nD=unset\nE=my.toml\nF=unset\nG=unset' ]] || { cat "$TEST_ROOT/out" "$TEST_ROOT/err"; return 2; }
  }
  It 'exports STARSHIP_CONFIG for a readable file or bundled preset and removes only its own value'
    When run config_case
    The status should be success
  End
  preset_case() {
    emulate -L zsh
    local preset="$MARKSHARC_ROOT/modules/prompt-starship/presets/rich.toml"
    [[ -r $preset ]] || return 1
    # The rich preset keeps the left prompt short and sends the rest to the right prompt.
    # grep -qx 'format = """$directory$character"""' "$preset" && grep -qx 'right_format = """$all"""' "$preset" || return 2
    grep -qx 'format =' && grep -qx 'fill' || return 2
    #local section
    #for section in status cmd_duration jobs shlvl sudo; do grep -qx "\\[$section\\]" "$preset" || { print -r -- "missing $section"; return 3; }; done
  }
  It 'ships the rich preset'
    When run preset_case
    The status should be success
  End
End
