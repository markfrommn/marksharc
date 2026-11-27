#!/bin/sh
# marksharc installer (Day 0, spec 6.15). POSIX sh.
#
#   curl -fsSL https://raw.githubusercontent.com/markfrommn/marksharc/main/install.sh | sh
#   git clone https://github.com/markfrommn/marksharc.git && sh marksharc/install.sh
#
# Options:
#   --home DIR       use DIR (a marksharc checkout) as the framework
#   --overlay SRC    link a local directory, or git-clone a URL, as the overlay
#   --coexist        add one source line to ~/.zshenv and ~/.zshrc instead of
#                    replacing dotfiles or redirecting ZDOTDIR
#   --dry-run        print every action and change nothing
#   --clobber        assume yes to optional pre-install cleanup
#   --no-plugins     do not fetch the pinned plugins (run "marksharc update" later)
#
# The framework is the checkout this script sits in, else a clone made into
# $XDG_DATA_HOME/marksharc ($MARKSHARC_REPO overrides the repository). Existing
# zsh dotfiles in HOME move into a backup under the state directory, recorded in
# an install manifest that "marksharc uninstall" reads. Re-running is safe.
set -eu

REPO_DEFAULT=https://github.com/markfrommn/marksharc.git
DRY=0
CLOBBER=0
COEXIST=0
PLUGINS=1
FW_ARG=
OVERLAY_ARG=
BASH_DOTFILES=".bashrc .bash_profile"
BASH_LEGACY=".bash_login .profile .login"
DOTFILES=".zshenv .zshrc .zprofile .zlogin .zlogout $BASH_DOTFILES $BASH_LEGACY"
STUB_MARK='# marksharc: managed stub'
COEXIST_MARK='# marksharc: coexist'
NL='
'
TMP_STUB=
TMP_MANIFEST=
fish_move_pending=0
install_lock_held=0

say() { printf 'marksharc: %s\n' "$*"; }
die() { printf 'marksharc install: error: %s\n' "$*" >&2; exit 1; }
cleanup() {
  rm -f -- "$TMP_STUB" "$TMP_MANIFEST"
  if [ "$fish_move_pending" -eq 1 ] && [ "$(mf_get fish_backup)" != "$fish_backup" ]; then
    if dest_present "$fish_backup/fish"; then
      if ! mv -n -- "$fish_backup/fish" "$CONFIG_BASE/" || dest_present "$fish_backup/fish"; then
        printf 'marksharc: the original Fish config is in %s\n' "$fish_backup/fish" >&2
      fi
    fi
    rmdir -- "$fish_backup" 2>/dev/null || :
  fi
  [ "$install_lock_held" -eq 0 ] || rmdir -- "$install_lock"
}
trap cleanup EXIT
trap 'exit 130' HUP INT TERM

usage() {
  cat <<'EOF'
Usage: install.sh [--home DIR] [--overlay PATH|URL] [--coexist] [--dry-run] [--clobber] [--no-plugins]

  --home DIR        use DIR, a marksharc checkout, as the framework
  --overlay SRC     link a local directory, or git-clone a URL, as the overlay
                    (default: copy the template when no overlay exists)
  --coexist         add one source line to ~/.zshenv and ~/.zshrc instead of
                    replacing dotfiles or redirecting ZDOTDIR (leaves existing
                    zsh, Bash and Fish startup files in place)
  --dry-run         print every action and change nothing
  --clobber         assume yes to optional pre-install cleanup
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
    --coexist) COEXIST=1; shift ;;
    --dry-run|-n) DRY=1; shift ;;
    --clobber) CLOBBER=1; shift ;;
    --no-plugins) PLUGINS=0; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "unknown option: $1 (try --help)" ;;
  esac
done
if [ "$COEXIST" -eq 1 ] && [ "$CLOBBER" -eq 1 ]; then
  die "--coexist and --clobber cannot be combined"
fi
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
while [ "${#CONFIG_BASE}" -gt 1 ]; do
  case $CONFIG_BASE in */) CONFIG_BASE=${CONFIG_BASE%/} ;; *) break ;; esac
