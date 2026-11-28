#!/bin/sh
# Clean-container check that the README alone is enough to install marksharc.
#
# The install commands are read from the fenced `sh` blocks of README.md's "Install"
# section, so the check runs what a reader sees. They run as a new unprivileged user in a
# fresh container that has only zsh, git, curl and CA certificates added. The script then
# starts a login shell and runs the README's Day 1, Day 2 and uninstall commands.
#
# Usage: tests/e2e/readme-container.sh [--source local|github-clone|github-curl]
#                                      [--image IMAGE] [<checkout>]
#
#   local         (default) the README's `git clone` block, with the GitHub URL replaced by
#                 a snapshot of this working tree: tests the checkout, uncommitted edits
#                 included.
#   github-clone  the README's `git clone` block exactly as written.
#   github-curl   the README's `curl | sh` block exactly as written.
#
# The two github modes install the published default branch, so they prove the README's
# commands reach a working repository; `local` proves this checkout installs.
# Needs docker (or a compatible CLI named by $DOCKER) and network access. Not run by CI.
set -eu

source_mode=local
image=ubuntu:24.04
checkout=
while [ $# -gt 0 ]; do
  case $1 in
    --source) [ $# -ge 2 ] || { echo "readme-container: --source needs a value" >&2; exit 2; }; source_mode=$2; shift 2 ;;
    --image) [ $# -ge 2 ] || { echo "readme-container: --image needs a value" >&2; exit 2; }; image=$2; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) echo "readme-container: unknown option: $1" >&2; exit 2 ;;
    *) [ -z "$checkout" ] || { echo "readme-container: unexpected argument: $1" >&2; exit 2; }; checkout=$1; shift ;;
  esac
done
case $source_mode in
  local|github-clone|github-curl) ;;
  *) echo "readme-container: unknown source: $source_mode (expected local, github-clone or github-curl)" >&2; exit 2 ;;
esac
[ -n "$checkout" ] || checkout=$(dirname -- "$0")/../..
checkout=$(CDPATH='' cd -- "$checkout" && pwd)
[ -r "$checkout/README.md" ] && [ -r "$checkout/install.sh" ] || { echo "readme-container: $checkout is not a marksharc checkout" >&2; exit 2; }
docker=${DOCKER:-docker}
command -v "$docker" >/dev/null 2>&1 || { echo "readme-container: $docker not found" >&2; exit 2; }

work=$(mktemp -d "${TMPDIR:-/tmp}/marksharc-readme.XXXXXX")
trap 'rm -rf -- "$work"' EXIT
trap 'exit 130' HUP INT TERM
mkdir "$work/steps"

# Print the first fenced sh block of the README's Install section that contains $1.
readme_block() {
  awk -v want="$1" '
    /^## / { section = ($0 == "## Install") }
    section && /^```sh$/ { inblock = 1; block = ""; next }
    section && inblock && /^```$/ {
      inblock = 0
      if (index(block, want)) { printf "%s", block; found = 1; exit }
      next
    }
    section && inblock { block = block $0 "\n" }
    END { exit found ? 0 : 1 }
  ' "$checkout/README.md"
}

repo_url=https://github.com/markfrommn/marksharc.git
case $source_mode in
  local|github-clone) commands=$(readme_block 'git clone') || { echo "readme-container: no git clone block in the README Install section" >&2; exit 1; } ;;
  github-curl) commands=$(readme_block 'curl ') || { echo "readme-container: no curl block in the README Install section" >&2; exit 1; } ;;
esac

mount_src=
if [ "$source_mode" = local ]; then
  case $commands in
    *"$repo_url"*) ;;
    *) echo "readme-container: the README clone command does not name $repo_url" >&2; exit 1 ;;
  esac
  # Snapshot the working tree (tracked files and new files that are not ignored) as a
  # one-commit repository, so the README's git clone has something local to clone.
  mkdir "$work/src"
  (cd "$checkout" && git ls-files -co --exclude-standard -z | tar --null -T - -cf -) | tar -xf - -C "$work/src"
  git -C "$work/src" init -q
  git -C "$work/src" add -A
  git -C "$work/src" -c user.name=readme-check -c user.email=readme-check@example.invalid commit -q -m 'working tree snapshot'
  commands=$(printf '%s\n' "$commands" | sed "s|$repo_url|/srv/marksharc.git|")
  mount_src="-v $work/src:/src:ro"
fi

cat > "$work/steps/steps.sh" <<EOF
set -eu
cd "\$HOME"
echo "== README install commands ($source_mode)"
$commands
EOF
cat >> "$work/steps/steps.sh" <<'EOF'

fail() { echo "readme-container: FAIL: $*" >&2; exit 1; }

echo "== a login shell starts silently"
zsh -l -c true > "$HOME/first.out" 2> "$HOME/first.err" < /dev/null || fail "login zsh failed"
[ ! -s "$HOME/first.out" ] && [ ! -s "$HOME/first.err" ] || { cat "$HOME/first.out" "$HOME/first.err"; fail "login zsh printed output"; }

echo "== marksharc is on PATH"
zsh -l -c 'print -r -- "session=$MARKSHARC_SESSION framework=$MARKSHARC_HOME"; marksharc version'

echo "== Day 1: module list, disable"
enabled=$(zsh -l -c 'marksharc module list' | grep -c ' enabled ' || :)
[ "$enabled" -gt 0 ] || fail "module list shows no enabled module"
echo "$enabled modules enabled"
zsh -l -c 'marksharc module disable greeting'
zsh -l -c 'marksharc module list' | grep -q '^greeting  *disabled' || fail "greeting was not disabled"
grep -q '^module greeting off$' "$HOME/.config/marksharc/config.conf" || fail "config.conf was not edited"

echo "== Day 2: doctor, sync"
zsh -l -c 'marksharc doctor' > "$HOME/doctor.out" || fail "doctor failed"
cat "$HOME/doctor.out"
grep -q '^doctor: [0-9][0-9]* issue' "$HOME/doctor.out" || fail "doctor printed no summary"
zsh -l -c 'marksharc update --list' > "$HOME/update.out" || fail "update --list failed"
grep -q '^sync$' "$HOME/update.out" || fail "update --list has no sync step"

echo "== Bash gets the environment"
bash -l -c 'command -v marksharc' >/dev/null || fail "login Bash does not have marksharc on PATH"

echo "== uninstall restores the home directory"
zsh -l -c 'marksharc uninstall'
! grep -q 'marksharc: managed stub' "$HOME/.zshenv" 2>/dev/null || fail "the zsh stub is still installed"
[ -d "$HOME/.config/marksharc" ] || fail "uninstall removed the overlay"
echo "readme-container: PASS ($(cat /etc/os-release | sed -n 's/^PRETTY_NAME=//p' | tr -d '"'))"
EOF

echo "readme-container: source=$source_mode image=$image"
# shellcheck disable=SC2086 # mount_src is an optional pair of words.
"$docker" run --rm -i -v "$work/steps:/work:ro" $mount_src "$image" sh -s <<'EOF'
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update -q >/dev/null
apt-get install -y -q --no-install-recommends zsh git curl ca-certificates >/dev/null
useradd -m -s /bin/sh tester
if [ -d /src ]; then
  cp -R /src /srv/marksharc.git
  chown -R tester /srv/marksharc.git
fi
exec su - tester -c 'sh /work/steps.sh'
EOF
