#!/usr/bin/env bash
# Controleert of er nieuwe upstream-commits zijn → zinvol om opnieuw te bouwen?
# Haalt upstream op (netwerk-only, wijzigt de working tree NIET) en telt per
# project hoeveel commits de uitgecheckte bron achterloopt op de remote branch.
set -euo pipefail
cd "$(dirname "$0")"

echo "Fetching upstream (network-only, wijzigt de working tree niet)..."
docker exec houji-builder bash -c \
  'cd /src && repo sync -n -c --no-clone-bundle --no-tags -j8 >/dev/null 2>&1'

echo
echo "Nieuwe upstream-commits per project:"

changes=$(docker exec -i houji-builder bash -s <<'INNER'
cd /src
repo forall -c '
  rrev="$REPO_RREV"
  branch=""
  case "$rrev" in
    refs/tags/*) ;;                                   # gepind op een tag: verandert niet
    refs/heads/*) branch="${rrev#refs/heads/}" ;;
    *) branch="$rrev" ;;
  esac
  if [ -n "$branch" ]; then
    n=$(git rev-list --count "HEAD..$REPO_REMOTE/$branch" 2>/dev/null || echo 0)
    if [ "$n" -gt 0 ]; then
      printf "%s\t%s\n" "$REPO_PATH" "$n"
    fi
  fi
'
INNER
)

if [ -z "$changes" ]; then
  echo "  (geen) — bron is up-to-date; geen nieuwe build nodig."
  exit 0
fi

echo "$changes" | awk -F'\t' '
  { printf "  %-55s +%s commits\n", $1, $2; total += $2; n++ }
  END {
    printf "\nTotaal: +%d commits over %d project(en) -> zinvol om opnieuw te bouwen.\n", total, n
  }
'
