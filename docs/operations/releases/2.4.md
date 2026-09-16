# Release 2.4

Status: local preparation draft; App Store Connect version and build availability not yet verified.

Marketing version: 2.4. Local build number: 1 for the app and widget extension.
Xcode Cloud may assign its own build number; verify the processed artifact before selecting it in App Store Connect.

Notes below cover the driver-facing changes from `6819262..7b61dab`. Confirm the previous published build before treating this as the complete App Store release delta.

## What's New — English

- Read regional alert status more easily with clearer CarPlay indicators and a simpler main screen.
- See when information is outdated and check the last known regional status if an update fails.
- Identify automatic or manual region selection; outside Ukraine, the app keeps the previous region instead of switching to Kyiv.
- Open additional information separately and refresh without leaving the current CarPlay screen.
- See freshness information in the compact Live Activity and use the clearer refresh button on iPhone.

## What's New — Ukrainian

- Чіткіші позначки статусу та простіший головний екран CarPlay допомагають швидше прочитати інформацію про тривогу.
- Переглядайте попередження про застарілі дані та останній відомий статус регіону, якщо оновлення не вдалося.
- Розрізняйте автоматичний і ручний вибір регіону; поза Україною застосунок зберігає попередній регіон замість перемикання на Київ.
- Відкривайте подробиці окремо та оновлюйте дані без переходу з поточного екрана CarPlay.
- Переглядайте актуальність даних у компактній Live Activity та користуйтеся зрозумілішою кнопкою оновлення на iPhone.

## What's New — Russian

- Более заметные обозначения статуса и упрощённый главный экран CarPlay помогают быстрее прочитать информацию о тревоге.
- Смотрите предупреждения об устаревших данных и последний известный статус региона, если обновление не удалось.
- Различайте автоматический и ручной выбор региона; вне Украины приложение сохраняет предыдущий регион вместо переключения на Киев.
- Открывайте подробности отдельно и обновляйте данные без перехода с текущего экрана CarPlay.
- Проверяйте актуальность данных в компактной Live Activity и используйте более понятную кнопку обновления на iPhone.

## Remaining release gates

- Visually verify iPhone and CarPlay, including stale data, offline, automatic/manual selection, and the compact Live Activity.
- Confirm the existing App Store version and previous published build in App Store Connect.
- Commit and push the verified version bump, then use the existing Xcode Cloud workflow for Archive and TestFlight.
- Verify processed version, build number, signing, and distribution status before selecting the build.
- Review localized metadata and obtain approval before App Review submission or release.
