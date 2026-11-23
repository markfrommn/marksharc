#!/bin/sh
# marksharc installer (Day 0, spec 6.15). POSIX sh.
#
#   curl -fsSL https://raw.githubusercontent.com/markfrommn/marksharc/main/install.sh | sh
#   git clone https://github.com/markfrommn/marksharc.git && sh marksharc/install.sh
#
# Options:
#   --home DIR       use DIR (a marksharc checkout) as the framework
#   --overlay SRC    link a local directory, or git-clone a URL, as the overlay
#   --dry-run        print every action and change nothing
#   --no-plugins     do not fetch the pinned plugins (run "marksharc update" later)
#
# The framework is the checkout this script sits in, else a clone made into
# $XDG_DATA_HOME/marksharc ($MARKSHARC_REPO overrides the repository). Existing
# zsh dotfiles in HOME move into a backup under the state directory, recorded in
# an install manifest that "marksharc uninstall" reads. Re-running is safe.
set -eu

REPO_DEFAULT=https://github.com/markfrommn/marksharc.git
DRY=0
PLUGINS=1
FW_ARG=
OVERLAY_ARG=
DOTFILES=".zshenv .zshrc .zprofile .zlogin .zlogout .bashrc .bash_profile"
BASH_DOTFILES=".bashrc .bash_profile"
STUB_MARK='# marksharc: managed stub'
NL='
'
TMP_STUB=
TMP_MANIFEST=

say() { printf 'marksharc: %s\n' "$*"; }
die() { printf 'marksharc install: error: %s\n' "$*" >&2; exit 1; }
cleanup() { rm -f -- "$TMP_STUB" "$TMP_MANIFEST"; }
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

usage() {
  cat <<'EOF'
Usage: install.sh [--home DIR] [--overlay PATH|URL] [--dry-run] [--no-plugins]

  --home DIR        use DIR, a marksharc checkout, as the framework
  --overlay SRC     link a local directory, or git-clone a URL, as the overlay
                    (default: copy the template when no overlay exists)
  --dry-run         print every action and change nothing
  --no-plugins      do not fetch the pinned plugins; "marksharc update" does it later
  -h, --help        show this help

Without --home the framework is the checkout containing this script, else a
clone of $MARKSHARC_REPO (default: the public repository) in
$XDG_DATA_HOME/marksharc (default ~/.local/share/marksharc). An existing
overlay is never modified.
EOF
}

# --- arguments --------------------------------------------------------------
while [ $# -gt 0 ]; do
  case $1 in
    --home) [ $# -ge 2 ] && [ -n "$2" ] || die "--home needs a directory"; FW_ARG=$2; shift 2 ;;
    --home=*) FW_ARG=${1#--home=}; [ -n "$FW_ARG" ] || die "--home needs a directory"; shift ;;
    --overlay) [ $# -ge 2 ] && [ -n "$2" ] || die "--overlay needs a path or URL"; OVERLAY_ARG=$2; shift 2 ;;
    --overlay=*) OVERLAY_ARG=${1#--overlay=}; [ -n "$OVERLAY_ARG" ] || die "--overlay needs a path or URL"; shift ;;
    --dry-run|-n) DRY=1; shift ;;
    --no-plugins) PLUGINS=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done
case $FW_ARG$OVERLAY_ARG in *"$NL"*) die "arguments must not contain newlines" ;; esac

