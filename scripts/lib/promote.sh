#!/usr/bin/env bash
# Shared checks for the scripts that move the branches Xcode Cloud builds.
#
# Source this file from a promotion script; it only defines functions.
#
# Xcode Cloud archives whatever `testflight` and `release` point at, so both
# promotions answer the same question: did the owner annotate a commit that
# GitHub Actions verified, carrying the marketing version the tag claims? The
# checks live here so the two paths cannot drift apart.
#
# Needs GH_TOKEN with actions:read and GITHUB_REPOSITORY (both set in Actions).

REMOTE="${PROMOTE_REMOTE:-origin}"
WAIT_ATTEMPTS="${PROMOTE_WAIT_ATTEMPTS:-45}"
WAIT_SECONDS="${PROMOTE_WAIT_SECONDS:-60}"
TESTS_WORKFLOW="${PROMOTE_TESTS_WORKFLOW:-tests.yml}"
PBXPROJ="RegionalCheck.xcodeproj/project.pbxproj"

fail() {
  echo "::error::$*" >&2
  exit 1
}

# Prints the commit of annotated tag $1. A lightweight tag is rejected: the
# annotation is the owner's recorded intent to publish that commit.
resolve_annotated_tag() {
  local tag="$1"
  git fetch --quiet "$REMOTE" "refs/tags/${tag}:refs/tags/${tag}"
  [[ "$(git cat-file -t "refs/tags/${tag}")" == "tag" ]] || fail "$tag must be an annotated tag"
  git rev-list -n 1 "refs/tags/${tag}"
}

# Fails unless every MARKETING_VERSION at commit $2 is exactly $3. Tag $1 names
# the version it claims, so a tag on a commit built as another version is a typo.
assert_marketing_version() {
  local tag="$1" sha="$2" version="$3" versions
  versions="$(git show "${sha}:${PBXPROJ}" | grep -o 'MARKETING_VERSION = [^;]*' | sed 's/.*= //' | sort -u)"
  [[ "$versions" == "$version" ]] \
    || fail "$tag does not match MARKETING_VERSION at ${sha:0:7}: $(echo "$versions" | tr '\n' ' ')"
}

# Fails unless commit $2 is contained in main.
assert_on_main() {
  local tag="$1" sha="$2"
  git fetch --quiet "$REMOTE" main
  git merge-base --is-ancestor "$sha" FETCH_HEAD || fail "$tag (${sha:0:7}) is not on main"
}

# Prints success, failure, cancelled, pending, or missing for the Tests runs of a
# push of $1 to main. The API reports each run's latest attempt, so a rerun that
# succeeds replaces an earlier failure or cancellation.
tests_state() {
  gh api "repos/${GITHUB_REPOSITORY}/actions/workflows/${TESTS_WORKFLOW}/runs?head_sha=${1}&event=push&branch=main" \
    --jq '[.workflow_runs[] | {status, conclusion}] as $runs
      | if ($runs | length) == 0 then "missing"
        elif any($runs[]; .conclusion == "success") then "success"
        elif any($runs[]; .status != "completed") then "pending"
        elif all($runs[]; .conclusion == "cancelled") then "cancelled"
        else "failure" end'
}

# Waits until commit $2 has its own successful "Tests and coverage" run for a
# push to main, or fails. Containment in a verified branch is not a substitute: a
# red commit followed by a green one is also contained. Tagging right after
# pushing is fine, which is why this waits instead of failing on "pending".
require_verified_commit() {
  local tag="$1" sha="$2" state attempt
  for ((attempt = 1; ; attempt++)); do
    state="$(tests_state "$sha")"
    case "$state" in
      success)
        echo "${sha:0:7} passed Tests and coverage on main"
        return 0
        ;;
      failure)
        fail "Tests and coverage failed for ${sha:0:7}; fix main, bump the version, and tag the fixed commit"
        ;;
    esac
    # "cancelled": a newer push to main cancelled this commit's run (cancel-in-progress).
    # "missing": the commit was not the head of a push, so it has no run of its own.
    if ((attempt >= WAIT_ATTEMPTS)); then
      case "$state" in
        cancelled)
          fail "Tests and coverage for ${sha:0:7} was cancelled by a newer push; rerun it (gh run rerun), then rerun this workflow"
          ;;
        *)
          fail "no successful Tests and coverage run for a push of ${sha:0:7} to main ($state); tag a commit a run verified, or rerun this workflow once it is green"
          ;;
      esac
    fi
    echo "waiting for Tests and coverage on ${sha:0:7}: $state ($attempt/$WAIT_ATTEMPTS)"
    sleep "$WAIT_SECONDS"
  done
}

# Fast-forwards branch $1 to commit $2, named $3 in the log. Never force-pushes:
# these branches are the record of what Xcode Cloud built.
promote_branch() {
  local branch="$1" sha="$2" label="$3"
  if git fetch --quiet "$REMOTE" "$branch" 2>/dev/null && git merge-base --is-ancestor "$sha" FETCH_HEAD; then
    echo "$branch already contains $label"
    # Xcode Cloud starts on a branch change, so a no-op promotion builds nothing.
    # Saying so here stops the tag from looking like a build that never arrived.
    echo "$branch did not move, so Xcode Cloud starts no build; to rebuild ${sha:0:7}, use Start Build on $branch in App Store Connect"
    return 0
  fi
  git push "$REMOTE" "${sha}:refs/heads/${branch}"
  echo "$branch -> $label (${sha:0:7})"
}
