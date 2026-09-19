# CarPlay and TestFlight readiness

App ID `vil4max.RegionalCheck` (team `BTHRDS7254`) needs Apple CarPlay Driving Task entitlement, then a new App Store profile containing `com.apple.developer.carplay-driving-task`.

Entitlements file: `RegionalCheck/Resources/RegionalCheck.entitlements`.

## Xcode Cloud → TestFlight

Builds come from Xcode Cloud only, gated by GitHub Actions. The current workflows, their App Store Connect settings, and the release checklist are in [release-process.md](release-process.md); the current single-pipeline decision is [ADR 0013](../decisions/0013-one-build-pipeline-or-two.md). ADP includes 25 compute hours per month.

### Repo prerequisites (met)

- Shared scheme `RegionalCheck` with Archive enabled (`buildForArchiving = YES`)
- Archivable product: `vil4max.RegionalCheck` / team `BTHRDS7254`
- App Store Connect app record exists
- `ci_scripts/ci_post_clone.sh` skips SwiftPM plugin fingerprint validation so Prefire's build tool plugin runs non-interactively

Verify locally anytime:

```bash
xcodebuild -project RegionalCheck.xcodeproj -describeAllArchivableProducts -json
```

### Rules for the Xcode Cloud workflows

- Do not add a Test action: tests run only in GitHub Actions.
- The single archive workflow starts from `testflight`, advanced by CI after an owner-created `tf-*` tag passes its checks. Neither `main` nor `release` starts an archive.
- A `v*` tag records the submitted TestFlight commit; it does not request another build.
- Record any workflow change in the configuration table of [release-process.md](release-process.md).
- If App Store Connect expects a higher build number, set the next Xcode Cloud build number: [Setting the next build number for Xcode Cloud builds](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds).

Builds expire after 90 days in TestFlight. Xcode Cloud keeps build artifacts for 30 days — download symbols for any App Store-bound build.

## App Privacy (before App Review)

Before submitting or updating metadata, walk through the App Privacy checklist in `docs/operations/analytics.md` (location when-in-use, no analytics SDK, no tracking). Privacy policy: `docs/privacy-policy.html`.

## Fallback: local Archive

A local Archive is not an automatic substitute for the tag-gated pipeline.
If Xcode Cloud is unavailable, report the failure and obtain an explicit
release-path decision before changing build numbers or uploading a local
archive. The candidate must retain its verified source SHA, version, and
acceptance evidence; membership in the retired `release` branch is not a gate.