# --- environment ------------------------------------------------------------
[ -n "${HOME:-}" ] || die "HOME is not set"
case $HOME in /*) ;; *) die "HOME must be an absolute path" ;; esac
[ -d "$HOME" ] || die "HOME ($HOME) is not a directory"
# xdg_dir VAR DEFAULT: set xd_value to an XDG base directory, which must be absolute.
xdg_dir() {
  eval "xd_value=\${$1:-}"
  [ -n "$xd_value" ] || { xd_value=$2; return 0; }
  case $xd_value in /*) ;; *) die "$1 must be an absolute path (got: $xd_value)" ;; esac
}
xdg_dir XDG_CONFIG_HOME "$HOME/.config"; CONFIG_BASE=$xd_value
xdg_dir XDG_DATA_HOME "$HOME/.local/share"; DATA_BASE=$xd_value
xdg_dir XDG_STATE_HOME "$HOME/.local/state"; STATE_BASE=$xd_value
xdg_dir XDG_CACHE_HOME "$HOME/.cache"; CACHE_BASE=$xd_value
STATE_DIR=$STATE_BASE/marksharc
CACHE_DIR=$CACHE_BASE/marksharc
MANIFEST=$STATE_DIR/install.manifest
# The overlay the core assumes when the stub names no MARKSHARC_CONFIG. It is judged against
# ~/.config, not against $XDG_CONFIG_HOME: the old dotfiles that exported XDG_CONFIG_HOME are
# moved aside, so a new shell cannot rely on it.
DEFAULT_CONFIG=$HOME/.config/marksharc
CONFIG_DIR=${MARKSHARC_CONFIG:-$CONFIG_BASE/marksharc}
while [ "${#CONFIG_DIR}" -gt 1 ]; do
  case $CONFIG_DIR in */) CONFIG_DIR=${CONFIG_DIR%/} ;; *) break ;; esac
done
REPO=${MARKSHARC_REPO:-$REPO_DEFAULT}
case $CONFIG_DIR in /*) ;; *) die "MARKSHARC_CONFIG must be an absolute path" ;; esac
for p in "$HOME" "$CONFIG_DIR" "$DATA_BASE" "$STATE_DIR" "$CACHE_DIR"; do
  case $p in *"$NL"*|*:*) die "unsupported character (newline or colon) in path: $p" ;; esac
done

# --- prerequisites: nothing is written until these hold ---------------------
command -v zsh > /dev/null 2>&1 || die "zsh is required but was not found on PATH"
command -v git > /dev/null 2>&1 || die "git is required but was not found on PATH"
zsh_version=$(zsh -f -c 'print -r -- $ZSH_VERSION' 2> /dev/null || :)
zsh_major=${zsh_version%%.*}
zsh_rest=${zsh_version#*.}
zsh_minor=${zsh_rest%%[!0-9]*}
case $zsh_major.$zsh_minor in
  .*|*.|*[!0-9.]*|*.*.*) die "could not determine the zsh version (got: ${zsh_version:-nothing}); 5.9 or later is required" ;;
esac
if [ "$zsh_major" -lt 5 ] || { [ "$zsh_major" -eq 5 ] && [ "$zsh_minor" -lt 9 ]; }; then
  die "zsh 5.9 or later is required (found $zsh_version)"
fi

# --- helpers ----------------------------------------------------------------
# abspath DIR / physpath DIR: the absolute (logical or symlink-free) path of a directory.
abspath() { (CDPATH='' cd -- "$1" 2> /dev/null && pwd); }
physpath() { (CDPATH='' cd -P -- "$1" 2> /dev/null && pwd -P); }
valid_fw() { [ -r "$1/core/zsh/zshenv.zsh" ]; }
# shq STRING: single-quote STRING for a shell, so the stub carries it as data.
shq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
# mf_get KEY: the first value of KEY in the existing manifest, if any.
mf_get() {
  [ -f "$MANIFEST" ] || return 0
  awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$MANIFEST"
}
is_url() {
  case $1 in
    *://*) return 0 ;;
    /*|./*|../*) return 1 ;;
    *@*:*) return 0 ;;
  esac
  return 1
}
dest_present() { [ -e "$1" ] || [ -L "$1" ]; }

# --- plan: framework --------------------------------------------------------
self_dir=
if [ -f "$0" ]; then
  case $0 in */*) self_dir=$(abspath "${0%/*}") || self_dir= ;; *) self_dir=$(abspath .) || self_dir= ;; esac
  { [ -n "$self_dir" ] && valid_fw "$self_dir" && [ -f "$self_dir/install.sh" ]; } || self_dir=
fi
fw_action=use
if [ -n "$FW_ARG" ]; then
  FW=$(abspath "$FW_ARG") || die "--home $FW_ARG is not a directory"
  valid_fw "$FW" || die "--home $FW_ARG is not a marksharc checkout (core/zsh/zshenv.zsh not found)"
elif [ -n "$self_dir" ]; then
  FW=$self_dir
else
  FW=$DATA_BASE/marksharc
  if dest_present "$FW"; then
    valid_fw "$FW" || die "$FW exists but is not a marksharc checkout; move it aside or pass --home"
    fw_action=reuse
  else
    fw_action=clone
  fi
