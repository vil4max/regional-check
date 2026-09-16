# Release 2.5

Status: local preparation draft; remote push, build availability, and App
Store Connect version state still require verification.

Marketing version: 2.5. Local build number: 1 for the app and widget
extension. Xcode Cloud may assign its own build number; verify the processed
artifact before selecting it in App Store Connect.

## What's New — English

- Read the clear status more easily in CarPlay with a distinct green indicator.

## What's New — Ukrainian

- Легше зчитуйте відсутність тривоги в CarPlay завдяки виразному зеленому індикатору.

## What's New — Russian

- Быстрее считывайте отсутствие тревоги в CarPlay благодаря заметному зелёному индикатору.

## Release gates

- Confirm that commit `4392e07` is present on `origin/main`.
- Run `just verify` in an environment with writable Xcode caches and simulator services.
- Verify the processed 2.5 build and build number in App Store Connect.
- Review localized metadata before App Review submission.
