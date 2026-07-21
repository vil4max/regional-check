# CarPlay and TestFlight readiness

App ID `vil4max.RegionalCheck` (team `BTHRDS7254`) needs Apple CarPlay Driving Task entitlement, then a new App Store profile containing `com.apple.developer.carplay-driving-task`.

Entitlements file: `RegionalCheck/Resources/RegionalCheck.entitlements`.

## Preferred path: Xcode Cloud → TestFlight

Prefer [Xcode Cloud](https://developer.apple.com/xcode-cloud/get-started/) over a local Archive upload. ADP includes 25 compute hours per month.

### Repo prerequisites (already met)

- Shared scheme `RegionalCheck` with Archive enabled (`buildForArchiving = YES`)
- Archivable product: `vil4max.RegionalCheck` / team `BTHRDS7254`
- App Store Connect app record exists
- No `ci_scripts` required (no third-party package installs)

Verify locally anytime:

```bash
xcodebuild -project RegionalCheck.xcodeproj -describeAllArchivableProducts -json
```

### First-time setup (Xcode UI)

Needs Account Holder, Admin, App Manager, or Developer/Marketing with Create Apps permission.

1. Push the branch you want built to GitHub (`vil4engineering/regional-check`).
2. Open the project in Xcode 15+.
3. Report navigator → Cloud → Get Started.
4. Select product `RegionalCheck`, team `BTHRDS7254`.
5. Grant Xcode Cloud access to the Git repository.
6. Review the suggested workflow (scheme `RegionalCheck`, Archive action).
7. Start Build on the branch that contains the release commit.

Docs: [Configuring your first Xcode Cloud workflow](https://developer.apple.com/documentation/xcode/configuring-your-first-xcode-cloud-workflow).

### After the first successful build

1. Edit the workflow (Xcode or App Store Connect → Xcode Cloud → Manage Workflows).
2. Add a **Test** action for `RegionalCheckTests` (smoke tests).
3. Add a post-action to distribute to **TestFlight**.
4. Optionally narrow start conditions (default branch and/or release branch) to save compute hours.
5. If ASC still expects build `1`, set the next Xcode Cloud build number to `2` or higher: [Setting the next build number for Xcode Cloud builds](https://developer.apple.com/documentation/xcode/setting-the-next-build-number-for-xcode-cloud-builds).

### Shipping a cleaned build while App Review is waiting

1. App Store Connect → cancel the current Waiting for Review submission (build `1`).
2. Ensure `CURRENT_PROJECT_VERSION` is bumped (currently `2` on main after cleanup).
3. Push and start (or wait for) an Xcode Cloud Archive → TestFlight build.
4. When build `2+` is in TestFlight / Ready for Review, submit App Review again.

Builds expire after 90 days in TestFlight. Xcode Cloud keeps build artifacts for 30 days — download symbols for any App Store-bound build.

## Fallback: local Archive

Only if Xcode Cloud is unavailable:

1. Increment `CURRENT_PROJECT_VERSION`.
2. Product → Archive (Release).
3. Distribute to App Store Connect → TestFlight.
