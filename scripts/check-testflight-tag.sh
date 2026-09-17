#!/usr/bin/env bash
# Checks a commit against the tf- tag rules before the owner tags it.
#
# Usage: just tf-check [<commit-ish>]   (default: HEAD)
#
# A rejected tag has to be deleted locally and remotely before retrying, and a
# build nobody wanted spends one of the day's App Store Connect uploads (the cap
# behind ITMS-90382). So run the workflow's own checks first, locally, and print
# the exact tag command with the next free BUILD number.
#
# Advisory: testflight.yml decides. gh is optional — without it the test-run
# state is reported as unknown, not as a failure.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/promote.sh
. "${SCRIPT_DIR}/lib/promote.sh"

target="${1:-HEAD}"
blocked=0

note() { printf '  %s\n' "$*"; }
ok() { printf 'ok       %s\n' "$*"; }
warn() { printf 'warning  %s\n' "$*"; }
blocks() {
  printf 'blocked  %s\n' "$*"
  blocked=1
}

sha="$(git rev-parse "${target}^{commit}")"
printf 'commit   %s  %s\n' "${sha:0:7}" "$(git log -1 --format=%s "$sha")"

git fetch --quiet "$REMOTE" main
if git merge-base --is-ancestor "$sha" FETCH_HEAD; then
  ok "on main"
else
  blocks "not on main — push it first; a tag on an unpushed commit is rejected"
fi

versions="$(git show "${sha}:${PBXPROJ}" | grep -o 'MARKETING_VERSION = [^;]*' | sed 's/.*= //' | sort -u)"
version="$(echo "$versions" | head -1)"
if [[ "$(echo "$versions" | wc -l)" -eq 1 ]]; then
  ok "MARKETING_VERSION $version in every target and configuration"
else
  blocks "MARKETING_VERSION differs across targets or configurations: $(echo "$versions" | tr '\n' ' ')"
fi

# The next free BUILD for this version, read from the tags that exist on the
# remote: local tags can be stale or missing in a fresh clone.
next=1
while read -r existing; do
  [[ -n "$existing" ]] || continue
  (( existing >= next )) && next=$((existing + 1))
done < <(git ls-remote --tags "$REMOTE" "refs/tags/tf-${version}-*" \
  | sed -n 's|.*refs/tags/tf-'"${version}"'-\([0-9][0-9]*\)$|\1|p')
tag="tf-${version}-${next}"

if [[ -z "${GITHUB_REPOSITORY:-}" ]] && command -v gh >/dev/null 2>&1; then
  GITHUB_REPOSITORY="$(gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || true)"
  export GITHUB_REPOSITORY
fi
if [[ -n "${GITHUB_REPOSITORY:-}" ]] && command -v gh >/dev/null 2>&1; then
  case "$(tests_state "$sha")" in
    success) ok "Tests and coverage passed for a push of this commit to main" ;;
    pending) warn "Tests and coverage is still running — the workflow waits up to 45 minutes" ;;
    failure) blocks "Tests and coverage failed for this commit — fix forward on main and tag the fix" ;;
    cancelled) blocks "Tests and coverage was cancelled for this commit — rerun it (gh run rerun)" ;;
    missing) blocks "no Tests and coverage run for a push of this commit to main — it was not the head of its push" ;;
  esac
else
  warn "test-run state unknown (no gh) — testflight.yml checks it and refuses a commit without a green run"
fi

if git fetch --quiet "$REMOTE" testflight 2>/dev/null && git merge-base --is-ancestor "$sha" FETCH_HEAD; then
  blocks "testflight already contains this commit — the branch would not move and no build would start"
  note "to rebuild it, use Start Build on testflight in App Store Connect; it needs no tag"
fi

echo
if ((blocked)); then
  echo "Not ready to tag. Fix the blocked lines above."
  exit 1
fi
cat <<TAG
Ready. Round $next of $version:

  git tag -a $tag -m "<what testers should try in this round>"
  git push origin $tag

The -m message is this round's What to Test: paste it into App Store Connect
when the build appears.
TAG
