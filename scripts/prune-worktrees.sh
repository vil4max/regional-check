#!/usr/bin/env bash
# Lists and, with --apply, removes landed task worktrees, their branches, and
# their DerivedData. Dry run by default. Never forces: anything with uncommitted
# or unlanded work is kept and reported.
set -euo pipefail

apply=false
[[ "${1:-}" == "--apply" ]] && apply=true

root="$(git rev-parse --path-format=absolute --git-common-dir)"
root="$(dirname "$root")"
cd "$root"
git fetch --prune --quiet origin

base=main
removed=0
kept=0

# A branch whose reflog has only its creation entry was never worked on; a fresh
# task worktree sits at the tip of main and would otherwise look landed.
has_commits() {
  [[ "$(git reflog show --format=%H "refs/heads/$1" 2>/dev/null | wc -l)" -gt 1 ]]
}

# Fast-forward merges make the branch an ancestor; cherry-picks leave only
# patch-equivalent ("-") commits.
is_landed() {
  git merge-base --is-ancestor "$1" "$base" && return 0
  local cherry
  cherry="$(git cherry "$base" "$1")" || return 1
  ! grep -q '^+' <<<"$cherry"
}

remove_derived_data() {
  local path="$1" dir
  for dir in "$HOME"/Library/Developer/Xcode/DerivedData/RegionalCheck-*; do
    [[ -f "$dir/info.plist" ]] || continue
    if plutil -extract WorkspacePath raw "$dir/info.plist" 2>/dev/null | grep -q "^$path/"; then
      rm -rf "$dir"
    fi
  done
}

act() {
  if $apply; then
    "$@"
  fi
}

worktree_branches=""
while IFS=$'\t' read -r path branch; do
  if [[ "$path" == "$root" ]]; then
    worktree_branches+="$branch"$'\n'
    continue
  fi
  if [[ ! -d "$path" ]]; then
    echo "prune   $path ($branch): directory missing"
    continue
  fi
  worktree_branches+="$branch"$'\n'
  if [[ -n "$(git -C "$path" status --porcelain)" ]]; then
    echo "keep    $path ($branch): uncommitted changes"
    kept=$((kept + 1))
  elif [[ "$branch" == "(detached)" ]]; then
    echo "keep    $path: detached HEAD, owner decides"
    kept=$((kept + 1))
  elif ! has_commits "$branch"; then
    echo "keep    $path ($branch): no commits yet"
    kept=$((kept + 1))
  elif ! is_landed "$branch"; then
    echo "keep    $path ($branch): commits not in $base"
    kept=$((kept + 1))
  else
    echo "remove  $path ($branch): landed"
    act git worktree remove "$path"
    act git branch -D "$branch"
    act remove_derived_data "$path"
    removed=$((removed + 1))
  fi
done < <(git worktree list --porcelain | awk '
  /^worktree / { path = substr($0, 10) }
  /^branch /   { sub("refs/heads/", "", $2); print path "\t" $2 }
  /^detached/  { print path "\t(detached)" }')

# Unregisters worktrees whose directory is gone, so their branches can be deleted.
act git worktree prune

while read -r branch; do
  [[ "$branch" == "$base" ]] && continue
  grep -qxF "$branch" <<<"$worktree_branches" && continue
  if has_commits "$branch" && is_landed "$branch"; then
    echo "remove  branch $branch: landed, no worktree"
    act git branch -D "$branch"
    removed=$((removed + 1))
  elif ! has_commits "$branch" && git merge-base --is-ancestor "$branch" "$base"; then
    echo "remove  branch $branch: never used, no worktree"
    act git branch -D "$branch"
    removed=$((removed + 1))
  else
    echo "keep    branch $branch: no worktree, not landed"
    kept=$((kept + 1))
  fi
done < <(git for-each-ref --format='%(refname:short)' refs/heads)

$apply || echo "dry run: rerun with --apply to remove"
echo "remove=$removed keep=$kept"