fi
case $FW in *"$NL"*|*:*) die "unsupported character (newline or colon) in path: $FW" ;; esac
fw_cloned=0
if [ "$fw_action" = clone ]; then
  fw_cloned=1
elif [ "$(mf_get framework)" = "$FW" ] && [ "$(mf_get framework_cloned)" = 1 ]; then
  fw_cloned=1
fi

# --- plan: overlay ----------------------------------------------------------
ov_action=none
ov_origin=existing
ov_src=
if [ -n "$OVERLAY_ARG" ]; then
  if [ -d "$OVERLAY_ARG" ]; then
    ov_src=$(abspath "$OVERLAY_ARG")
    ov_origin="link"
    if dest_present "$CONFIG_DIR"; then
      [ "$(physpath "$CONFIG_DIR")" = "$(physpath "$ov_src")" ] || die "an overlay already exists at $CONFIG_DIR and is not $ov_src; marksharc never changes an existing overlay (move it aside, or install without --overlay)"
    else
      ov_action="link"
    fi
  elif is_url "$OVERLAY_ARG"; then
    ov_src=$OVERLAY_ARG
    ov_origin=clone
    if dest_present "$CONFIG_DIR"; then
      [ "$(git -C "$CONFIG_DIR" remote get-url origin 2> /dev/null || :)" = "$ov_src" ] || die "an overlay already exists at $CONFIG_DIR and is not a clone of $ov_src; marksharc never changes an existing overlay"
    else
      ov_action=clone
    fi
  else
    die "--overlay $OVERLAY_ARG is neither an existing directory nor a git URL"
  fi
elif dest_present "$CONFIG_DIR"; then
  if [ "$(mf_get config)" = "$CONFIG_DIR" ]; then ov_origin=$(mf_get config_origin); fi
  ov_origin=${ov_origin:-existing}
else
  ov_action=template
  ov_origin=template
  if [ "$fw_action" != clone ] && [ ! -d "$FW/templates/overlay" ]; then
    die "the framework at $FW has no templates/overlay to copy"
  fi
fi

# --- plan: dotfiles and stub ------------------------------------------------
STUB=$HOME/.zshenv
stub_text() {
  printf '%s\n' "$STUB_MARK (install.sh); do not edit. Remove with: marksharc uninstall"
  printf 'MARKSHARC_HOME=%s\n' "$(shq "$FW")"
  printf 'export MARKSHARC_HOME\n'
  if [ "$CONFIG_DIR" != "$DEFAULT_CONFIG" ]; then
    printf 'MARKSHARC_CONFIG=%s\n' "$(shq "$CONFIG_DIR")"
    printf 'export MARKSHARC_CONFIG\n'
  fi
  cat <<'EOF'
_ms_stub_ok=0
{
    [[ -r $MARKSHARC_HOME/core/zsh/zshenv.zsh ]] && source "$MARKSHARC_HOME/core/zsh/zshenv.zsh" && _ms_stub_ok=1
} always {
    if (( ! _ms_stub_ok )); then
        PATH="$MARKSHARC_HOME/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
        export PATH
        print -ru2 -- "marksharc: could not load $MARKSHARC_HOME/core/zsh/zshenv.zsh; using a minimal PATH (repair the checkout, or run: marksharc uninstall)"
    fi
    TRY_BLOCK_ERROR=0
}
unset _ms_stub_ok
EOF
}
bash_stub_text() {
  printf '%s\n' "$STUB_MARK (install.sh); do not edit. Remove with: marksharc uninstall"
  printf 'MARKSHARC_HOME=%s\n' "$(shq "$FW")"
  printf 'export MARKSHARC_HOME\n'
  if [ "$CONFIG_DIR" != "$DEFAULT_CONFIG" ]; then
    printf 'MARKSHARC_CONFIG=%s\n' "$(shq "$CONFIG_DIR")"
    printf 'export MARKSHARC_CONFIG\n'
  fi
  # shellcheck disable=SC2016 # Expanded by the shell that reads the stub.
  printf '%s\n' '[ ! -r "$MARKSHARC_HOME/core/bash/bashrc.bash" ] || . "$MARKSHARC_HOME/core/bash/bashrc.bash"'
}
# cksum_of: "crc size" of the data on stdin (the stub fingerprint kept in the manifest).
cksum_of() { cksum | tr -s ' ' ' '; }
stub_is_ours() {
  stub_check=${1:-$STUB}
  [ -f "$stub_check" ] && [ ! -L "$stub_check" ] || return 1
  first_line=
  IFS= read -r first_line < "$stub_check" || :
  case $first_line in "$STUB_MARK"*) return 0 ;; esac
  return 1
}
backup_files=
backup_links=
if stub_is_ours; then
  mode=update
