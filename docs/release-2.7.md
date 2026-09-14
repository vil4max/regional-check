# Release 2.7

Marketing version: 2.7. Local build number: 1 for the app and widget extension.
Xcode Cloud assigns the uploaded build number.

App Store Connect confirms that version 2.6 is processed.
These notes cover the widget freshness and cellular polling stability changes since that release.

## What's New — English

- Restored standard refresh frequency on cellular networks (LTE/5G) for responsive CarPlay driving updates.
- Air raid alert and all-clear statuses are now kept clearly visible during brief mobile coverage delays.
- Improved widget freshness tracking with explicit update timestamps.
- Added a clear "No Signal" indicator when network connection is lost for more than 10 minutes.

## What's New — Ukrainian

- Відновлено стандартну частоту оновлень через стільникову мережу (LTE/5G) для своєчасних оновлень у CarPlay.
- Статуси повітряної тривоги та відбою тепер чітко зберігаються під час короткочасних пауз зв'язку в дорозі.
- Покращено відображення свіжості даних віджета з точною фіксацією часу оновлення.
- Додано чіткий статус «Немає зв'язку» при втраті мережі довше ніж на 10 хвилин.

## What's New — Russian

- Восстановлена стандартная частота обновлений по сотовой сети (LTE/5G) для своевременных обновлений в CarPlay.
- Статусы тревоги и отбоя теперь надежно сохраняются при кратковременных перебоях связи в дороге.
- Улучшено отслеживание свежести данных виджета с точной фиксацией времени обновления.
- Добавлен понятный статус «Нет связи» при отсутствии сети более 10 минут.

## Validation and delivery

- Run `just verify` before committing and publishing the release changes.
- Verify the Xcode Cloud build and processed 2.7 artifact before selecting it in App Store Connect.
- Review the localized release notes before submission.
- Add the annotated `v2.7.0` tag at the release-preparation commit after publication is confirmed.
