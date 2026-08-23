# Release 2.2

Status: Draft App Store Connect metadata for the next release.

## What ships

- Shows the latest saved regional status immediately after a cold launch while fresh data loads.
- Keeps the saved status visible when the first refresh fails.
- Adds an on-demand explanation of the currently displayed status.
- Removes an out-of-range color warning without changing the visual design.

## App Store Connect

Target version: **2.2**

### What's New — English (U.S.)

```text
Drive Check now shows your latest saved regional status immediately after launch while fresh data loads.

You can also request a clear explanation of the currently displayed status. This update includes additional reliability and visual-rendering improvements.
```

### What's New — Ukrainian

```text
Drive Check тепер одразу показує останній збережений статус регіону під час запуску, поки завантажуються свіжі дані.

Також можна запросити зрозуміле пояснення поточного статусу. Оновлення містить додаткові покращення надійності та відображення.
```

### What's New — Russian

```text
Drive Check теперь сразу показывает последний сохранённый статус региона при запуске, пока загружаются свежие данные.

Также можно запросить понятное объяснение текущего статуса. Обновление включает дополнительные улучшения надёжности и отображения.
```

## Release preparation

- Confirm that App Store Connect does not already contain version 2.2.
- Align the app and extension marketing versions before archiving.
- Run `just verify` and the simulator smoke test on the release commit.
- Attach the build and review the localized metadata before submission.
