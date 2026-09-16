#!/bin/sh

# Xcode Cloud runs non-interactively and cannot show the one-time trust
# dialog for SwiftPM build tool plugins (e.g. Prefire's PrefireTestsPlugin),
# so it refuses to run them unless plugin fingerprint validation is skipped.
defaults write com.apple.dt.Xcode IDESkipPackagePluginFingerprintValidatation -bool YES
