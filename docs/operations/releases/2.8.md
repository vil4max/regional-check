# Release 2.8

Marketing version: 2.8. Local build number: 1 for the app and widget extension.
Xcode Cloud assigns the uploaded build number.

This release ships the widget changes that missed 2.7: autonomous background
polling, last-known-good status preservation, and explicit staleness markers.

## Tag policy note

The annotated `v2.8.0` tag is placed at the release-preparation commit, but it
**may be moved (forced update) if the release shifts to a later commit before
publication** — for example when a fix lands after the prep commit. Do not treat
the tag position as final until the release is published.

## What's New — English

- Widgets now update on their own in the background — no more stuck "no connection" state.
- If the network drops, the widget keeps showing the last known alert status with its age instead of going blank.
- Clearer freshness markers when data gets old.

## What's New — Ukrainian

- Віджети тепер оновлюються самостійно у фоні — завислий стан «немає зв'язку» більше не з'являється.
- Якщо мережа зникла, віджет зберігає останній відомий статус тривоги з позначкою давності замість порожнього екрана.
- Зрозуміліші індикатори застарілих даних.

## What's New — Russian

- Виджеты теперь обновляются сами в фоне — зависшее состояние «нет связи» больше не появляется.
- Если сеть пропала, виджет сохраняет последний известный статус тревоги с отметкой давности вместо пустого экрана.
- Более понятные индикаторы устаревших данных.

## Validation and delivery

- Run `just verify` before committing and publishing the release changes.
- Verify the Xcode Cloud build and processed 2.8 artifact before selecting it in App Store Connect.
- Review the localized release notes before submission.
