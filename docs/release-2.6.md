# Release 2.6

Marketing version: 2.6. Local build number: 1 for the app and widget extension.
Xcode Cloud assigns the uploaded build number.

App Store Connect confirms that version 2.5 (build 66) is Ready for Distribution.
These notes cover the widget changes since that release.

## What's New — English

- Updated widgets with clearer alert labels and colors that match the app.
- Added a distinct indicator when widget data is outdated.
- Reduced unnecessary widget refreshes to avoid extra background work.
- Updated the secondary-region widget and added a refresh button.

## What's New — Ukrainian

- Оновлено віджети: зрозуміліші назви станів і кольори, як у застосунку.
- Додано окреме позначення застарілих даних у віджеті.
- Зменшено кількість зайвих оновлень віджета та фонової роботи.
- Оновлено віджет другого регіону й додано кнопку оновлення.

## What's New — Russian

- Обновлены виджеты: понятные названия статусов и цвета, как в приложении.
- Добавлено отдельное обозначение устаревших данных в виджете.
- Сокращены лишние обновления виджета и фоновая работа.
- Обновлён виджет второго региона и добавлена кнопка обновления.

## Validation and delivery

- Run `just verify` before committing and publishing the release changes.
- Verify the Xcode Cloud build and processed 2.6 artifact before selecting it in App Store Connect.
- Review the localized release notes before submission.
- Add the annotated `v2.6.0` tag at the release-preparation commit after publication is confirmed.