done
xdg_dir XDG_DATA_HOME "$HOME/.local/share"; DATA_BASE=$xd_value
xdg_dir XDG_STATE_HOME "$HOME/.local/state"; STATE_BASE=$xd_value
xdg_dir XDG_CACHE_HOME "$HOME/.cache"; CACHE_BASE=$xd_value
STATE_DIR=$STATE_BASE/marksharc
CACHE_DIR=$CACHE_BASE/marksharc
MANIFEST=$STATE_DIR/install.manifest
install_lock=$STATE_BASE/.marksharc-install.lock
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
for p in "$HOME" "$CONFIG_BASE" "$CONFIG_DIR" "$DATA_BASE" "$STATE_DIR" "$CACHE_DIR"; do
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
# fish single-quoted strings escape backslashes and single quotes.
fishq() { printf "'%s'" "$(printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/\\\\'/g")"; }
# mf_get KEY: the first value of KEY in the existing manifest, if any.
mf_get() {
  [ -f "$MANIFEST" ] || return 0
  awk -F= -v k="$1" '$1 == k { sub(/^[^=]*=/, ""); print; exit }' "$MANIFEST"
}
manifest_sum() {
  if [ -f "$MANIFEST" ]; then cksum < "$MANIFEST"; fi
}
initial_manifest=$(manifest_sum) || die "could not read $MANIFEST"
is_url() {
  case $1 in
    *://*) return 0 ;;
    /*|./*|../*) return 1 ;;
    *@*:*) return 0 ;;
  esac
  return 1
}
dest_present() { [ -e "$1" ] || [ -L "$1" ]; }
uninstall_cmd() {
  uc_fw=$(mf_get framework)
  if [ -n "$uc_fw" ]; then printf '%s/bin/marksharc uninstall' "$uc_fw"; else printf 'marksharc uninstall'; fi
}
# resolve_file PATH: print the physical target path of PATH, following symlinks.
resolve_file() {
  rf_path=$1
  rf_depth=0
  while [ -L "$rf_path" ]; do
    rf_depth=$((rf_depth + 1))
    [ "$rf_depth" -le 40 ] || die "too many symlink levels: $1"
    rf_link=$(readlink "$rf_path" && printf x) || die "could not read symlink: $rf_path"
    rf_link=${rf_link%x}
    case ${rf_link%"$NL"} in *"$NL"*) die "the link $1 has a newline in its target" ;; esac
    rf_link=${rf_link%"$NL"}
    case $rf_link in
      /*) rf_path=$rf_link ;;
      *)
        case $rf_path in
          */*) rf_path=${rf_path%/*}/$rf_link ;;
          *) rf_path=$rf_link ;;
        esac
        ;;
    esac
  done
  case $rf_path in
    */*) rf_dir=${rf_path%/*}; rf_base=${rf_path##*/} ;;
    *) rf_dir=.; rf_base=$rf_path ;;
  esac
  rf_dir=$(physpath "${rf_dir:-/}") || die "could not resolve directory of $1"
  case $rf_dir in
    /) printf '/%s\n' "$rf_base" ;;
    *) printf '%s/%s\n' "$rf_dir" "$rf_base" ;;
  esac
}
coexist_line_count() {
  [ -f "$1" ] || { printf '0\n'; return 0; }
  MS_MARK=$COEXIST_MARK awk 'index($0, ENVIRON["MS_MARK"]) > 0 { n++ } END { print n + 0 }' "$1"
}
coexist_line_exact() {
  [ -f "$1" ] || return 1
  MS_MARK=$COEXIST_MARK MS_LINE=$2 awk '
    index($0, ENVIRON["MS_MARK"]) > 0 {
      if ($0 == ENVIRON["MS_LINE"]) found = 1; else bad = 1
    }
    END { exit !(found && !bad) }
  ' "$1"
}
coexist_apply_line() {
  ca_dot=$1
  ca_line=$2
  ca_count=$3
  if dest_present "$ca_dot"; then
    ca_target=$(resolve_file "$ca_dot")
  else
    ca_target=$ca_dot
  fi
  TMP_STUB=$ca_target.marksharc.$$
  if [ ! -e "$ca_target" ]; then
    printf '%s\n' "$ca_line" > "$TMP_STUB"
  elif [ "$ca_count" -eq 1 ]; then
    cp -p -- "$ca_target" "$TMP_STUB"
    MS_MARK=$COEXIST_MARK MS_LINE=$ca_line awk '
      index($0, ENVIRON["MS_MARK"]) > 0 { print ENVIRON["MS_LINE"]; next }
      { print }
    ' "$ca_target" > "$TMP_STUB"
  else
    cp -p -- "$ca_target" "$TMP_STUB"
    if [ -s "$ca_target" ]; then
      case $(tail -c 1 "$ca_target"; printf x) in
        "$NL"x) ;;
        *) printf '\n' >> "$TMP_STUB" ;;
      esac
    fi
    printf '%s\n' "$ca_line" >> "$TMP_STUB"
  fi
  mv -f -- "$TMP_STUB" "$ca_target"
  TMP_STUB=
}
fish_cleanup_confirmed() {
  if [ "$CLOBBER" -eq 1 ]; then return 0; fi
  if [ "$DRY" -eq 1 ]; then
    say "would ask whether to back up $FISH_DIR and install a clean Fish configuration (y/N)"
    return 1
  fi
  prompt="Back up $FISH_DIR and install a clean MarkSharc Fish configuration? (y/N) "
  if [ -t 0 ]; then
    printf '%s' "$prompt"
    IFS= read -r answer || return 1
  elif ( : < /dev/tty ) 2>/dev/null; then
    # The README's piped command uses stdin for script text.
    printf '%s' "$prompt" > /dev/tty
    IFS= read -r answer < /dev/tty || return 1
  else
    return 1
  fi
  case $answer in [Yy]|[Yy][Ee][Ss]) return 0 ;; *) return 1 ;; esac
}

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
FISH_DIR=${CONFIG_BASE%/}/fish
FISH_STUB=$FISH_DIR/conf.d/00-marksharc.fish
COEXIST_DIR=$STATE_DIR/coexist
COEXIST_ZSHENV=$COEXIST_DIR/zshenv.zsh
COEXIST_ZSHRC=$COEXIST_DIR/zshrc.zsh
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
coexist_zshenv_text() {
  printf '%s\n' "$STUB_MARK (install.sh --coexist); do not edit. Remove with: marksharc uninstall"
  printf 'MARKSHARC_HOME=%s\n' "$(shq "$FW")"
  printf 'export MARKSHARC_HOME\n'
  if [ "$CONFIG_DIR" != "$DEFAULT_CONFIG" ]; then
    printf 'MARKSHARC_CONFIG=%s\n' "$(shq "$CONFIG_DIR")"
    printf 'export MARKSHARC_CONFIG\n'
  fi
  cat <<'EOF'
typeset -g MARKSHARC_COEXIST=1
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
coexist_zshrc_text() {
  printf '%s\n' "$STUB_MARK (install.sh --coexist); do not edit. Remove with: marksharc uninstall"
  printf 'MARKSHARC_HOME=%s\n' "$(shq "$FW")"
  printf 'export MARKSHARC_HOME\n'
  if [ "$CONFIG_DIR" != "$DEFAULT_CONFIG" ]; then
    printf 'MARKSHARC_CONFIG=%s\n' "$(shq "$CONFIG_DIR")"
    printf 'export MARKSHARC_CONFIG\n'
  fi
  printf '%s\n' 'typeset -g MARKSHARC_COEXIST=1'
  # shellcheck disable=SC2016 # Expanded by the shell that reads the stub.
  printf '%s\n' 'if [[ -r $MARKSHARC_HOME/core/zsh/zshrc.zsh ]]; then source "$MARKSHARC_HOME/core/zsh/zshrc.zsh"; fi'
}
fish_stub_text() {
  printf '%s\n' "$STUB_MARK (install.sh); do not edit. Remove with: marksharc uninstall"
  printf 'set -gx MARKSHARC_HOME %s\n' "$(fishq "$FW")"
  if [ "$CONFIG_DIR" != "$DEFAULT_CONFIG" ]; then
    printf 'set -gx MARKSHARC_CONFIG %s\n' "$(fishq "$CONFIG_DIR")"
  fi
  # shellcheck disable=SC2016 # the variables belong to the generated fish stub
  printf '%s\n' 'test -r "$MARKSHARC_HOME/core/fish/marksharc.fish"; and source "$MARKSHARC_HOME/core/fish/marksharc.fish"'
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

# A moved Fish tree must not take the framework, overlay or installer state with it.
check_fish_overlap() {
  fish_physical=$(physpath "$FISH_DIR") || fish_physical=$FISH_DIR
  for protected in "$HOME" "$FW" "$CONFIG_DIR" "$STATE_DIR" "$STATE_DIR/backup" "$STATE_DIR/replaced" \
    "$(mf_get backup)" "$CACHE_DIR" "$ov_src"; do
    case $protected in /*) ;; *) continue ;; esac
    parent=$protected
    # Check ancestors as well as the endpoint. An overlay symlink inside Fish
    # can point outside the tree but still become unreachable when it moves.
    while [ -n "$parent" ]; do
      [ "$parent" != "$FISH_DIR" ] || die "cannot clean Fish: $FISH_DIR contains $protected"
      if [ -d "$parent" ]; then
        physical=$(physpath "$parent") || die "could not resolve $parent"
        case $physical in "$fish_physical"|"$fish_physical"/*) die "cannot clean Fish: $FISH_DIR contains $protected" ;; esac
      fi
      parent=${parent%/*}
    done
  done
}

existing_mode=$(mf_get mode)
fish_enabled=0
fish_clean=0
fish_backup=
fish_backup_stub_sum=
old_fish_stub=
old_fish_sum=
backup_files=
backup_links=
cleanup_only=
backup_candidates=
original_backup=$(mf_get backup)
coexist_zshenv_created=0
coexist_zshrc_created=0
coexist_zshenv_count=0
coexist_zshrc_count=0
coexist_zshenv_line=
coexist_zshrc_line=
coexist_zshenv_line_current=0
coexist_zshrc_line_current=0
coexist_zshenv_stub_current=0
coexist_zshrc_stub_current=0
if [ "$COEXIST" -eq 1 ]; then
  if stub_is_ours "$STUB"; then
    die "marksharc is already installed in standard mode; run \"$(uninstall_cmd)\" first before installing with --coexist"
  fi
  if [ -f "$MANIFEST" ] && [ "$existing_mode" != coexist ] &&
    grep -Eq '^(backup|file|link|fish_backup|bash_stubs|stub_sum)=' "$MANIFEST"; then
    die "marksharc is already installed in standard mode (see $MANIFEST); run \"$(uninstall_cmd)\" first before installing with --coexist"
  fi
  if [ "$existing_mode" = coexist ]; then
    mode=update
  else
    mode=fresh
  fi
  coexist_zshenv_line="[[ ! -r $(shq "$COEXIST_ZSHENV") ]] || source $(shq "$COEXIST_ZSHENV") $COEXIST_MARK"
  coexist_zshrc_line="[[ ! -r $(shq "$COEXIST_ZSHRC") ]] || source $(shq "$COEXIST_ZSHRC") $COEXIST_MARK"
  for pair in "zshenv:$HOME/.zshenv:$coexist_zshenv_line" "zshrc:$HOME/.zshrc:$coexist_zshrc_line"; do
    ckind=${pair%%:*}
    crest=${pair#*:}
    cdot=${crest%%:*}
    cline=${crest#*:}
    if dest_present "$cdot"; then
      if [ -L "$cdot" ] && [ ! -e "$cdot" ]; then
        die "$cdot is a broken symlink; fix or remove it before installing with --coexist"
      fi
      [ -f "$cdot" ] || die "$cdot is not a regular file; move it aside before installing with --coexist"
      creal=$(resolve_file "$cdot")
      ccnt=$(coexist_line_count "$creal")
      [ "$ccnt" -le 1 ] || die "$cdot contains multiple marksharc coexist lines; remove the extra lines and retry"
      if [ "$ccnt" -eq 1 ] && coexist_line_exact "$creal" "$cline"; then
        ccur=1
      else
        ccur=0
      fi
      if [ "$mode" = update ]; then
        ccreated=$(mf_get "coexist_${ckind}_created")
        ccreated=${ccreated:-0}
      else
        ccreated=0
      fi
    else
      ccnt=0
      ccur=0
      if [ "$mode" = update ]; then
        ccreated=$(mf_get "coexist_${ckind}_created")
        ccreated=${ccreated:-1}
      else
        ccreated=1
      fi
    fi
    if [ "$ckind" = zshenv ]; then
      coexist_zshenv_count=$ccnt
      coexist_zshenv_line_current=$ccur
      coexist_zshenv_created=$ccreated
    else
      coexist_zshrc_count=$ccnt
      coexist_zshrc_line_current=$ccur
      coexist_zshrc_created=$ccreated
    fi
  done
else
  if [ -f "$MANIFEST" ] && [ "$existing_mode" = coexist ]; then
    die "marksharc is currently installed in coexist mode; run \"$(uninstall_cmd)\" first to switch to standard mode, or re-run with --coexist"
  fi
  fish_backup=$(mf_get fish_backup)
  fish_backup_stub_sum=$(mf_get fish_backup_stub_sum)
  old_fish_stub=$(mf_get fish_stub)
  old_fish_sum=$(mf_get fish_stub_sum)
  [ -z "$old_fish_stub" ] || [ "$old_fish_stub" = "$FISH_STUB" ] ||
    die "fish stub moved from $old_fish_stub; uninstall before changing XDG_CONFIG_HOME"
  if [ -n "$fish_backup" ]; then
    case $fish_backup in "${CONFIG_BASE%/}"/.marksharc-fish-backup.*) ;; *) die "the Fish backup is outside the current XDG_CONFIG_HOME" ;; esac
    if [ "${fish_backup%/*}" != "${CONFIG_BASE%/}" ] ||
      [ ! -d "$fish_backup" ] || [ -L "$fish_backup" ] || ! dest_present "$fish_backup/fish"; then
      die "the original Fish configuration is missing from $fish_backup; finish uninstall or recover the backup before reinstalling"
    fi
  fi
  if [ "$fw_action" = clone ] || [ -r "$FW/core/fish/marksharc.fish" ]; then
    fish_enabled=1
    fish_slot_unavailable=0
    fish_legacy=0
    if dest_present "$FISH_DIR"; then
      if [ -L "$FISH_DIR" ] || [ ! -d "$FISH_DIR" ] ||
        [ -L "$FISH_DIR/conf.d" ] ||
        { dest_present "$FISH_DIR/conf.d" && [ ! -d "$FISH_DIR/conf.d" ]; } ||
        { dest_present "$FISH_STUB" && ! stub_is_ours "$FISH_STUB"; }; then
        fish_slot_unavailable=1
        fish_legacy=1
      else
        extras=$(cd -- "$FISH_DIR" && find . ! -path . ! -path ./conf.d ! -path ./conf.d/00-marksharc.fish -prune -print) ||
          die "could not inspect the existing Fish configuration at $FISH_DIR"
        [ -z "$extras" ] || fish_legacy=1
      fi
    fi
    if [ "$fish_legacy" -eq 1 ] && [ -z "$fish_backup" ] && fish_cleanup_confirmed; then
      check_fish_overlap
      fish_clean=1
      if stub_is_ours "$FISH_STUB"; then
        if [ -L "$FISH_DIR" ] || [ -L "$FISH_DIR/conf.d" ]; then
          die "move the managed Fish stub out of the symlinked configuration before cleaning it"
        fi
        fish_backup_stub_sum=${old_fish_sum:-unknown}
      fi
    elif [ "$fish_slot_unavailable" -eq 1 ]; then
      say "warning: skipping Fish because $FISH_STUB is unavailable; leaving the existing Fish configuration in place"
      fish_enabled=0
    fi
  fi

  matches_original() {
    if [ -L "$HOME/$1" ]; then
      grep -Fxq "link=$1=$(readlink "$HOME/$1")" "$MANIFEST"
    elif [ -f "$HOME/$1" ] && [ -n "$original_backup" ] &&
      [ -f "$original_backup/$1" ] && [ ! -L "$original_backup/$1" ]; then
      grep -Fxq "file=$1" "$MANIFEST" && cmp -s "$HOME/$1" "$original_backup/$1"
    else
      return 1
    fi
  }
  if stub_is_ours; then
    mode=update
    backup_candidates=$BASH_LEGACY
  else
    mode=fresh
    # Backups from an earlier install are only recorded in the manifest: rebuilding it now would
    # drop them (and a later uninstall --purge would delete them), so stop before any write.
    if [ -f "$MANIFEST" ] && grep -Eq '^(backup|file|link|fish_backup)=' "$MANIFEST"; then
      backup_hint=${original_backup:-${fish_backup:-$MANIFEST}}
      die "an earlier install recorded backups at $backup_hint, but $STUB is no longer the marksharc stub. Run \"$(mf_get framework)/bin/marksharc uninstall\" first to restore the originals. If it reports a conflicting $STUB, move that file aside and retry."
    fi
    backup_candidates=$DOTFILES
  fi

  # A pre-Bash manifest retains its original backup and adds the two Bash files.
  old_bash_sum=$(mf_get bash_stub_sum)
  if [ "$mode" = update ] && [ "$(mf_get bash_stubs)" != 1 ]; then
    backup_candidates="$BASH_DOTFILES $backup_candidates"
  elif [ "$mode" = update ]; then
    for n in $BASH_DOTFILES; do
      if dest_present "$HOME/$n" && ! stub_is_ours "$HOME/$n"; then
        matches_original "$n" && continue
        die "$HOME/$n is no longer the managed stub; move it aside before reinstalling"
      fi
    done
  fi
  for n in $backup_candidates; do
    path=$HOME/$n
    dest_present "$path" || continue
    if [ "$mode" = update ] && [ -f "$MANIFEST" ] &&
      { grep -Fxq "file=$n" "$MANIFEST" || grep -q "^link=[.]${n#.}=" "$MANIFEST"; }; then
      matches_original "$n" || die "$path differs from the original backup; move it aside before reinstalling"
      cleanup_only="$cleanup_only $n"
    elif [ -L "$path" ]; then
      target=$(readlink "$path" && printf x) || die "could not read the link $path"
      target=${target%x}
      case ${target%"$NL"} in *"$NL"*) die "the link $path has a newline in its target; move it aside before reinstalling" ;; esac
      backup_links="$backup_links $n"
    elif [ -f "$path" ]; then
      backup_files="$backup_files $n"
    else
      die "$path is neither a regular file nor a symlink; move it aside and re-run"
    fi
    # A retry can encounter a copy made before the manifest was published.
    if [ -n "$original_backup" ] && dest_present "$original_backup/$n"; then
      if [ ! -L "$path" ] && [ -f "$original_backup/$n" ] &&
        [ ! -L "$original_backup/$n" ] && cmp -s "$path" "$original_backup/$n"; then
        continue
      fi
      die "backup already exists for $path at $original_backup/$n; reconcile it before upgrading"
    fi
  done
fi

# --- act --------------------------------------------------------------------
if [ "$DRY" -eq 1 ]; then
  say "dry run: nothing will be changed"
else
  mkdir -p -- "$STATE_BASE"
  mkdir -m 700 -- "$install_lock" 2>/dev/null ||
    die "another install or uninstall may be running; could not acquire $install_lock"
  install_lock_held=1
  current_manifest=$(manifest_sum) || die "could not read $MANIFEST"
  [ "$current_manifest" = "$initial_manifest" ] || die "the install manifest changed; re-run the installer"
fi

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
      if [ "$COEXIST" -eq 0 ] && [ ! -r "$FW/core/fish/marksharc.fish" ]; then
        fish_enabled=0
        fish_clean=0
        fish_backup_stub_sum=$(mf_get fish_backup_stub_sum)
        say "warning: skipping Fish because the framework clone has no Fish startup script"
      fi
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

# 3 & 4. dotfiles, manifest and stubs
stamp_now=$(date +%Y%m%dT%H%M%S)
if [ "$COEXIST" -eq 1 ]; then
  say "coexist mode: keeping existing zsh, Bash and Fish startup files in place"
  coexist_zshenv_body=$(coexist_zshenv_text; printf x); coexist_zshenv_body=${coexist_zshenv_body%x}
  coexist_zshenv_sum=$(printf '%s' "$coexist_zshenv_body" | cksum_of)
  coexist_zshrc_body=$(coexist_zshrc_text; printf x); coexist_zshrc_body=${coexist_zshrc_body%x}
  coexist_zshrc_sum=$(printf '%s' "$coexist_zshrc_body" | cksum_of)
  coexist_zshenv_stub_current=0
  coexist_zshenv_edited=0
  if stub_is_ours "$COEXIST_ZSHENV"; then
    if [ "$(cat "$COEXIST_ZSHENV"; printf x)" = "$coexist_zshenv_body"x ]; then
      coexist_zshenv_stub_current=1
    else
      cur_sum=$(cksum_of < "$COEXIST_ZSHENV")
      want_sum=$(mf_get coexist_zshenv_sum)
      [ "$cur_sum" = "${want_sum:-$coexist_zshenv_sum}" ] || coexist_zshenv_edited=1
    fi
  fi
  coexist_zshrc_stub_current=0
  coexist_zshrc_edited=0
  if stub_is_ours "$COEXIST_ZSHRC"; then
    if [ "$(cat "$COEXIST_ZSHRC"; printf x)" = "$coexist_zshrc_body"x ]; then
      coexist_zshrc_stub_current=1
    else
      cur_sum=$(cksum_of < "$COEXIST_ZSHRC")
      want_sum=$(mf_get coexist_zshrc_sum)
      [ "$cur_sum" = "${want_sum:-$coexist_zshrc_sum}" ] || coexist_zshrc_edited=1
    fi
  fi
  write_coexist_manifest() {
    printf '%s\n' "# marksharc install manifest (v1); read by marksharc uninstall. Do not edit."
    printf 'version=1\n'
    printf 'mode=coexist\n'
    printf 'home=%s\n' "$HOME"
    printf 'framework=%s\n' "$FW"
    printf 'framework_cloned=%s\n' "$fw_cloned"
    printf 'config=%s\n' "$CONFIG_DIR"
    printf 'config_origin=%s\n' "$ov_origin"
    printf 'state=%s\n' "$STATE_DIR"
    printf 'cache=%s\n' "$CACHE_DIR"
    printf 'coexist_zshenv=%s\n' "$COEXIST_ZSHENV"
    printf 'coexist_zshenv_sum=%s\n' "$coexist_zshenv_sum"
    printf 'coexist_zshrc=%s\n' "$COEXIST_ZSHRC"
    printf 'coexist_zshrc_sum=%s\n' "$coexist_zshrc_sum"
    printf 'coexist_zshenv_created=%s\n' "$coexist_zshenv_created"
    printf 'coexist_zshrc_created=%s\n' "$coexist_zshrc_created"
  }
  new_manifest=$(write_coexist_manifest; printf x); new_manifest=${new_manifest%x}
  manifest_current=0
  if [ -f "$MANIFEST" ] && [ "$(cat "$MANIFEST"; printf x)" = "$new_manifest"x ]; then manifest_current=1; fi
  if [ "$DRY" -eq 1 ]; then
    if [ "$coexist_zshenv_edited" -eq 1 ]; then say "would keep a copy of the edited coexist stub in $STATE_DIR/replaced/coexist-zshenv.$stamp_now.$$"; fi
    if [ "$coexist_zshenv_stub_current" -eq 1 ]; then say "the coexist stub $COEXIST_ZSHENV is up to date"; else say "would write the coexist stub $COEXIST_ZSHENV"; fi
    if [ "$coexist_zshrc_edited" -eq 1 ]; then say "would keep a copy of the edited coexist stub in $STATE_DIR/replaced/coexist-zshrc.$stamp_now.$$"; fi
    if [ "$coexist_zshrc_stub_current" -eq 1 ]; then say "the coexist stub $COEXIST_ZSHRC is up to date"; else say "would write the coexist stub $COEXIST_ZSHRC"; fi
    if [ "$coexist_zshenv_line_current" -eq 1 ]; then
      say "$HOME/.zshenv already has the marksharc coexist line"
    elif [ "$coexist_zshenv_count" -eq 1 ]; then
      say "would update the marksharc coexist line in $HOME/.zshenv"
    else
      say "would add the marksharc coexist line to $HOME/.zshenv"
    fi
    if [ "$coexist_zshrc_line_current" -eq 1 ]; then
      say "$HOME/.zshrc already has the marksharc coexist line"
    elif [ "$coexist_zshrc_count" -eq 1 ]; then
      say "would update the marksharc coexist line in $HOME/.zshrc"
    else
      say "would add the marksharc coexist line to $HOME/.zshrc"
    fi
    if [ "$manifest_current" -eq 0 ]; then say "would write the manifest $MANIFEST"; fi
  else
    mkdir -p -- "$STATE_DIR" "$COEXIST_DIR"
    if [ "$manifest_current" -eq 0 ]; then
      TMP_MANIFEST=$STATE_DIR/.install.manifest.$$
      printf '%s' "$new_manifest" > "$TMP_MANIFEST"
      mv -f -- "$TMP_MANIFEST" "$MANIFEST"
      TMP_MANIFEST=
    fi
    if [ "$coexist_zshenv_stub_current" -eq 1 ]; then
      say "the coexist stub $COEXIST_ZSHENV is up to date"
    else
      if [ "$coexist_zshenv_edited" -eq 1 ]; then
        mkdir -p -- "$STATE_DIR/replaced"
        chmod 700 "$STATE_DIR/replaced"
        cp -p -- "$COEXIST_ZSHENV" "$STATE_DIR/replaced/coexist-zshenv.$stamp_now.$$"
        say "the coexist stub had been edited by hand; your copy is kept in $STATE_DIR/replaced/coexist-zshenv.$stamp_now.$$"
      fi
      [ ! -L "$COEXIST_ZSHENV" ] || rm -f -- "$COEXIST_ZSHENV"
      TMP_STUB=$COEXIST_ZSHENV.tmp.$$
      printf '%s' "$coexist_zshenv_body" > "$TMP_STUB"
      mv -f -- "$TMP_STUB" "$COEXIST_ZSHENV"
      TMP_STUB=
      say "wrote the coexist stub $COEXIST_ZSHENV"
    fi
    if [ "$coexist_zshrc_stub_current" -eq 1 ]; then
      say "the coexist stub $COEXIST_ZSHRC is up to date"
    else
      if [ "$coexist_zshrc_edited" -eq 1 ]; then
        mkdir -p -- "$STATE_DIR/replaced"
        chmod 700 "$STATE_DIR/replaced"
        cp -p -- "$COEXIST_ZSHRC" "$STATE_DIR/replaced/coexist-zshrc.$stamp_now.$$"
        say "the coexist stub had been edited by hand; your copy is kept in $STATE_DIR/replaced/coexist-zshrc.$stamp_now.$$"
      fi
      [ ! -L "$COEXIST_ZSHRC" ] || rm -f -- "$COEXIST_ZSHRC"
      TMP_STUB=$COEXIST_ZSHRC.tmp.$$
      printf '%s' "$coexist_zshrc_body" > "$TMP_STUB"
      mv -f -- "$TMP_STUB" "$COEXIST_ZSHRC"
      TMP_STUB=
      say "wrote the coexist stub $COEXIST_ZSHRC"
    fi
    if [ "$coexist_zshenv_line_current" -eq 0 ]; then
      coexist_apply_line "$HOME/.zshenv" "$coexist_zshenv_line" "$coexist_zshenv_count"
      say "added the marksharc coexist line to $HOME/.zshenv"
    fi
    if [ "$coexist_zshrc_line_current" -eq 0 ]; then
      coexist_apply_line "$HOME/.zshrc" "$coexist_zshrc_line" "$coexist_zshrc_count"
      say "added the marksharc coexist line to $HOME/.zshrc"
    fi
  fi
else
  # 3. Back up newly covered dotfiles before changing the originals.
  backup=$original_backup
  if [ -n "$backup_files$backup_links" ]; then
    if [ -z "$backup" ]; then
      stamp=$(date +%Y%m%dT%H%M%S)
      backup=$STATE_DIR/backup/$stamp
      if dest_present "$backup"; then backup=$backup-$$; fi
    fi
    if [ "$DRY" -eq 1 ]; then
      say "would back up$backup_files$backup_links from $HOME into $backup"
    else
      mkdir -p -- "$STATE_DIR/backup"
      chmod 700 "$STATE_DIR" "$STATE_DIR/backup"
      [ -d "$backup" ] || mkdir -m 700 -- "$backup"
      for n in $backup_files; do
        dest_present "$backup/$n" || cp -p -- "$HOME/$n" "$backup/$n"
      done
      say "backed up$backup_files$backup_links into $backup"
    fi
  else
    say "no new zsh or Bash dotfiles to back up"
  fi

  if [ "$fish_clean" -eq 1 ]; then
    if [ "$DRY" -eq 1 ]; then
      say "would back up $FISH_DIR beside the Fish configuration directory"
    else
      fish_backup=$(mktemp -d "${CONFIG_BASE%/}/.marksharc-fish-backup.XXXXXX")
      fish_move_pending=1
      mv -- "$FISH_DIR" "$fish_backup/fish" || die "could not back up $FISH_DIR"
      say "backed up the Fish configuration into $fish_backup/fish"
    fi
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
    if [ "$fish_enabled" -eq 1 ]; then
      printf 'fish_stub=%s\n' "$FISH_STUB"
      printf 'fish_stub_sum=%s\n' "$fish_sum"
    elif [ -n "$old_fish_stub" ]; then
      printf 'fish_stub=%s\n' "$old_fish_stub"
      printf 'fish_stub_sum=%s\n' "$old_fish_sum"
    fi
    [ -z "$fish_backup" ] || printf 'fish_backup=%s\n' "$fish_backup"
    [ -z "$fish_backup_stub_sum" ] || printf 'fish_backup_stub_sum=%s\n' "$fish_backup_stub_sum"
    printf 'bash_stubs=1\n'
    printf 'bash_stub_sum=%s\n' "$bash_sum"
    [ -z "$backup" ] || printf 'backup=%s\n' "$backup"
    if [ "$mode" = update ] && [ -f "$MANIFEST" ]; then
      grep -E '^(file|link)=' "$MANIFEST" || :
    fi
    for n in $backup_files; do printf 'file=%s\n' "$n"; done
    for n in $backup_links; do printf 'link=%s=%s\n' "$n" "$(readlink "$HOME/$n")"; done
  }
  new_stub=$(stub_text; printf x); new_stub=${new_stub%x}
  new_sum=$(printf '%s' "$new_stub" | cksum_of)
  fish_text=$(fish_stub_text; printf x); fish_text=${fish_text%x}
  fish_sum=$(printf '%s' "$fish_text" | cksum_of)
  fish_current=1
  if [ "$fish_enabled" -eq 1 ] &&
    { [ "$fish_clean" -eq 1 ] || ! stub_is_ours "$FISH_STUB" ||
      [ "$(cat "$FISH_STUB"; printf x)" != "$fish_text"x ]; }; then
    fish_current=0
  fi
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
  replaced_copy=$STATE_DIR/replaced/zshenv.$stamp_now.$$
  new_manifest=$(write_manifest; printf x); new_manifest=${new_manifest%x}
  manifest_current=0
  if [ -f "$MANIFEST" ] && [ "$(cat "$MANIFEST"; printf x)" = "$new_manifest"x ]; then manifest_current=1; fi

  if [ "$DRY" -eq 1 ]; then
    if [ "$fish_current" -eq 0 ]; then say "would write the fish stub $FISH_STUB"; fi
    if [ "$stub_edited" -eq 1 ]; then say "would keep a copy of the edited stub in $replaced_copy"; fi
    if [ "$stub_current" -eq 1 ]; then say "the stub $STUB is up to date"; else say "would write the stub $STUB"; fi
    if [ "$bash_current" -eq 0 ]; then say "would write the Bash startup stubs in $HOME"; fi
    if [ "$manifest_current" -eq 0 ]; then say "would write the manifest $MANIFEST"; fi
    for n in $backup_files $backup_links $cleanup_only; do
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
    fish_move_pending=0
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
      [ ! -L "$STUB" ] || rm -f -- "$STUB"
      mv -f -- "$TMP_STUB" "$STUB"
      TMP_STUB=
      say "wrote the stub $STUB"
    fi
    # The stub is in place and everything it replaces is backed up: clear the rest.
    for n in $backup_files $backup_links $cleanup_only; do
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
    if [ "$fish_current" -eq 0 ]; then
      mkdir -p -- "${FISH_STUB%/*}"
      if dest_present "$FISH_STUB"; then
        stub_is_ours "$FISH_STUB" || die "$FISH_STUB appeared during installation; leaving it in place"
        if [ "$(cksum_of < "$FISH_STUB")" != "$old_fish_sum" ]; then
          mkdir -p -- "$STATE_DIR/replaced"
          chmod 700 "$STATE_DIR/replaced"
          cp -p -- "$FISH_STUB" "$STATE_DIR/replaced/fish.$stamp_now.$$"
        fi
      fi
      TMP_STUB=$FISH_STUB.tmp.$$
      printf '%s' "$fish_text" > "$TMP_STUB"
      mv -f -- "$TMP_STUB" "$FISH_STUB"
      TMP_STUB=
      say "wrote the fish stub $FISH_STUB"
    fi
  fi
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
elif [ "$COEXIST" -eq 1 ]; then
  if [ "$mode" = update ] && [ "$coexist_zshenv_stub_current" -eq 1 ] && [ "$coexist_zshrc_stub_current" -eq 1 ] &&
    [ "$coexist_zshenv_line_current" -eq 1 ] && [ "$coexist_zshrc_line_current" -eq 1 ] && [ "$manifest_current" -eq 1 ]; then
    say "already installed; nothing to change"
  else
    say "installed in coexist mode. Open a new terminal, or run: exec zsh -l"
  fi
elif [ "$mode" = update ] && [ "$stub_current" -eq 1 ] && [ "$bash_current" -eq 1 ] &&
  [ "$fish_current" -eq 1 ] && [ "$manifest_current" -eq 1 ] && [ -z "$cleanup_only" ]; then
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