else
  mode=fresh
  # Backups from an earlier install are only recorded in the manifest: rebuilding it now would
  # drop them (and a later uninstall --purge would delete them), so stop before any write.
  if [ -f "$MANIFEST" ] && grep -Eq '^(backup|file|link)=' "$MANIFEST"; then
    die "an earlier install moved your original dotfiles into $(mf_get backup), but $STUB is no longer the marksharc stub; installing again would lose that record. Run \"$(mf_get framework)/bin/marksharc uninstall\" first (move a replaced $STUB aside so the original can come back). If you already restored the files yourself, delete $MANIFEST and run this again."
  fi
  for n in $DOTFILES; do
    if [ -L "$HOME/$n" ]; then
      backup_links="$backup_links $n"
    elif [ -f "$HOME/$n" ]; then
      backup_files="$backup_files $n"
    elif [ -e "$HOME/$n" ]; then
      die "$HOME/$n is neither a regular file nor a symlink; move it aside and re-run"
    fi
  done
fi

# A pre-Bash manifest retains its original backup and adds the two Bash files.
bash_upgrade=0
old_bash_sum=$(mf_get bash_stub_sum)
if [ "$mode" = update ] && [ "$(mf_get bash_stubs)" != 1 ]; then
  bash_upgrade=1
  for n in $BASH_DOTFILES; do
    if [ -L "$HOME/$n" ]; then
      backup_links="$backup_links $n"
    elif [ -f "$HOME/$n" ]; then
      backup_files="$backup_files $n"
    elif [ -e "$HOME/$n" ]; then
      die "$HOME/$n is neither a regular file nor a symlink; move it aside and re-run"
    fi
  done
fi
if [ "$mode" = update ] && [ "$bash_upgrade" = 0 ]; then
  for n in $BASH_DOTFILES; do
    if dest_present "$HOME/$n" && ! stub_is_ours "$HOME/$n"; then
      original_backup=$(mf_get backup)
      if [ -f "$HOME/$n" ] && [ ! -L "$HOME/$n" ] &&
        grep -Fxq "file=$n" "$MANIFEST" && [ -f "$original_backup/$n" ] &&
        cmp -s "$HOME/$n" "$original_backup/$n"; then
        continue
      fi
      if [ -L "$HOME/$n" ] && grep -Fxq "link=$n=$(readlink "$HOME/$n")" "$MANIFEST"; then
        continue
      fi
      die "$HOME/$n is no longer the managed stub; move it aside before reinstalling"
    fi
  done
fi
if [ "$bash_upgrade" = 1 ]; then
  original_backup=$(mf_get backup)
  if [ -n "$original_backup" ]; then
    for n in $backup_files $backup_links; do
      if dest_present "$original_backup/$n"; then
        if [ -f "$HOME/$n" ] && [ ! -L "$HOME/$n" ] &&
          [ -f "$original_backup/$n" ] && [ ! -L "$original_backup/$n" ] &&
          cmp -s "$HOME/$n" "$original_backup/$n"; then
          continue
        fi
        die "backup already exists for $HOME/$n at $original_backup/$n; reconcile it before upgrading"
      fi
    done
  fi
fi

# --- act --------------------------------------------------------------------
if [ "$DRY" -eq 1 ]; then say "dry run: nothing will be changed"; fi

# 1. framework
case $fw_action in
  clone)
    say "framework: cloning $REPO into $FW"
    if [ "$DRY" -eq 1 ]; then
      say "would run: git clone $REPO $FW"
    else
      mkdir -p -- "$DATA_BASE"
      git clone --quiet -- "$REPO" "$FW" || die "git clone $REPO failed"
      valid_fw "$FW" || die "the clone at $FW does not look like a marksharc checkout"
    fi
    ;;
  reuse) say "framework: reusing the existing clone at $FW (not updated)" ;;
  *) say "framework: using the checkout at $FW" ;;
