#!/usr/bin/env bash
# Checks a vMAJOR.MINOR.PATCH marker tag. It moves no branch and starts no build.
#
# Usage: scripts/check-release-tag.sh <vMAJOR.MINOR.PATCH>
#
# After ADR 0013 a release tag records which commit's build was submitted to App
# Review; the build itself came from a tf- tag. Nothing here can undo a wrong
# tag, so the check exists to say so while the submission is still fresh: the
# tag must name a verified commit on main whose own TestFlight build exists,
# which is the tf-<version>-BUILD tag on that exact commit.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/promote.sh
. "${SCRIPT_DIR}/lib/promote.sh"

TAG="${1:-}"

[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY is not set"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "tag '$TAG' is not vMAJOR.MINOR.PATCH"

sha="$(resolve_annotated_tag "$TAG")"
version="${TAG#v}"
assert_marketing_version "$TAG" "$sha" "$version"
assert_on_main "$TAG" "$sha"
require_verified_commit "$TAG" "$sha"
assert_testflight_round "$TAG" "$sha" "$version"

echo "$TAG marks ${sha:0:7} as the submitted commit of $version"
