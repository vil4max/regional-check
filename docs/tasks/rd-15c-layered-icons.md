# Agent Task — RD-15C: layered Icon Composer icons (Mark and Pro)

Assignee: unassigned
State: blocked
Status note: parked after 3.0.0 (see Decided); waits for the owner to schedule it.
Requested by: owner (2026-09-17, redesign batch 5, "и не забываем про иконку")
Decided: drivecheck-product parked it out of 3.0.0 on 2026-09-17 on the research
below; the owner may overrule that, and the decisive experiment is small
(see Acceptance).
Parent: `docs/tasks/redesign.md`
Requirements: none yet — the app icon has no REQ ID
Changes a requirement: no
Owned files: a new `Mark.icon` / `Mark-Pro.icon` package, the target's App Icon
build setting, and whatever `AlternateIconManager` needs
Out of scope: shipping this inside 3.0.0; App Store Connect; any tag
Failure conditions: the shipped Dark or Tinted icon regresses; the Pro icon
switch stops working or survives only by accident; a hand-written manifest is
committed without a build proving Xcode accepts it

## Why this is parked and not cancelled

The upside is real: Liquid Glass layer effects — specular, translucency, blur,
per-appearance fills — on an icon that today is a flat 1024 PNG per appearance.

The cost is that Apple's Icon Composer article states outright that adding an
Icon Composer file **replaces** the icon asset catalog. The Default, Dark and
Tinted icons that shipped in 6b37b5f and 23825b7 therefore stop being used and
have to be re-expressed as `appearance` variants inside `icon.json` and proven
again on a device. On top of that, the Pro alternate icon — shipped behaviour,
driven by `AlternateIconManager` — rests on asset-catalog vocabulary that Apple
has not extended to `.icon` packages in writing. Doing that re-authoring days
before an App Review submission trades a working icon for an unproven one, so
3.0.0 keeps the asset catalog.

## What is already known about the format

An `.icon` is a package, not an opaque Icon Composer document: Icon Composer.app
(Xcode 27) exports the UTI `com.apple.iconcomposer.icon` with
`UTTypeConformsTo = com.apple.package` and extension `icon`, so its contents are
ordinary files. The layout is `Name.icon/icon.json` plus an `Assets/` directory
of layer files — the literals `icon.json`, `AssetStore`,
`Assets should be a directory` and `IconComposition.AssetStore.swift` all appear
in `IconComposerFoundation.framework` inside the app bundle. The manifest
vocabulary, extracted from that same framework, is: `version`,
`supported-platforms`, `platform`, `groups`, `layers`, `image-name`, `fill`
(`solid`, `gradient`, `image`, `color`, `blend-mode`), `specular`,
`translucency`, `blur`, `shadow`, `opacity`, `position`, `scale`, `hidden`,
`appearance` with the values `neutral`, `dark`, `tinted` and `light`, plus
localization keys (`locale`, `localizations`,
`com.apple.IconComposer.localized-assets-slice`). Apple's authoring guidance
matches that shape: layers are SVG (preferred) or PNG exported from any design
tool, 1024×1024 for iPhone/iPad/Mac, organised into at most four groups rendered
back to front, with blurs, shadows, specular, opacity, translucency and
background fills left to the manifest rather than baked into the artwork.
Project wiring is a single step: add the file to the target and set the App Icon
field in the target's General pane (build setting
`ASSETCATALOG_COMPILER_APPICON_NAME`) to the filename without its extension.

Two blockers remain, and both need exactly one build to settle, not more
research. First, the `icon.json` schema above is reverse-engineered from binary
strings and is not published, so whether Xcode's icon compiler accepts a
hand-written manifest is unproven — the decisive test is a hand-written manifest
over the existing 1024 Mark PNG, one compile, and an inspection of the built
app. Second, and more serious for this app: `AlternateIconManager` relies on
`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES` / `CFBundleAlternateIcons`,
which Apple's build-settings reference and `setAlternateIconName` documentation
still describe purely as asset-catalog icon *set* names; the Icon Composer
article says a project may hold several `.icon` files but only the one matching
the App Icon field is used. Nothing in Apple's documentation either permits or
forbids a second `.icon` as a runtime alternate, so the Pro icon switch is an
open question a build must answer.

## Acceptance

Run the cheap experiment first and report before implementing:

1. One worktree, one hand-written `icon.json` over the existing Mark PNG, one
   build. Does the icon compiler accept it, and does the built app show the
   icon?
2. Add a second `.icon` and call `setAlternateIconName` with its name. Does the
   Pro switch work, and does it survive a restart?

If either answer is no, close this task with the evidence: the asset catalog
stays. If both are yes, then implement — Mark and Pro as layered icons, Default,
Dark and Tinted proven on a device, the Pro switch proven twice (switch and
restart), and `docs/design/redesign/geometry-and-tokens.md` updated by
drivecheck-product with whatever the layer geometry turns out to be.

## Sources

- [Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
  — the Important note about replacing the asset catalog, layer export
  guidance, the App Icon field wiring, "only one that matches the name in the
  App Icon text field".
- [Configuring your app icon using an asset catalog](https://developer.apple.com/documentation/xcode/configuring-your-app-icon)
  — what the app uses today, including the single-1024 form and the iOS dark
  and tinted styles.
- [Build settings reference](https://developer.apple.com/documentation/xcode/build-settings-reference)
  — `ASSETCATALOG_COMPILER_APPICON_NAME`,
  `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`.
- [`setAlternateIconName(_:completionHandler:)`](https://developer.apple.com/documentation/uikit/uiapplication/setalternateiconname(_:completionhandler:))
  — `CFBundleIcons` / `CFBundlePrimaryIcon` / `CFBundleAlternateIcons`.
- **Not from Apple's documentation:** the UTI declaration and the manifest
  vocabulary were read out of
  `/Applications/Xcode.app/Contents/Applications/Icon Composer.app` — its
  `Info.plist` and the strings of
  `Contents/Frameworks/IconComposerFoundation.framework`, on Xcode 27 (27A266a),
  2026-09-17. Treat that vocabulary as a starting point to validate, not as a
  contract.