esac

# 2. overlay
case $ov_action in
  link)
    say "overlay: linking $CONFIG_DIR to $ov_src"
    if [ "$DRY" -eq 1 ]; then
      say "would link $CONFIG_DIR to $ov_src"
    else
      mkdir -p -- "${CONFIG_DIR%/*}"
      ln -s -- "$ov_src" "$CONFIG_DIR"
    fi
    ;;
  clone)
    say "overlay: cloning $ov_src into $CONFIG_DIR"
    if [ "$DRY" -eq 1 ]; then
      say "would run: git clone $ov_src $CONFIG_DIR"
    else
      mkdir -p -- "${CONFIG_DIR%/*}"
      git clone --quiet -- "$ov_src" "$CONFIG_DIR" || die "git clone $ov_src failed"
    fi
    ;;
  template)
    say "overlay: copying the template to $CONFIG_DIR"
    if [ "$DRY" -eq 1 ]; then
      say "would copy $FW/templates/overlay to $CONFIG_DIR"
    else
      mkdir -p -- "$CONFIG_DIR"
      cp -R -- "$FW/templates/overlay/." "$CONFIG_DIR/"
      find "$CONFIG_DIR" -name .gitkeep -type f -exec rm -f -- {} +
    fi
    ;;
  *) say "overlay: keeping the existing overlay at $CONFIG_DIR" ;;
esac

# 3. backup (fresh installs only; a re-run never makes a new backup)
backup=
if [ "$mode" = fresh ] || [ "$bash_upgrade" = 1 ]; then
  if [ -n "$backup_files$backup_links" ]; then
    if [ "$bash_upgrade" = 1 ]; then backup=$(mf_get backup); fi
    if [ -z "$backup" ]; then
      stamp=$(date +%Y%m%dT%H%M%S)
      backup=$STATE_DIR/backup/$stamp
      [ ! -e "$backup" ] || backup=$backup-$$
    fi
    if [ "$DRY" -eq 1 ]; then
      say "would back up$backup_files$backup_links from $HOME into $backup"
    else
      mkdir -p -- "$STATE_DIR/backup"
      chmod 700 "$STATE_DIR" "$STATE_DIR/backup"
      [ -d "$backup" ] || mkdir -m 700 -- "$backup"
      for n in $backup_files; do cp -p -- "$HOME/$n" "$backup/$n"; done
      say "backed up$backup_files$backup_links into $backup"
    fi
  else
    say "no existing zsh dotfiles to back up"
  fi
else
  say "the stub is already ours; no new backup"
fi

# 4. the manifest and the stub
write_manifest() {
  printf '%s\n' "# marksharc install manifest (v1); read by marksharc uninstall. Do not edit."
  printf 'version=1\n'
  printf 'home=%s\n' "$HOME"
  printf 'framework=%s\n' "$FW"
  printf 'framework_cloned=%s\n' "$fw_cloned"
  printf 'config=%s\n' "$CONFIG_DIR"
  printf 'config_origin=%s\n' "$ov_origin"
  printf 'state=%s\n' "$STATE_DIR"
  printf 'cache=%s\n' "$CACHE_DIR"
  printf 'stub_sum=%s\n' "$new_sum"
  printf 'bash_stubs=1\n'
  printf 'bash_stub_sum=%s\n' "$bash_sum"
  if [ "$mode" = fresh ]; then
    [ -z "$backup" ] || printf 'backup=%s\n' "$backup"
    for n in $backup_files; do printf 'file=%s\n' "$n"; done
    for n in $backup_links; do printf 'link=%s=%s\n' "$n" "$(readlink "$HOME/$n")"; done
  elif [ -f "$MANIFEST" ]; then
    grep -E '^(backup|file|link)=' "$MANIFEST" || :
    if [ "$bash_upgrade" = 1 ]; then
      [ -z "$backup" ] || [ -n "$(mf_get backup)" ] || printf 'backup=%s\n' "$backup"
      for n in $backup_files; do printf 'file=%s\n' "$n"; done
      for n in $backup_links; do printf 'link=%s=%s\n' "$n" "$(readlink "$HOME/$n")"; done
    fi
  fi
}
new_stub=$(stub_text; printf x); new_stub=${new_stub%x}
new_sum=$(printf '%s' "$new_stub" | cksum_of)
bash_stub=$(bash_stub_text; printf x); bash_stub=${bash_stub%x}
bash_sum=$(printf '%s' "$bash_stub" | cksum_of)
bash_current=1
for n in $BASH_DOTFILES; do
  if ! stub_is_ours "$HOME/$n" || [ "$(cat "$HOME/$n"; printf x)" != "$bash_stub"x ]; then
    bash_current=0
  fi
