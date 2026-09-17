#!/usr/bin/env bash
# Moves the testflight branch to a verified commit the owner marked for TestFlight.
#
# Usage: scripts/promote-testflight.sh <tf-MAJOR.MINOR.PATCH-BUILD>
#
# Xcode Cloud builds internal TestFlight builds from the testflight branch. Every
# build costs Xcode Cloud compute and an App Store Connect build slot, so a
# commit reaches the branch only when the owner tags it: annotated, naming the
# commit's own MARKETING_VERSION, on main, and with a successful "Tests and
# coverage" run for a push of that exact commit to main. Tagging right after
# pushing is fine: the script waits. The checks live in lib/promote.sh.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/promote.sh
. "${SCRIPT_DIR}/lib/promote.sh"

TAG="${1:-}"

[[ -n "${GITHUB_REPOSITORY:-}" ]] || fail "GITHUB_REPOSITORY is not set"
[[ "$TAG" =~ ^tf-[0-9]+\.[0-9]+\.[0-9]+-[0-9]+$ ]] || fail "tag '$TAG' is not tf-MAJOR.MINOR.PATCH-BUILD"

sha="$(resolve_annotated_tag "$TAG")"
version="${TAG#tf-}"
assert_marketing_version "$TAG" "$sha" "${version%-*}"
assert_on_main "$TAG" "$sha"
require_verified_commit "$TAG" "$sha"

promote_branch testflight "$sha" "$TAG"
