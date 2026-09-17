#!/usr/bin/env bash
# Lists and, with --apply, removes landed task worktrees, their branches, and
# their DerivedData. Dry run by default. Never forces: anything with uncommitted
# or unlanded work is kept and reported.
set -euo pipefail

apply=false
only=""
while (($#)); do
  case "$1" in
    --apply) apply=true ;;
    --only) only="${2:?--only needs a branch}"; shift ;;
    *) echo "usage: prune-worktrees.sh [--apply] [--only <branch>]" >&2; exit 2 ;;
  esac
  shift
done
# A worktree whose Git state changed this recently may belong to a live session.
active_minutes=120

root="$(git rev-parse --path-format=absolute --git-common-dir)"
root="$(dirname "$root")"
cd "$root"
git fetch --prune --quiet origin

base=main
removed=0
kept=0

# A branch still at the commit it was created from was never worked on (or was
# reset back); a fresh or emptied task worktree sits in main and would otherwise
# look landed. The oldest reflog entry is the creation point.
has_commits() {
  local created tip
  created="$(git reflog show --format=%H "refs/heads/$1" 2>/dev/null | tail -1)"
  tip="$(git rev-parse "refs/heads/$1")"
  [[ -n "$created" && "$tip" != "$created" ]]
}

recently_active() {
  local admin
  admin="$(git -C "$1" rev-parse --path-format=absolute --git-dir)"
  [[ -n "$(find "$admin/HEAD" "$admin/index" -mmin "-$active_minutes" 2>/dev/null)" ]]
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
  # Measured before `git status`, which refreshes the index and its mtime.
  recent=false
  recently_active "$path" && recent=true
  if [[ -n "$only" && "$branch" != "$only" ]]; then
    continue
  elif [[ -n "$(git -C "$path" status --porcelain)" ]]; then
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
  elif [[ -z "$only" ]] && $recent; then
    echo "keep    $path ($branch): landed, but Git activity in the last $active_minutes min; rerun with --only $branch"
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
  [[ -n "$only" && "$branch" != "$only" ]] && continue
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