done
stub_current=0
stub_edited=0
if [ "$mode" = update ]; then
  if [ "$(cat "$STUB"; printf x)" = "$new_stub"x ]; then
    stub_current=1
  else
    # Not the text we would write: an edit of the stub unless it is exactly what we wrote last time
    # (then the framework or the overlay moved).
    cur_sum=$(cksum_of < "$STUB")
    want_sum=$(mf_get stub_sum)
    [ "$cur_sum" = "${want_sum:-$new_sum}" ] || stub_edited=1
  fi
fi
stamp_now=$(date +%Y%m%dT%H%M%S)
replaced_copy=$STATE_DIR/replaced/zshenv.$stamp_now.$$
new_manifest=$(write_manifest; printf x); new_manifest=${new_manifest%x}
manifest_current=0
if [ -f "$MANIFEST" ] && [ "$(cat "$MANIFEST"; printf x)" = "$new_manifest"x ]; then manifest_current=1; fi

if [ "$DRY" -eq 1 ]; then
  if [ "$stub_edited" -eq 1 ]; then say "would keep a copy of the edited stub in $replaced_copy"; fi
  if [ "$stub_current" -eq 1 ]; then say "the stub $STUB is up to date"; else say "would write the stub $STUB"; fi
  if [ "$bash_current" -eq 0 ]; then say "would write the Bash startup stubs in $HOME"; fi
  if [ "$manifest_current" -eq 0 ]; then say "would write the manifest $MANIFEST"; fi
  for n in $backup_files $backup_links; do
    [ "$n" = .zshenv ] || say "would remove $HOME/$n (kept in the backup)"
  done
else
  mkdir -p -- "$STATE_DIR"
  if [ "$manifest_current" -eq 0 ]; then
    TMP_MANIFEST=$STATE_DIR/.install.manifest.$$
    printf '%s' "$new_manifest" > "$TMP_MANIFEST"
    mv -f -- "$TMP_MANIFEST" "$MANIFEST"
    TMP_MANIFEST=
  fi
  if [ "$stub_current" -eq 1 ]; then
    say "the stub $STUB is up to date"
  else
    if [ "$stub_edited" -eq 1 ]; then
      mkdir -p -- "$STATE_DIR/replaced"
      chmod 700 "$STATE_DIR/replaced"
      cp -p -- "$STUB" "$replaced_copy"
      say "the stub had been edited by hand; your copy is kept in $replaced_copy (merge any lines you still need)"
    fi
    TMP_STUB=$HOME/.zshenv.marksharc.$$
    printf '%s' "$new_stub" > "$TMP_STUB"
    mv -f -- "$TMP_STUB" "$STUB"
    TMP_STUB=
    say "wrote the stub $STUB"
  fi
  # The stub is in place and everything it replaces is backed up: clear the rest.
  for n in $backup_files $backup_links; do
    case $n in .zshenv|.bashrc|.bash_profile) ;; *) rm -f -- "$HOME/$n" ;; esac
  done
  for n in $BASH_DOTFILES; do
    if stub_is_ours "$HOME/$n"; then
      current_sum=$(cksum_of < "$HOME/$n")
      if [ "$current_sum" = "$bash_sum" ]; then continue; fi
      if [ -n "$old_bash_sum" ] && [ "$current_sum" != "$old_bash_sum" ]; then
        mkdir -p -- "$STATE_DIR/replaced"
        chmod 700 "$STATE_DIR/replaced"
        cp -p -- "$HOME/$n" "$STATE_DIR/replaced/${n#.}.$stamp_now.$$"
        say "the stub had been edited by hand; your copy is kept in $STATE_DIR/replaced/${n#.}.$stamp_now.$$"
      fi
    fi
    [ ! -L "$HOME/$n" ] || rm -f -- "$HOME/$n"
    TMP_STUB=$HOME/$n.marksharc.$$
    printf '%s' "$bash_stub" > "$TMP_STUB"
    mv -f -- "$TMP_STUB" "$HOME/$n"
    TMP_STUB=
  done
