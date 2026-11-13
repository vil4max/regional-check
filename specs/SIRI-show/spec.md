# SIRI-show: ask Siri for the alert status in your own words

Status: draft, 2026-11-12. Not approved. Target: 3.4.0. Related backlog items: SIRI-1 to SIRI-4
(`docs/planning/backlog.md`).

## Request

Owner, 2026-11-12 (verbatim): «Также нужно проверить, что там сделано по Siri и по интентам, чтобы
голосом можно было сказать Siri, покажи состояние тревог, покажи тревогу.»

## What exists today (audit, 2026-11-12)

- One App Shortcut, `CheckAlertStatusIntent`, answers in place with a spoken and a shown dialog
  (`Packages/DriveCheckKit/Sources/DriveCheckKit/CheckAlertStatusIntent.swift:4`, REQ-SURF-011).
- Its phrases all say "check" and the app name: "Check alert status in Drive Check", "Проверить
  статус тревоги в Drive Check", "Перевірити статус тривоги в Drive Check"
  (`RegionalCheckWidgets/DriveCheckShortcuts.swift:9-12`).
- None of «покажи состояние тревог», «покажи тревогу» or "show alert status" is a phrase.
- The Russian and Ukrainian phrases sit in the English source list; there is no
  `AppShortcuts.xcstrings`, so they are not localized phrases and likely match only when Siri
  speaks English.
- `intent.check.title` exists only in the Kit's catalog, not the widget's or the app's, so
  Shortcuts may show the raw key (not verified on a device).
- With no region chosen, the intent silently answers for Kyiv city
  (`CheckAlertStatusIntent.swift:18`).
- The app name has no localized form or alternative names (`INAlternativeAppNames`), so a
  Russian or Ukrainian speaker must say "Drive Check" in English.
- Siri's languages: Apple's iOS 27 feature-availability page lists Ukrainian for Dictation; whether
  Siri itself takes Ukrainian is checked against Apple's current list in the plan
  ([iOS 27 feature availability](https://www.apple.com/ios/feature-availability/)). If it does not,
  Ukrainian phrases cannot be spoken to Siri and serve only Spotlight and Shortcuts.

## Acceptance criteria (draft)

- **AC-1** The owner's phrases work in Russian and English with the app name: "Покажи тревогу в
  Drive Check", "Покажи состояние тревог в Drive Check", "Show alert status in Drive Check", plus
  the existing "check" phrases; Ukrainian equivalents where Siri supports Ukrainian.
- **AC-2** Phrases live in `AppShortcuts.xcstrings`, one localization per language, each with the
  `${applicationName}` token.
- **AC-3** The intent's title and parameter keys resolve in every catalog the extension and app
  read; Shortcuts shows no raw key in `en`, `uk` or `ru`.
- **AC-4** With no region chosen, Siri says so and names how to choose one, instead of answering
  for Kyiv city.
- **AC-5** The answer works hands-free in CarPlay and on a locked iPhone without opening the app
  (to verify on a device).
- **AC-6** Tests: phrase coverage per locale and catalog keys, checked by a unit test, not by hand.

## Out of scope

A Siri AI integration beyond App Shortcuts; a refresh phrase (SIRI-4) unless the owner adds it.

## Points to decide

1. Alternative app name: «Драйв Чек» (owner, 2026-11-12), so «Покажи тревогу в Драйв Чек» works
   in Russian; its Ukrainian form follows the Siri language check.
2. AC-4: wording of the no-region answer.
