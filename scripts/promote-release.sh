#!/usr/bin/env bash
# Moves the release branch to a verified, correctly versioned release tag.
#
# Usage: scripts/promote-release.sh <vMAJOR.MINOR.PATCH>
#
# Xcode Cloud builds App Store candidates from the release branch. A tag is
# promoted only when it is annotated, matches MARKETING_VERSION, is on main, and
# the "Tests and coverage" run for a push of that exact commit to main succeeded.
# That run is the whole gate; the commit need not be on testflight, which would
# only cost the same commit a second Xcode Cloud build and never proved anything
# on its own (a red commit followed by a green one is contained too). Tagging
# right after pushing is fine: the script waits. The checks live in lib/promote.sh.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/promote.sh
. "${SCRIPT_DIR}/lib/promote.sh"

TAG="${1:-}"

[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY is not set"
[[ "$TAG" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "tag '$TAG' is not vMAJOR.MINOR.PATCH"

sha="$(resolve_annotated_tag "$TAG")"
assert_marketing_version "$TAG" "$sha" "${TAG#v}"
assert_on_main "$TAG" "$sha"
require_verified_commit "$TAG" "$sha"

promote_branch release "$sha" "$TAG"