fi

# 5. plugin pins: fetched here and by "marksharc update", never at startup (spec 6.8). A fetch
# that fails (offline, say) leaves the install in place; doctor reports the missing clone.
plugin_fns=$FW/modules/completion-fzf-tab/functions/zsh
if [ "$PLUGINS" -eq 0 ]; then
  say "plugins: not fetched (--no-plugins); fetch them later with: marksharc update"
elif [ "$DRY" -eq 1 ]; then
  # A framework the real run would clone cannot be read yet; assume it pins plugins.
  if [ "$fw_action" = clone ] || [ -r "$plugin_fns/zsh-plugin-update" ]; then
    say "would fetch the pinned plugins into $CACHE_DIR/plugins"
  fi
elif [ ! -r "$plugin_fns/zsh-plugin-update" ]; then
  :
else
  # shellcheck disable=SC2016 # the zsh code is single-quoted on purpose
  if MARKSHARC_HOME=$FW MARKSHARC_CONFIG=$CONFIG_DIR XDG_CACHE_HOME=$CACHE_BASE \
    zsh -f -c 'fpath=( "$1" $fpath ); autoload -Uz "$1"/*(N-.:t); zsh-plugin-update' zsh "$plugin_fns"; then
    say "plugins: fetched the pinned plugins into $CACHE_DIR/plugins"
  else
    say "warning: could not fetch the pinned plugins; the shell starts without them until you run: marksharc update"
  fi
fi

# 6. first declarative render. Older minimal fixtures may not carry the renderer;
# a real checkout always does. A failed generator leaves a usable install and is
# retried by "marksharc render" or reload.
if [ "$DRY" -eq 1 ] && [ -r "$FW/core/zsh/lib/render.zsh" ]; then
  say "would render the declarative environment and completions"
elif [ "$DRY" -eq 0 ] && [ -r "$FW/core/zsh/lib/render.zsh" ]; then
  if HOME="$HOME" MARKSHARC_HOME="$FW" MARKSHARC_CONFIG="$CONFIG_DIR" \
    XDG_CONFIG_HOME="$CONFIG_BASE" XDG_CACHE_HOME="$CACHE_BASE" \
    XDG_DATA_HOME="$DATA_BASE" XDG_STATE_HOME="$STATE_BASE" \
    zsh -f "$FW/core/cli/render"; then
    say "rendered the declarative environment and completions"
  else
    say "warning: could not render declarative completions; retry with: marksharc render"
  fi
fi

# --- done -------------------------------------------------------------------
if [ "$DRY" -eq 1 ]; then
  say "dry run complete"
elif [ "$mode" = update ] && [ "$stub_current" -eq 1 ] && [ "$bash_current" -eq 1 ] && [ "$manifest_current" -eq 1 ]; then
  say "already installed; nothing to change"
else
  say "installed. Open a new terminal, or run: exec zsh -l"
fi
case ${SHELL:-} in
  */zsh) ;;
  *) say "your login shell is ${SHELL:-unknown}, not zsh; to make zsh the login shell run: chsh -s $(command -v zsh)" ;;
esac
# The stub cannot carry the other XDG variables; say so when they are not the defaults.
for pair in "XDG_STATE_HOME:$HOME/.local/state" "XDG_CACHE_HOME:$HOME/.cache" "XDG_DATA_HOME:$HOME/.local/share"; do
  xv=${pair%%:*}
  xd=${pair#*:}
  eval "xval=\"\${$xv:-}\""
  if [ -n "$xval" ] && [ "$xval" != "$xd" ]; then
    say "warning: $xv is $xval here, but new shells only see it if it is set in their environment; the stub does not save it (without it they use $xd)"
  fi
done
say "undo with: marksharc uninstall"
