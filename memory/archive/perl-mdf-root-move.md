# Perl `$MDF_ROOT` interpolation in move-unit mechanical passes

**Applies to:** units that move specs/modules from mark-desktop-files with
mechanical path renames (DEV-43/P2.3, DEV-44/P2.4).

**Retire when:** DEV-43 and DEV-44 are merged and no further mark-desktop-files
move units remain.

The DEV-42 plan's mechanical-rename one-liner used `s/\Q$MDF_ROOT\E/.../g` in
single quotes. Perl interpolates `$MDF_ROOT` as an (undefined) Perl variable
before `\Q` quoting, so the pattern became empty and the `/g` substitution
inserted the replacement at every position, shredding the copied spec files
(symptom: `$MARKSHARC_ROOT` between every two characters).

Fix used in DEV-42 (verified): escape the dollar instead of `\Q...\E`:

    perl -pi -e 's/\$MDF_ROOT\/config\/zsh\/core/\$MARKSHARC_ROOT\/core\/zsh/g;
                 s/\$MDF_ROOT\/config\/zsh\/modules/\$MARKSHARC_ROOT\/modules/g;
                 s/\$MDF_ROOT\/tests\/shell/\$MARKSHARC_ROOT\/tests/g;
                 s/\$MDF_ROOT/\$MARKSHARC_ROOT/g;' <files>

Always re-copy the files fresh from the source before re-running a corrected
pass, then grep the result for `MDF_ROOT` leftovers and for `^\$MARKSHARC_ROOT`
line-start insertions to prove the pass was clean.

Quoted-string concatenations escape the mechanical rules entirely: patterns
like `'"$MDF_ROOT"'/config/zsh/modules/...` and plain `config/zsh` pathspecs in
`git grep`/`find` need hand edits — grep the moved files for `config/zsh`
after the mechanical pass.
